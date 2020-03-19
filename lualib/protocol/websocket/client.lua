local class = require "class"

local log = require "logging"
local Log = log:new{ dump = true, path = "protocol-wsclient"}

local tcp = require "internal.TCP"

local cf = require "cf"
local cf_fork = cf.fork

local wbproto = require "protocol.websocket.protocol"
local _recv_frame = wbproto.recv_frame
local _send_frame = wbproto.send_frame

local HTTP = require "protocol.http"
local PARSER_HTTP_RESPONSE = HTTP.PARSER_HTTP_RESPONSE

local crypt = require "crypt"
local sha1 = crypt.sha1
local base64encode = crypt.base64encode

local type = type
local next = next
local pcall = pcall
local ipairs = ipairs
local setmetatable = setmetatable

local random = math.random
local toint = math.tointeger
local os_date = os.date
local concat = table.concat
local insert = table.insert

local char = string.char
local byte = string.byte
local find = string.find
local fmt = string.format
local match = string.match

local CRLF = '\x0d\x0a'
local CRLF2 = '\x0d\x0a\x0d\x0a'
local RE_CRLF2 = '[\x0d]?\x0a[\x0d]?\x0a'

local function rshift(a, b)
  return a >> b
end

local function band (a, b)
  return a & b
end

local function sock_read (self, byte)
  local sock = self.sock
  if self.ssl then
    return sock:ssl_recv(byte)
  end
  return sock:recv(byte)
end

local function sock_send (self, data)
  local sock = self.sock
  if self.ssl then
    return sock:ssl_send(data)
  end
  return sock:send(data)
end

local function sock_connect (self, domain, port)
  local sock = self.sock
  if self.ssl then
    return sock:ssl_connect(domain, port)
  end
  return sock:connect(domain, port)
end

local function sock_close (self)
  self.sock:close()
end

