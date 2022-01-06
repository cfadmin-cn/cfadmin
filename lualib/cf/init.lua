local Co = require "internal.Co"
local co_self = Co.self
local co_fork = Co.spawn
local co_wait = Co.wait
local co_wakeup = Co.wakeup

local Timer = require "internal.Timer"
local time_at = Timer.at
local time_sleep = Timer.sleep
local time_out = Timer.timeout

local type = type
local error = error
local ipairs = ipairs
local tonumber = tonumber
local loadfile = loadfile

local loadfilex = package.searchers[2]

local cf = {}

---comment  指定的`filename`文件内容为入口创建一个协程.
---@param filename string @可被`loadfile`或`require`加载的代码文件.
---@param ... any         @可选传递的可变参.
function cf.run(filename, ...)
  local f, errinfo = loadfile(filename, 'bt')
  if not f then
    f = loadfilex(filename)
    if type(f) ~= 'function' then
      return assert(nil, '\n' .. errinfo .. ' and ' .. f )
    end
  end
  return cf.fork(f, ...)
end

---comment  创建一个由cf管理的超时器(只会触发一次)
---@param timeout number @`timeout`大于0才会创建定时器.
---@param func function  @时间到期后将会调用此函数.
function cf.timeout(timeout, func)
  return time_out(timeout, func)
end

---comment  创建一个由cf管理的循环定时器(需要手动停止)
---@param timeout number @`timeout`大于0才会创建定时器.
---@param func function  @间隔时间到期后将会调用此函数.
---@return table @返回一个`timer`对象, 调用`timer:stop()`方法可停止.
function cf.at(timeout, func)
  return time_at(timeout, func)
end

---comment 让出协程执行权
local function yield ()
  local co = co_self()
  co_fork(function ()
    co_wakeup(co)
  end)
  return co_wait()
end
cf.yield = yield

---comment 让出当前协程执行权并休眠`timeout`秒
---@param timeout number @`timeout`大于0才会创建定时器.
function cf.sleep(timeout)
  timeout = tonumber(timeout)
  if timeout and timeout > 0 then
    return time_sleep(timeout)
  end
  return yield()
end

---comment 获取调用此方法的协程对象.
---@return thread
function cf.self ()
  return co_self()
end

---comment 让出协程
function cf.wait()
  return co_wait()
end

---comment  创建一个由cf框架调度的协程
---@param func function @协程的执行的函数
---@return thread 协程对象
function cf.fork(func, ...)
  return co_fork(func, ...)
end

---comment 唤醒一个由cf框架创建的协程
---@param co thread @被唤醒的协程对象与需要传递给协程的参数
---@return nil
function cf.wakeup(co, ...)
  return co_wakeup(co, ...)
end

local function cb(f, ctx)
  local ok, errinfo = pcall(f)
  ctx.waits = ctx.waits - 1
  if ctx.waits == 0 then
    co_wakeup(ctx.co)
  end
  if not ok then
    return error(errinfo)
  end
end

---comment 并发执行多协程, 指定的协程都结束后返回.
---@param fn function @至少一个或多个任务函数
---@return nil @始终不存在返回值.
function cf.join(fn, ...)
  local qlist = {fn, ...}
  local ctx = { co = co_self(), waits = nil }
  local waits = 0
  for _, f in ipairs(qlist) do
    if type(f) == 'function' then
      co_fork(cb, f, ctx)
      waits = waits + 1
    end
  end
  ctx.waits = waits
  return co_wait()
end

return cf
