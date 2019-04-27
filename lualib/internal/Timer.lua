local co = require "internal.Co"
local ti = require "timer"
local log = require "logging"
local Log = log:new()

local type = type
local pcall = pcall
local ti_new = ti.new
local ti_start = ti.start
local ti_stop = ti.stop

local co_new = co.new
local co_wait = co.wait
local co_spwan = co.spwan
local co_wakeup = co.wakeup
local co_self = co.self

local insert = table.insert
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
    insert(TIMER_LIST, t)
end

function Timer.count( ... )
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
        return Log:ERROR("timeout error: Create timer class error! memory maybe not enough...")
    end
    local timer = {STOP = false}
    timer.stop = function (...)
        if timer.STOP then
          return
        end
        Timer_release(t)
        timer.STOP = true
        timer.co = nil
        Timer[timer] = nil
    end
    timer.co = co_new(function (...)
        Timer_release(t)
        local ok, err = pcall(cb)
        if not ok then
            Log:ERROR('timeout error:', err)
        end
        if timer.STOP then
          return
        end
        Timer[timer] = nil
        timer.STOP = true
        timer.co = nil
    end)
    Timer[timer] = timer
    ti_start(t, timeout, timer.co)
    return timer
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
        return Log:ERROR("timeout error: Create timer class error! memory maybe not enough...")
    end
    local timer = { STOP = false }
    timer.stop = function (...)
        if timer.STOP then
            return
        end
        Timer_release(t)
        timer.STOP = true
        timer.co = nil
        Timer[timer] = nil
    end
    timer.co = co_new(function ()
      local co_wait = coroutine.yield
        while 1 do
            if timer.STOP then
                return
            end
            co_spwan(cb)
            if timer.STOP then
              return
            end
            co_wait()
        end
    end)
    Timer[timer] = timer
    ti_start(t, repeats, timer.co)
    return timer
end

-- 休眠 --
function Timer.sleep(repeats)
    if type(repeats) ~= 'number' or repeats <= 0 then
        return
    end
    local t = Timer_new()
    if not t then
        return Log:ERROR("timeout error: Create timer class error! memory maybe not enough...")
    end
    local timer = {}
    timer.current_co = co_self()
    timer.co = co_new(function (...)
        local current_co = timer.current_co
        Timer[timer] = nil
        timer.current_co, timer.co = nil
        Timer_release(t)
        return co_wakeup(current_co)
    end)
    Timer[timer] = timer
    ti_start(t, repeats, timer.co)
    return co_wait()
end

return Timer
