local class = require "class"
local tcp = require "internal.TCP"

local cf = require "cf"
local cf_fork = cf.fork

local logging = require "logging"
local Log = logging:new{ dump = true, path = "protocol-stomp"}

local protocol = require "protocol.stomp.protocol"
local protocol_send = protocol.send
local protocol_subscribe = protocol.subscribe
local protocol_unsubscribe = protocol.unsubscribe
local protocol_disconnect = protocol.disconnect
local connect_and_login = protocol.connect

local type = type
local assert = assert
local fmt = string.format
local random = math.random

local stomp = class("stomp")

function stomp:ctor (opt)
  self.id = opt.id or fmt('luastomp-cf-v1-0x%08X', random(0xFFFFFFFF))
  self.ssl = opt.ssl
  self.sock = tcp:new()
  self.host = opt.host
  self.port = opt.port
  self.header = opt.header
  self.vhost = opt.vhost or "/exchange"
  self.username = opt.username
  self.password = opt.password
end

-- 连接
function stomp:connect ()
  -- 如果需要扩展头部
  local opt = {
    ['id'] = self.id,
    ['client_id'] = self.id,
    ['vhost'] = self.vhost,
    ['login'] = self.username,
    ['username'] = self.username,
    ['passcode'] = self.password,
  }
  if type(self.header) == 'table' then
    for key, value in pairs(self.header) do
      opt[key] = value
    end
  end
  -- 登录授权
  local ok, data = connect_and_login(self, opt)
  if not ok then
    return ok, data
  end
  self.session = data.session
  self.state = true
  return true
end

function stomp:send (...)
  return self:publish(...)
end

function stomp:publish (topic, payload)
  if not self.state then
    return nil, "[STOMP ERROR] : client not connected."
  end
  if type(topic) ~= 'string' or topic == '' or type(payload) ~= 'string' or payload == '' then
    return nil, "[STOMP ERROR] : Invalide `topic` or `payload` arguments."
  end
  return protocol_send(self, { topic = topic, payload = payload })
end

function stomp:subscribe (topic, func)
  if not self.state then
    return nil, "[STOMP ERROR] : client not connected."
  end
  if type(topic) ~= 'string' or topic == '' or type(func) ~= 'function' then
    return nil, '[STOMP ERROR] : Invalide `topic` or `func` arguments.'
  end
  local errinfo
  assert(protocol_subscribe(self, topic))
  cf_fork(function ()
    while 1 do
      local ok, msg = protocol_subscribe(self, topic, true)
      if not ok then
        Log:ERROR(msg)
        ok, msg = pcall(func, false, msg)
        if not ok then
          Log:ERROR(msg)
        end
        return
      end
      ok, errinfo = pcall(func, {
        len = msg['content-length'],
        id = msg['message-id'],
        session = msg['session'],
        payload = msg['body'],
        pattern = msg['destination'],
      })
      if not ok then
        Log:ERROR(errinfo)
      end
    end
  end)
  return true
end

function stomp:unsubscribe ()
  if not self.state then
    return nil, "stomp未连接"
  end
  if not self.topic then
    return nil, '没有需要取消订阅的topic'
  end
  return protocol_unsubscribe(self, self.topic)
end

function stomp:disconnect ()
  if self.state then
    self.state = nil
    protocol_disconnect(self)
    self:close()
  end
end

-- 关闭
function stomp:close ()
  if self.sock then
    self.state = nil
    self.sock:close()
    self.sock = nil
  end
end

return stomp
