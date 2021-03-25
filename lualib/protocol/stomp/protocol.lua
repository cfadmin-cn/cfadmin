local pairs = pairs
local toint = math.tointeger
local splite = string.gmatch
local concat = table.concat

local LF = '\x0a'
local LF2 = '\x0a\x0a'
local NULL_LF = "\x00\x0a"

-- 支持的版本列表
local versions = { 1.2, 1.1, 1.0}

local VERSION = {
  ['1.2'] = 1.2,
  ['1.1'] = 1.1,
  ['1.0'] = 1.0,
  ['1'] = 1.0,
}

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
local function version_support (list)
  for _, v in pairs(list) do
    if VERSION[v] then
      return true
    end
  end
  return false
end

local function sock_send (sock, data)
  return sock:send(data)
end

local function sock_read (sock, byte)
  local buffers = {}
  while true do
    local buf = sock:recv(byte)
    if not buf then
      return
    end
    buffers[#buffers+1] = buf
    byte = byte - #buf
    if byte == 0 then
      break
    end
  end
  return concat(buffers)
end

local function sock_readline(sock, sp, nosp)
  return sock:readline(sp, nosp)
end

local function sock_connect (sock, ssl, host, port)
  local ok, err = sock:connect(host, port)
  if not ok then
    return false, err
  end
  if ssl then
    ok = sock:ssl_handshake()
    if not ok then
      return false, "[STOMP ERROR] : SSL handshake failed."
    end
  end
  return true
end

local function parser_header (data)
  local HEADERS = {}
  for key, value in splite(data, "([^:]+):([^\x0a]+)[\x0a]?") do
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
  local req = { CMD, "version:" .. concat(versions, ',') }
  for key, value in pairs(opt) do
    req[#req+1] = key..":"..value
  end
  if body then
    -- req[#req+1] = "content-type:text/plain;charset=utf-8"
    req[#req+1] = "content-length:"..#body
  end
  return concat{concat(req, LF), LF2, (body or ''), NULL_LF}
end

local function read_response (sock)
  local response_cmd = sock_readline(sock, LF, true)
  if not response_cmd then
    return false, "[STOMP ERROR] : Server Close this session when receiving `cmd` data."
  end
  if not CMDS[response_cmd] then
    return false, "[STOMP ERROR] : client get Invalid `cmd` data : " .. response_cmd
  end
  -- print(response_cmd)
  local response_header = sock_readline(sock, LF2)
  if not response_header then
    return false, "[STOMP ERROR] : Server Close this session when receiving `headers` data."
  end
  local response = parser_header(response_header)
  local v = response['version'] or response['Version']
  if not v or not version_support(v) then
    -- print(v, version_support(v))
    return false, "[STOMP ERROR] : Unsupported Stomp protocol version."
  end
  -- var_dump(response)
  response["COMMAND"] = response_cmd
  local body_len = toint(response['content-length'] or response['Content-length'] or response['Content-Length'])
  if body_len and body_len > 0 then
    -- print("长度: ", body_len)
    local body = sock_read(sock, body_len)
    if not body then
      return false, "[STOMP ERROR] : Server Close this session when receiving `body` data."
    end
    -- print(body)
    response['body'] = body
  end
  sock_readline(sock, NULL_LF)
  -- var_dump(response)
  return true, response
end


local protocol = {}


-- 连接
function protocol.connect (self, opt)
  local ok = sock_connect(self.sock, self.ssl, self.host, self.port)
  if not ok then
    self.state = nil
    return nil, "[STOMP ERROR] : Server connnect refuse."
  end
  if not sock_send(self.sock, build_frame("CONNECT", opt)) then
    self.state = nil
    return nil, '[STOMP ERROR] : client send `CONNECT` failed.'
  end
  return read_response(self.sock)
end

-- 发布消息
function protocol.send (self, opt)
  local ok = sock_send(self.sock, build_frame("SEND", { ['id'] = self.id, ['session'] = self.session, ['destination'] = self.vhost .. opt.topic }, opt.payload))
  if not ok then
    self.state = nil
    return nil, '[STOMP ERROR] : `SEND` failed.'
  end
  return true
end

-- 订阅消息
function protocol.subscribe (self, topic, already)
  if not already then
    local ok = sock_send(self.sock, build_frame("SUBSCRIBE", { ['id'] = self.id, ['session'] = self.session, ['destination'] = self.vhost .. topic }))
    if not ok then
      self.state = nil
      return nil, '[STOMP ERROR] : `SUBSCRIBE` failed.'
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
  local ok = sock_send(self.sock, build_frame("UNSUBSCRIBE", { ['id'] = self.id, ['session'] = self.session, ['destination'] = self.vhost .. topic }))
  self.topic = nil
  if not ok then
    self.state = nil
    return nil, '[STOMP ERROR] : `UNSUBSCRIBE` failed.'
  end
  return read_response(self.sock)
end

-- 回应
function protocol.ack (self, opt)
  local ok = sock_send(self.sock, build_frame("ACK", { ['id'] = self.id, ['session'] = self.session, ['message-id'] = opt['message-id'], ['transaction'] = opt['transaction'] }))
  if not ok then
    self.state = nil
    return nil, "[STOMP ERROR] : `ACK` failed."
  end
  return true
end

-- 断开连接
function protocol.disconnect (self)
  self.state = nil
  return sock_send(self.sock, build_frame("DISCONNECT", { ['receipt'] = 1 }))
end

return protocol