local function check_response (self, secure)
  local buffers = {}
  while 1 do
    local data = sock_read(self, 1024)
    if not data then
      return nil, '服务端断开了连接'
    end
    buffers[#buffers + 1] = data
    local buffer = concat(buffers)
    if find(buffer, RE_CRLF2) then
      local version, code, msg, headers = PARSER_HTTP_RESPONSE(buffer)
      if tonumber(version) ~= 1.1 or tonumber(code) ~= 101 or not headers then
        sock_close(self)
        return nil, "错误: 协议升级失败"
      end
      if not next(headers) then
        sock_close(self)
        return nil, "错误: 不支持的响应头部"
      end
      local sec_key = headers['Sec-WebSocket-Accept']
      local connection = headers['Connection']
      if not connection or connection:lower() ~= 'upgrade' then
        sock_close(self)
        return nil, '错误: 不支持的ws协议版本'
      end
      if sec_key ~= secure then
        sock_close(self)
        return nil, '错误: Sec-WebSocket-Accept验证失败'
      end
      if type(headers['Sec-WebSocket-Extensions']) == 'string' and find(headers['Sec-WebSocket-Extensions'], "permessage%-deflate") then
        self.ext = 'deflate'
      end
      return true
    end
  end
end

-- HTTP[s] Over WebSocket Upgrade
local function do_handshake (self)

  local ok, err = sock_connect(self, self.domain, self.port)
  if not ok then
    sock_close(self)
    return nil, err
  end

  local key = char(
      byte('c'), byte('f'), byte('a'), byte('d'), byte('m'), byte('i'), byte('n'),
      random(256) - 1, random(256) - 1, random(256) - 1,
      random(256) - 1, random(256) - 1, random(256) - 1,
      random(256) - 1, random(256) - 1, random(256) - 1
  )

  local sec_key = base64encode(key)
  local req = {
    fmt('GET %s HTTP/1.1', self.path),
    fmt('Data: %s', os_date("Date: %a, %d %b %Y %X GMT")),
    fmt('Host: %s:%s', self.domain, self.port),
    fmt('Sec-WebSocket-Key: %s', sec_key),
    'Origin: http://'..self.domain,
    'Upgrade: websocket',
    'Connection: Upgrade',
    'Sec-WebSocket-Version: 13',
    'User-Agent: cf-websocket/0.1',
    'Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits',
    CRLF
  }
  local ok, err = sock_send(self, concat(req, CRLF))
  if not ok then
    sock_close(self)
    return ok, err
  end

  return check_response(self, base64encode(sha1(sec_key .. '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')))
end

local function url_split (self)
  local scheme, domain_port, path = match(self.url, '^(ws[s]?)://([^/]+)(.*)')
  if not scheme or not domain_port then
    return nil, "连接失败: 无效的url参数"
  end

  if not path or path == '' then
    return nil, "连接失败: wss无path需要以'/'结尾"
  end

  local domain, port
  if find(domain_port, ':') then
    local _, Bracket_Pos = find(domain_port, '[%[%]]')
    if Bracket_Pos then
      domain, port = match(domain_port, '%[(.+)%][:]?(%d*)')
    else
      domain, port = match(domain_port, '([^:]+):(%d*)')
    end
    if not domain then
      return nil, "无效或者非法的主机名: "..domain_port
    end
    port = toint(port)
    if not port then
      port = 80
      if scheme == 'wss' then
        port = 443
      end
    end
  else
    domain, port = domain_port, scheme == 'ws' and 80 or 443
  end

  -- 判断是否需要ssl socket
  if scheme == 'wss' then
    self.ssl = true
  end
  self.domain = domain
  self.port = port
  self.path = path
  return true
end

local websocket = class("websocket-client")

function websocket:ctor (opt)
  self.ssl = nil
  self.url = opt.url
  self.sock = tcp:new()
  self.sock._timeout = opt.timeout
  self.send_masked = opt.send_masked or true
  self.max_payload_len = opt.max_payload_len or 65535
end

-- 设置超时
function websocket:set_timeout (timeout)
  self.sock._timeout = timeout
end

function websocket:connect ()
  if self.state then
    return nil, '已连接'
  end
  -- 切割URL
  local ok, err = url_split(self)
  if not ok then
    return nil, err
  end
  -- Websocket握手流程
  local ok, err = do_handshake(self)
  if not ok then
    return nil, err
  end
  self.state = true
  return true, err
end

-- 接受数据
function websocket:recv()
  if not self.state then
    return nil, '未连接'
  end
  local data, typ, err = _recv_frame(self.sock, self.max_payload_len, not self.send_masked)
  if typ == 'close' or not typ then
    self.state = nil
    if type == 'close' then
      return nil, 'server was closed session'
    end
    return nil, data or err
  end
  return data, typ
end

-- 发送 text/binary
function websocket:send (data, is_binary)
  if not self.state then
    return nil, '未连接'
  end
  local func = function (...)
    return _send_frame(self.sock, true, is_binary and 0x2 or 0x1, data, self.max_payload_len, self.send_masked, self.ext)
  end
  if not self.queue then
    self.queue = { func }
    return cf_fork(function (...)
      for _, f in ipairs(self.queue) do
        local ok, err = pcall(f)
        if not ok then
          Log:ERROR(err)
        end
      end
      self.queue = nil
    end)
  end
  return insert(self.queue, func)
end

-- 发送ping
function websocket:ping(data)
  if not self.state then
    return nil, '未连接'
  end
  local func = function (...)
    return _send_frame(self.sock, true, 0x9, data, self.max_payload_len, self.send_masked, self.ext)
  end
  if not self.queue then
    self.queue = { func }
    return cf_fork(function (...)
      for _, f in ipairs(self.queue) do
        local ok, err = pcall(f)
        if not ok then
          Log:ERROR(err)
        end
      end
      self.queue = nil
    end)
  end
  return insert(self.queue, func)
end

-- 发送pong
function websocket:pong(data)
  if not self.state then
    return nil, '未连接'
  end
  local func = function (...)
    return _send_frame(self.sock, true, 0xA, data, self.max_payload_len, self.send_masked, self.ext)
  end
  if not self.queue then
    self.queue = { func }
    return cf_fork(function (...)
      for _, f in ipairs(self.queue) do
        local ok, err = pcall(f)
        if not ok then
          Log:ERROR(err)
        end
      end
      self.queue = nil
    end)
  end
  return insert(self.queue, func)
end

-- 清理连接
function websocket:close ()
  if self.sock then
    sock_close(self)
  end
end

return websocket
