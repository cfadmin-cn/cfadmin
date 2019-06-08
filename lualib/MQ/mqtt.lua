local class = require "class"
local mqtt = require "protocol.mqtt"

local logging = require "logging"
local Log = logging:new{dump = true, path = 'MQ-mqtt'}

local cf = require "cf"
local cf_self = cf.self
local cf_fork = cf.fork
local cf_sleep = cf.sleep
local cf_wait = cf.wait
local cf_wakeup = cf.wakeup

local ipairs = ipairs
local type = type
local insert = table.insert
local random = math.random
local fmt = string.format

local mq = class('mqtt-mq')

function mq:ctor (opt)
  self.host = opt.host
  self.port = opt.port
  self.username = opt.username
  self.password = opt.password
  self.keepalive = opt.keepalive
  self.patterns = {}
  self.subsribes = {}
  self.queue = {}
end

local function _login (opt)
  local times = 1
  while 1 do
    local mq = mqtt:new {
      id = opt.id or fmt('luamqtt-cf-v1-%X', random(1, 0xFFFFFFFF)),
      host = opt.host,
      port = opt.port,
      clean = true,
      keep_alive = opt.keepalive,
      auth = {
        username = opt.username,
        password = opt.password,
      },
    }
    local ok, err = mq:connect()
    if ok then
      return mq
    end
    Log:WARN("第"..times.."次连接MQ(mqtt)失败:"..(err or "未知错误."))
    times = times + 1
    mq:close()
    cf_sleep(3)
  end
end

-- 订阅事件循环
local function subscribe (self, pattern, func)
  local mq = _login(self)
  self.subsribes[#self.subsribes+1] = mq
  return mq:subscribe({qos = 2, topic = pattern}, func)
end

-- 发布事件循环
local function publish (self, pattern, data)
  if #self.queue == 0 then
    self.queue[#self.queue + 1] = {pattern = pattern, data = data, co = cf_self()}
    cf_fork(function (...)
      for _, msg in ipairs(self.queue) do
        if not self.closed and self.emiter then
          cf_wakeup(msg.co, self.emiter:publish{topic = msg.pattern, payload = msg.data, qos = 2})
        end
      end
      self.queue = {}
    end)
    return cf_wait()
  end
  insert(self.queue, {pattern = pattern, data = data, co = cf_self()})
  return cf_wait()
end

-- 订阅
function mq:on (pattern, func)
  if type(pattern) ~= 'string' or pattern == '' then
    return nil, "订阅消息失败: 错误的pattern类型"
  end
  if type(func) ~= 'function' then
    return nil, "订阅消息失败: 错误的func类型"
  end
  for _, patt in ipairs(self.patterns) do
    if patt == pattern then
      return nil, '禁止重复订阅相同的频道'
    end
  end
  self.patterns[#self.patterns + 1] = pattern
  return subscribe(self, pattern, func)
end

-- 发布
function mq:emit (pattern, data)
  if type(pattern) ~= 'string' or pattern == '' then
    return nil, "推送消息失败: 错误的pattern类型"
  end
  if type(data) ~= 'string' or data == '' then
    return nil, "推送消息失败: 错误的data类型"
  end
  if not self.emiter then
    self.emiter = _login(self)
  end
  return publish(self, pattern, data)
end

-- 启动MQ服务
function mq:start()
  return cf.wait()
end

-- 关闭MQ服务
function mq:close ()
  self.closed = true
  if self.emiter then
    self.emiter:close()
    self.emiter = nil
  end
  if self.subsribes then
    for _, sub in ipairs(self.subsribes) do
      sub:close()
    end
    self.subsribes = nil
  end
end

return mq
