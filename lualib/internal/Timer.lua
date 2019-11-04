local co = require "internal.Co"
local ti = require "timer"

local type = type
local ti_new = ti.new
local ti_start = ti.start
local ti_stop = ti.stop

local co_new = co.new
local co_wait = co.wait
local co_spwan = co.spwan
local co_wakeup = co.wakeup
local co_self = co.self

local co_self_ex = coroutine.running
local co_wait_ex = coroutine.yield
local co_wakeup_ex = coroutine.resume

local remove = table.remove

local Timer = {}

local TIMER_LIST = {}

-- 内部函数防止被误用
local function Timer_new()
  if #TIMER_LIST > 0 then
    return remove(TIMER_LIST)
  end
  return ti_new()
end

local function Timer_release(t)
  ti_stop(t)
  TIMER_LIST[#TIMER_LIST+1] = t
end

local function Timer_start(self)
  Timer[self] = self
  ti_start(self.t, self.timeout or self.repeats, self.co)
end

local function Timer_stop(self)
  if self and not self.stoped then
    self.stoped = true
    if self.t then
      Timer_release(self.t)
      self.t = nil
    end
    Timer[self] = nil
  end
end

function Timer.count()
  return #TIMER_LIST
end

-- 超时器 --
function Timer.timeout(timeout, cb)
  if type(timeout) ~= 'number' or timeout <= 0 then
    return
  end
  if type(cb) ~= 'function' then
    return
  end
  local t = Timer_new()
  if not t then
    return
  end
  local once = {stoped = false, timeout = timeout, stop = Timer_stop, t = t, co = nil}
  once.co = co_new(function( ... )
    if once.stoped then
      return
    end
    co_spwan(cb)
    Timer_stop(once)
  end)
  Timer_start(once)
  return once
end

-- 循环定时器 --
function Timer.at(repeats, cb)
  if type(repeats) ~= 'number' or repeats <= 0 then
    return
  end
  if type(cb) ~= 'function' then
    return
  end
  local t = Timer_new()
  if not t then
    return
  end
  local at = {stoped = false, repeats = repeats, stop = Timer_stop, t = t, co = nil}
  at.co = co_new(function( ... )
    while 1 do
      if at.stoped then
        return
      end
      co_spwan(cb)
      co_wait_ex()
    end
  end)
  Timer_start(at)
  return at
end

-- 休眠 --
function Timer.sleep(timeout)
  if type(timeout) ~= 'number' or timeout <= 0 then
    return
  end
  local t = Timer_new()
  if not t then
    return
  end
  local sleep = {stoped = false, timeout = timeout, t = t, co = nil }
  local co = co_self()
  sleep.co = co_new(function (...)
    Timer_stop(sleep)
    return co_wakeup(co)
  end)
  Timer_start(sleep)
  return co_wait()
end

return Timer
