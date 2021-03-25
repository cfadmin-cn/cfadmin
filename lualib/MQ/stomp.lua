local class = require "class"
local stomp = require "protocol.stomp"

local logging = require "logging"
local Log = logging:new{dump = true, path = 'MQ-stomp'}

local cf = require "cf"
local cf_fork = cf.fork
local cf_sleep = cf.sleep

local ipairs = ipairs
local type = type
local insert = table.insert

local mq = class('stomp-mq')

function mq:ctor (opt)
  self.host = opt.host
  self.port = opt.port
  self.vhost = opt.vhost
  self.header = opt.header
  self.username = opt.username
  self.password = opt.password
  self.patterns = {}
  self.subsribes = {}
end

local function _login (opt)
  local times = 1
  while 1 do
    local mq = stomp:new {
      host = opt.host, port = opt.port, vhost = opt.vhost, auth = opt.auth,
      header = opt.header, username = opt.username, password = opt.password,
    }
    local ok, err = mq:connect()
    if ok then
      return mq
    end
    Log:WARN("第"..times.."次连接MQ(stomp)失败:"..(err or "未知错误."))
    times = times + 1
    mq:close()
    cf_sleep(3)
  end
end

-- 订阅事件循环
local function subscribe (self, pattern, func)
  local m = _login(self)
  insert(self.subsribes, m)
  return m:subscribe(pattern, func)
end

-- 发布事件循环
local function publish (self, pattern, data)
  if not self.queue then
    self.queue = {}
    cf_fork(function ()
      for _, msg in ipairs(self.queue) do
        if self.closed or not self.emiter:publish(msg.pattern, msg.data) then
          break
        end
      end
      self.queue = nil
    end)
  end
  insert(self.queue, {pattern = pattern, data = data})
  return true
end

-- 订阅
function mq:on (pattern, func)
  assert((type(pattern) == 'string' and pattern ~= '') and type(func) == 'function', "[STOMP ERROR] : Invalid `pattern`/`func` type.")
  for _, patt in ipairs(self.patterns) do
    if patt == pattern then
      return nil, '[STOMP ERROR] : already subscribe.'
    end
  end
  insert(self.patterns, pattern)
  -- self.patterns[#self.patterns + 1] = pattern
  return subscribe(self, pattern, func)
end

-- 发布
function mq:emit (pattern, data)
  assert((type(pattern) == 'string' and pattern ~= '') and (type(data) == 'string' and data ~= ''), "[STOMP ERROR] : Invalid `pattern`/`data` type.")
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
