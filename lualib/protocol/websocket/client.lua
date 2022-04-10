local class = require "class"

local log = require "logging"
local Log = log:new{ dump = true, path = "protocol-wsclient"}

local tcp = require "internal.TCP"
local stream = require "stream"

local cf = require "cf"
local cf_fork = cf.fork

local new_tab = require "sys".new_tab

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
local strpack = string.pack

local CRLF = '\x0d\x0a'
local CRLF2 = '\x0d\x0a\x0d\x0a'

local function sock_readline (sock, sp)
  return sock:readline(sp)
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
  self.sock = nil
end

local function check_response (self, secure)

  -- 读取协议头
  local buffer = sock_readline(self.sock, CRLF2)
  if not buffer then
    return false, '[WS ERROR] : Server Close this session when recv http handshake.'
  end

  -- 解析协议头
  local version, code, _, headers = PARSER_HTTP_RESPONSE(buffer)
  if tonumber(version) ~= 1.1 or tonumber(code) ~= 101 or not headers then
    sock_close(self)
    return nil, "Error: protocol upgrade failed."
  end
  if not next(headers) then
    sock_close(self)
    return nil, "Error: unsupported response header."
  end

  -- 验证握手信息
  local connection = headers['Connection']
  if not connection or connection:lower() ~= 'upgrade' then
    sock_close(self)
    return nil, 'Error: Unsupported websocket protocol version.'
  end
  if headers['Sec-WebSocket-Accept'] ~= secure then
    sock_close(self)
    return nil, 'Error: `Sec-WebSocket-Accept` verification failed.'
  end
  if type(headers['Sec-WebSocket-Extensions']) == 'string' and find(headers['Sec-WebSocket-Extensions'], "permessage%-deflate") then
    self.ext = 'deflate'
  end

  return true
end

-- HTTP[s] Over WebSocket Upgrade
local function do_handshake (self)

  local ok, err

  ok, err = sock_connect(self, self.domain, self.port)
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

  ok, err = sock_send(self, concat(req, CRLF))
  if not ok then
    sock_close(self)
    return ok, err
  end

  return check_response(self, base64encode(sha1(sec_key .. '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')))
end

local function url_split (self)
  local scheme, domain_port, path = match(self.url, '^(ws[s]?)://([^/]+)(.*)')
  if not scheme or not domain_port then
    return nil, "Connection failed: invalid url parameter."
  end

  if not path or path == '' then
    path = '/'
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
      return nil, "Invalid or illegal hostname: "..domain_port
    end
    port = toint(port)
    if not port then
      port = scheme == 'wss' and 443 or 80
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
  self.ext = nil
  self.url = opt.url
  self.sock = stream(tcp:new())
  self.send_masked = true
  self.sock._timeout = toint(opt.timeout)
  self.max_payload_len = opt.max_payload_len or 65535
end

-- 设置超时
function websocket:set_timeout (timeout)
  self.sock._timeout = timeout
end

function websocket:connect ()
  if self.state then
    return nil, 'already connected.'
  end
  local ok, err
  -- 切割URL
  ok, err = url_split(self)
  if not ok then
    return nil, err
  end
  -- Websocket握手流程
  ok, err = do_handshake(self)
  if not ok then
    return nil, err
  end
  self.state = true
  return true, err
end

function websocket:request(func)
  if not self.queue then
    self.queue = new_tab(16, 0)
    self.co = cf_fork(function ()
      -- print("do")
      for _, f in ipairs(self.queue) do
        local ok, err = pcall(f)
        if not ok then
          Log:ERROR(err)
        end
      end
      -- print("end")
      self.co, self.queue = nil, nil
    end)
  end
  return insert(self.queue, func)
end

-- 接受数据
function websocket:recv()
  if not self.state then
    return nil, 'not connected.'
  end
  local data, typ, err = _recv_frame(self.sock, self.max_payload_len, false)
  if not data then
    self.state = nil
    return false, err
  end
  return data, typ
end

-- 发送 text/binary
function websocket:send (data, bin)
  if not self.state then
    return nil, 'not connected.'
  end
  assert(type(data) == 'string' and data ~= '', "Invalid websocket send data.")
  local sock = self.sock
  return _send_frame(sock, true, bin and 0x02 or 0x01, data, self.send_masked, self.ext)
end

-- 发送ping
function websocket:ping(data)
  if not self.state then
    return nil, 'not connected.'
  end
  local sock = self.sock
  return _send_frame(sock, true, 0x09, type(data) == 'string' and #data <= 125 and data or "", self.send_masked, self.ext)
end

-- 发送pong
function websocket:pong(data)
  if not self.state then
    return nil, 'not connected.'
  end
  local sock = self.sock
  return _send_frame(sock, true, 0x0A, type(data) == 'string' and #data <= 125 and data or "", self.send_masked, self.ext)
end

-- 清理连接
function websocket:close ()
  if self.sock then
    local sock = self.sock
    return self:request(function ()
      if self.state then
        return _send_frame(sock, true, 0x08, strpack(">H", 1000), self.send_masked, self.ext)
      end
    end)
  end
end

return websocket
