local co = require "internal.Co"
local ti = require "timer"

local new_tab = require("sys").new_tab

local type = type
local pcall = pcall
local assert = assert

local insert = table.insert
local remove = table.remove

local ti_new = ti.new
local ti_start = ti.start
local ti_stop = ti.stop

local co_new = co.new
local co_wait = co.wait
local co_spawn = co.spawn
local co_wakeup = co.wakeup
local co_self = co.self


local TIMER_LIST = new_tab(1 << 10, 0)

local TIMER_MAP = new_tab(0, 1 << 10)

-- 内部函数防止被误用
local function Timer_new()
  return remove(TIMER_LIST) or ti_new()
end

-- 启动定时器
local function Timer_start(obj)
  obj.t = Timer_new()
  TIMER_MAP[obj] = obj
  ti_start(obj.t, obj.timeout or obj.repeats, obj.co)
  return obj
end

-- 停止定时器
local function Timer_stop(obj)
  if not obj or not obj.stoped then
    obj.stoped = true
    local o = assert(TIMER_MAP[obj], "[Timer ERROR]: Invalid timer object.")
    ti_stop(o.t); insert(TIMER_LIST, o.t);
    TIMER_MAP[o] = nil; o.t = nil; o.co = nil
  end
end

local Timer = { __VERSION__ = 0.2 }

local function stop(t)
  assert(type(t) == 'table', "[Timer ERROR]: stop timer must like `t:stop()`. ")
  t.stoped = true
end

function Timer.timeout(timeout, cb)
  if type(timeout) ~= 'number' or timeout <= 0 then
    return
  end
  assert(type(cb) == 'function', "[Timer ERROR]: Invalid callback.")
  local timer = { stop = stop }
  timer.co = co_spawn(function ()
    Timer.sleep(timeout)
    if timer.stoped then
      timer.co = nil
      return
    end
    local ok, errinfo = pcall(cb)
    if not ok then
      print("[Timer ERROR]: " .. errinfo)
    end
    -- 停止定时器
  end)
  return timer
end

function Timer.at(timeout, cb)
  if type(timeout) ~= 'number' or timeout <= 0 then
    return
  end
  assert(type(cb) == 'function', "[Timer ERROR]:  Invalid callback.")
  local timer = { stop = stop }
  timer.co = co_spawn(function ()
    while true do
      Timer.sleep(timeout)
      if timer.stoped then
        timer.co = nil
        return
      end
      co_spawn(cb)
    end
    -- 停止定时器
  end)
  return timer
end

function Timer.sleep(timeout)
  if type(timeout) ~= 'number' or timeout <= 0 then
    return
  end
  local current_co = co_self()
  local t = {stoped = false, timeout = timeout, stop = Timer_stop, t = nil, co = nil}
  t.co = co_new(function ( )
    Timer_stop(t)
    return co_wakeup(current_co)
  end)
  Timer_start(t)
  return co_wait()
end

return Timer