local Co = require "internal.Co"
local self = Co.self
local fork = Co.spwan
local wait = Co.wait
local wakeup = Co.wakeup

local Timer = require "internal.Timer"
local at = Timer.at
local sleep = Timer.sleep
local time_out = Timer.timeout

local cf = {}

-- 创建一个由cf管理的超时器
function cf.timeout(timeout, func)
  return time_out(timeout, func)
end

-- 创建一个由cf管理的循环定时器
function cf.at(repeats, func)
  return at(repeats, func)
end

-- 协程休眠指定时间
function cf.sleep(time)
  return sleep(time)
end


function cf.self ()
  return self()
end

-- 让出协程
function cf.wait()
  return wait()
end

-- 创建一个由cf框架调度的协程
function cf.fork(func, ...)
  return fork(func, ...)
end

-- 唤醒一个由cf框架创建的协程
function cf.wakeup(co, ...)
  return wakeup(co, ...)
end

-- 使用cf内置dns来解析域名, version表示想得到ipv6回应还是ipv4回应
function cf.resolve(domain, version)
  -- TODO
end

return cf
