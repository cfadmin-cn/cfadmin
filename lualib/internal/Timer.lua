require "internal.coroutine"
require "utils"

local ti = core_timer

local Timer = {}

local TIMER_LIST = {}

function Timer.get_timer()
    if #TIMER_LIST > 0 then
        return table.remove(TIMER_LIST)
    end
    return ti.new()
end

-- 超时器 --
function Timer.timeout(timeout, cb)
    ti = Timer.get_timer()
    if not ti then
        print("new timer class error! memory maybe not enough...")
        return
    end
    local timer = {}
    timer.ti = ti
    timer.current_co = co_self()
    timer.cb = cb
    timer.closed = nil
    function timer_out( ... )
        if timer.closed then
            table.insert(TIMER_LIST, timer.ti)
            timer.ti:stop()
            timer.current_co = nil
            timer.ti = nil
            timer.cb = nil
            timer = nil
            return
        end
        local ok, msg = pcall(timer.cb)
        if not ok then
            print("timer_out error:", msg)
        end
        table.insert(TIMER_LIST, timer.ti)
        timer.ti:stop()
        timer.current_co = nil
        timer.ti = nil
        timer.cb = nil
        timer = nil
        return
    end
    timer.co = co_new(timer_out)
    timer.ti:start(timeout, timeout, timer.co)
end

-- 定时器 --
function Timer.ti(repeats, cb)
    local ti = Timer.get_timer()
    if not ti then
        print("new timer class error! memory maybe not enough...")
        return
    end
    local timer = {}
    timer.ti = ti
    timer.repeats = repeats
    timer.current_co = co_self()
    timer.cb = cb
    timer.closed = nil
    function timer_repeats( ... )
        while 1 do
            if timer.closed then
                table.insert(TIMER_LIST, timer.ti)
                timer.ti:stop()
                timer.current_co = nil
                timer.repeats = nil
                timer.ti = nil
                timer.cb = nil
                timer = nil
                return
            end
            local ok, msg = pcall(timer.cb)
            if not ok then
                table.insert(TIMER_LIST, timer.ti)
                timer.ti:stop()
                timer.current_co = nil
                timer.repeats = nil
                timer.ti = nil
                timer.cb = nil
                timer = nil
                print("timer_repeats error:", msg)
                return
            end
            co_suspend()
        end
    end
    timer.co = co_new(timer_repeats)
    timer.ti:start(repeats, repeats, timer.co)
    return timer
end

return Timer