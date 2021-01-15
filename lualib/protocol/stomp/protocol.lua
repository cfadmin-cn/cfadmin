local system = require "system"

local is_array_member = system.is_array_member

local type = type
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local toint = math.tointeger

local find = string.find
local split = string.sub
local splite = string.gmatch

local concat = table.concat

local LF = '\x0a'
local LF2 = '\x0a\x0a'
local NULL = '\x00'
local CRLF = "\x0d\x0a"
local CRLF2 = "\x0d\x0a\x0d\x0a"
local NULL_LF = "\x00\x0a"

-- 支持的版本列表
local versions = { 1.2, 1.1, 1.0 }


local CMDS = {
  ["CONNECTED"] = true,
  ["SEND"] = true,
  ["MESSAGE"] = true,
  ["SUBSCRIBE"] = true,
  ["UNSUBSCRIBE"] = true,
  ["ABORT"] = true,
  ["DISCONNECT"] = true,
  ["ERROR"] = true,
}


-- 支持版本
local function version_support (ver)
  if type(ver) == 'string' or type(ver) == 'number' then
    ver = tonumber(ver)
    if not ver then
      return nil, "1. Unsupported version."
    end
    for _, version in ipairs(versions) do
      if ver == version then
        return true
      end
    end
  end
  if type(ver) == 'table' then
    for _, v in ipairs(ver) do
      if is_array_member(versions, tonumber(v)) then
        return true
      end
    end
  end
  return false, '2. Unsupported version.'
end

local function sock_send (sock, data)
  if sock.ssl then
    return sock:ssl_send(data)
  end
  return sock:send(data)
end

local function sock_read (sock, byte)
  if sock.ssl then
    return sock:ssl_recv(byte)
  end
  return sock:recv(byte)
end

local function sock_connect (sock, ssl, host, port)
  if ssl then
    return sock:ssl_connect(host, port)
  end
  return sock:connect(host, port)
end

local function parser_cmd (data)
  local _, Pos = find(data, '\x0a')
  if not Pos then
    return nil, "Command Parse Error."
  end
  local cmd = split(data, 1, Pos - 1)
  local exists = CMDS[cmd]
  if not exists then
    return nil, "Unsupported command: "..(data or cmd or data)
  end
  return cmd, Pos + 1
end

local function parser_header (data)
  local HEADERS = {}
  for key, value in splite(data, "([^:]+):([^\x0a]+)[\x0d]?\x0a") do
    if key:lower() == 'version' then
      local tab = {}
      for ver in splite(value, '([^,]+)') do
        tab[#tab+1] = ver
      end
      value = tab
    end
    if key:lower() == 'heart-beat' then
      local tab = {}
      for num in splite(value, '([^,]+)') do
        tab[#tab+1] = num
      end
      value = tab
    end
    HEADERS[key] = value
  end
  return HEADERS
end

local function build_frame (CMD, opt, body)
  local req = { CMD, "version:"..concat(versions, ',') }
  for key, value in pairs(opt) do
    req[#req+1] = key..":"..value
  end
  if body then
    req[#req+1] = "content-type:text/plain;charset=utf-8"
    req[#req+1] = "content-length:"..#body
  end
  return concat(req, CRLF)..CRLF2..(body or '')..NULL_LF
end

local function read_response (sock)
  local buffers = {}
  while 1 do
    local data = sock_read(sock, 1)
    if not data then
      return nil, "Server Close this session."
    end
    buffers[#buffers + 1] = data
    local response = concat(buffers)
    if find(response, NULL_LF) then
      local cmd, pos = parser_cmd(response)
      if not cmd then
        return cmd, pos
      end
      local headers = parser_header(split(response, pos, find(response, LF, -2) - 1))
      local ver = headers['version'] or headers['Version']
      if ver then
        local ok, err = version_support(ver)
        if not ok then
          return nil, err
        end
      end
      local body_len = toint(headers['content-length'] or headers['Content-length'])
      if body_len then
        headers['body'] = split(response, #response - body_len - 1, #response - 2)
      end
      headers["COMMAND"] = cmd
      if cmd == 'ERROR' then
        return nil, (headers["message"] or headers["Message"] or cmd)..','..(headers['body'] or "ERROR")
      end
      return true, headers
    end
    if #response > 10240 then
      return nil, 'Invalide Response.'
    end
  end
end


local protocol = {}


-- 连接
function protocol.connect (self, opt)
  local ok, err = sock_connect(self.sock, self.ssl, self.host, self.port)
  if not ok then
    self.state = nil
    return nil, "连接到stomp服务器失败"
  end
  local ok = sock_send(self.sock, build_frame("CONNECT", opt))
  if not ok then
    self.state = nil
    return nil, '发送CONNECT失败.'
  end
  return read_response(self.sock)
end

-- 发布消息
function protocol.send (self, opt)
  local ok = sock_send(self.sock, build_frame("SEND", {
    ['id'] = self.id,
    ['session'] = self.session,
    ['destination'] = self.vhost..opt.topic,
  }, opt.data))
  if not ok then
    self.state = nil
    return nil, 'SEND数据失败.'
  end
  return true
end

-- 订阅消息
function protocol.subscribe (self, topic, already)
  if not already then
    local ok = sock_send(self.sock, build_frame("SUBSCRIBE", {
      ['id'] = self.id,
      ['session'] = self.session,
      ['destination'] = self.vhost..topic,
    }))
    if not ok then
      self.state = nil
      return nil, 'SUBSCRIBE 失败.'
    end
    self.topic = topic
    return true
  end
  local ok, pack = read_response(self.sock)
  if not ok then
    self.state = nil
    return nil, pack
  end
  self.topic = topic
  return true, pack
end

-- 取消订阅
function protocol.unsubscribe (self, topic)
  local ok = sock_send(self.sock, build_frame("UNSUBSCRIBE", {
    ['id'] = self.id,
    ['session'] = self.session,
    ['destination'] = self.vhost..topic,
  }))
  self.topic = nil
  if not ok then
    self.state = nil
    return nil, 'UNSUBSCRIBE 失败.'
  end
  return read_response(self.sock)
end

-- 回应
function protocol.ack (self, opt)
  local ok = sock_send(self.sock, build_frame("ACK", {
    ['id'] = self.id,
    ['session'] = self.session,
    ['message-id'] = opt['message-id'],
    ['transaction'] = opt['transaction'],
  }))
  if not ok then
    self.state = nil
    return nil, "Send error"
  end
  return true
end

-- 断开连接
function protocol.disconnect (self)
  self.state = nil
  local ok = sock_send(self.sock, build_frame("DISCONNECT", {
    ['receipt'] = 1,
  }))
  if not ok then
    return nil, "Send error"
  end
  return true
end

return protocol
