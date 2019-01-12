local co = require "internal.Co"
local ti = require "timer"
local log = require "log"

local ti_new = ti.new
local ti_start = ti.start
local ti_stop = ti.stop
local co_new = co.new
local co_wait = co.wait
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
    if not timeout or timeout < 0 then
        return
    end
    local t = Timer_new()
    if not t then
        return log.error("timeout error: Create timer class error! memory maybe not enough...")
    end
    local timer = {
        stop = function (...)
            Timer_release(t)
        end,
        co = co_new(function (...)
            Timer_release(t)
            local ok, err = pcall(cb)
            if not ok then
               log.error('timeout error:', err)
            end
        end)
    }
    ti_start(t, timeout, timer.co)
    return timer
end

-- 循环定时器 --
function Timer.at(repeats, cb)
    if not repeats or repeats < 0 then
        return
    end
    local t = Timer_new()
    if not t then
        return log.error("timeout error: Create timer class error! memory maybe not enough...")
    end
    local timer = {
        stop = function (...)
            Timer_release(t)
        end,
        co = co_new(function (...)
            while 1 do
                local ok, err = pcall(cb)
                if not ok then
                   log.error('timeat error:', err)
                end
                co_wait()
            end
        end)
    }
   ti_start(t, repeats, timer.co)
    return timer
end

return Timer
