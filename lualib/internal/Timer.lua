local sys = require "sys"
local time = sys.time

local co = require "internal.Co"
local ti = require "timer"

local type = type
local ti_new = ti.new
local ti_start = ti.start

local co_new = co.new
local co_wait = co.wait
local co_spawn = co.spawn
local co_wakeup = co.wakeup
local co_self = co.self

local co_start = coroutine.resume
local co_wait_ex = coroutine.yield

local tab = debug.getregistry()
if tab['__G_TIMER__'] then
  return tab['__G_TIMER__']
end

local Timer = {}
tab['__G_TIMER__'] = Timer

local TMap = {}

local function get_tid(offset)
  return (time() + offset * 1e3) * 0.1 // 1
end

local function get_ctx(tid)
  return TMap[tid]
end

local function set_ctx(tid, ctx)
  if not ctx then
    TMap[tid] = nil
    return
  end
  local list = TMap[tid]
  if not list then
    TMap[tid] = {ctx}
  else
    list[#list+1] = ctx
  end
  return ctx
end

local TTimer = ti_new()
Timer.TTimer = TTimer

Timer.TCo = co_new(function ()
  local TNow = get_tid(0)
  co_wait_ex(co_self())
  while true do
    local now = get_tid(0)
    -- print("距离",  now - TNow )
    for tid = TNow, now, 1 do
      local list = get_ctx(tid)
      if list then
        for idx = 1, #list do
          local ctx = list[idx]
          if ctx[1] then
            co_spawn(ctx[3])
            if ctx[4] then -- 如果需要重复
              set_ctx(get_tid(ctx[2]), ctx)
            end
          end
        end
        set_ctx(tid, nil)
      end
    end
    TNow = now
    co_wait_ex()
  end
end)

-- 初始化
co_start(Timer.TCo)
-- 选一个误差最小的间隔
ti_start(TTimer, 0.01, Timer.TCo)

---@class Timer @定时器对象

---comment 初始化定时器对象
---@param timeout number   @超时时间
---@param again   boolean  @是否重复
---@param func    function @回调函数
---@return Timer
local function Timer_Init(timeout, again, func)
  local ctx = set_ctx(get_tid(timeout), { true, timeout, func, again })
  return {
    stop = function (self)
      if self and ctx and ctx[1] then
        ctx[1] = false
      end
    end
  }
end

---comment 一次性定时器
---@param timeout   number   @超时时间
---@param callback  function @回调函数
function Timer.timeout(timeout, callback)
  if type(timeout) ~= 'number' or timeout <= 0 or type(callback) ~= 'function' then
    return
  end
  return Timer_Init(timeout, false, callback)
end

---comment 重复定时器
---@param repeats   number   @间隔时间
---@param callback  function @回调函数
function Timer.at(repeats, callback)
  if type(repeats) ~= 'number' or repeats <= 0 or type(callback) ~= 'function' then
    return
  end
  return Timer_Init(repeats, true, callback)
end

---comment 休眠当前协程
---@param nsleep    number  @休眠时间(毫秒)
function Timer.sleep(nsleep)
  if type(nsleep) ~= 'number' or nsleep <= 0 then
    return
  end
  local coctx = co_self()
  Timer_Init(nsleep, false, function ()
    return co_wakeup(coctx)
  end)
  co_wait()
end

return Timer