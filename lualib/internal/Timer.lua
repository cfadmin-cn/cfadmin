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

local Timer = {}

local TMap = {}

local tab = debug.getregistry()
tab['__G_TIMER__'] = TMap

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
  local run_idx, time_idx, func_idx, again_idx, async_idx = 1, 2, 3, 4, 5
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
          if ctx[run_idx] then
            local cb = ctx[func_idx]
            if ctx[async_idx] then
              cb()
            else
              co_spawn(cb)
            end
            if ctx[again_idx] then -- 如果需要重复
              set_ctx(get_tid(ctx[time_idx]), ctx)
            end
          end
        end
        set_ctx(tid, nil)
      end
    end
    TNow = now + 1
    co_wait_ex()
  end
end)

-- 初始化
co_start(Timer.TCo)
-- 选更小的时间来定期检查.
ti_start(TTimer, 0.01, Timer.TCo)

---@class Timer @定时器对象
local class = require "class"

local TIMER = class("Timer")

-- 初始化
function TIMER:ctor() end
-- 停止定时器
function TIMER:stop() if self then self[1] = false end end

---comment 初始化定时器对象
---@param timeout number   @超时时间
---@param again   boolean  @是否重复
---@param async   boolean  @直接调用
---@param func    function @回调函数
---@return Timer  @定时器对象
local function Timer_Init(timeout, again, async, func)
  return set_ctx(get_tid(timeout), setmetatable({true, timeout, func, again, async}, TIMER))
end

---comment 一次性定时器
---@param timeout   number   @超时时间
---@param callback  function @回调函数
function Timer.timeout(timeout, callback)
  if type(timeout) ~= 'number' or timeout <= 0 or type(callback) ~= 'function' then
    return
  end
  return Timer_Init(timeout, false, false, callback)
end

---comment 重复定时器
---@param repeats   number   @间隔时间
---@param callback  function @回调函数
function Timer.at(repeats, callback)
  if type(repeats) ~= 'number' or repeats <= 0 or type(callback) ~= 'function' then
    return
  end
  return Timer_Init(repeats, true, false, callback)
end

---comment 休眠当前协程
---@param nsleep    number  @休眠时间(毫秒)
function Timer.sleep(nsleep)
  if type(nsleep) ~= 'number' or nsleep <= 0 then
    return
  end
  local coctx = co_self()
  Timer_Init(nsleep, false, true, function ()
    return co_wakeup(coctx)
  end)
  co_wait()
end

---comment 刷新
function Timer.flush()
  local Map = {}
  for key, value in pairs(TMap) do
    Map[key] = value
  end
  TMap = Map
  tab['__G_TIMER__'] = Map
end

return Timer