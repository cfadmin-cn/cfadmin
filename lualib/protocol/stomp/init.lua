local class = require "class"
local tcp = require "internal.TCP"

local cf = require "cf"
local cf_fork = cf.fork
local cf_wait = cf.wait
local cf_self = cf.self
local cf_wakeup = cf.wakeup

local logging = require "logging"
local Log = logging:new{ dump = true, path = "protocol-stomp"}

local protocol = require "protocol.stomp.protocol"
local protocol_send = protocol.send
local protocol_ack = protocol.ack
local protocol_subscribe = protocol.subscribe
local protocol_unsubscribe = protocol.unsubscribe
local protocol_disconnect = protocol.disconnect
local connect_and_login = protocol.connect

local type = type
local ipairs = ipairs
local fmt = string.format
local random = math.random

local stomp = class("stomp")

function stomp:ctor (opt)
  self.id = opt.id or fmt('luastomp-cf-v1-0x%08X', random(0xFFFFFFFF))
  self.ssl = opt.ssl
  self.sock = tcp:new()
  self.host = opt.host
  self.port = opt.port
  self.vhost = opt.vhost or ""
  self.username = opt.username
  self.password = opt.password
end

-- 连接
function stomp:connect ()
  local ok, data = connect_and_login(self, {
    ['id'] = self.id,
    ['vhost'] = self.vhost,
    ['login'] = self.username,
    ['username'] = self.username,
    ['passcode'] = self.password,
    ['password'] = self.password,
  })
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

function stomp:publish (topic, data)
  if not self.state then
    return nil, "stomp未连接"
  end
  if type(topic) ~= 'string' or type(data) ~= 'string' then
    return nil, "错误的topic或data"
  end
  return protocol_send(self, {
    topic = topic,
    data = data
  })
end

function stomp:subscribe (topic, func)
  if not self.state then
    return nil, "stomp未连接"
  end
  if type(topic) ~= 'string' then
    return nil, '错误的stopic订阅参数'
  end
  local co = cf_self()
  cf_fork(function ()
    local ok, pack = protocol_subscribe(self, topic, self.topic)
    if not ok then
      self.state = nil
      return cf_wakeup(co, ok, pack)
    end
    cf_wakeup(co, ok, pack)
    while 1 do
      local ok, msg = protocol_subscribe(self, topic, self.topic)
      if not ok then
        local ok, err = pcall(func, msg)
        if not ok then
          Log:ERROR(err)
        end
        return
      end
      local ok, err = pcall(func, {
        len = msg['content-length'],
        id = msg['message-id'],
        session = msg['session'],
        payload = msg['body'],
        pattern = msg['destination'],
      })
      if not ok then
        Log:ERROR(err)
      end
    end
  end)
  return cf_wait()
end

function stomp:unsubscribe (...)
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
