local co = require "internal.Co"
local ti = require "timer"
local log = require "log"

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
    return ti.new()
end

-- 超时器 --
function Timer.timeout(timeout, cb)
    if not timeout or timeout < 0 then
        return
    end
    local ti = Timer_new()
    if not ti then
        log.error("timeout error: Create timer class error! memory maybe not enough...")
        return
    end
    local t = {
        stop = function (...)
            ti:stop()
            insert(TIMER_LIST, ti)
        end,
        co = co_new(function (...)
            local ok, err = pcall(cb)
            if not ok then
               log.error('timeout error:', err)
            end
            ti:stop()
            insert(TIMER_LIST, ti)
        end)
    }
    ti:start(timeout, t.co)
    return t
end

return Timer
