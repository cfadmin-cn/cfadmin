local co_new = coroutine.create
local co_start = coroutine.resume
local co_wakeup = coroutine.resume
local co_suspend = coroutine.yield
local co_self = coroutine.running

local ti = core_timer

local Timer = {}

local TIMER_LIST = {}

-- 超时器 --
function Timer.timeout(timeout, cb)
    if not timeout or timeout <= 0 then
        return
    end
    ti = Timer.get_timer()
    if not ti then
        print("[INFO] Create timer class error! memory maybe not enough...")
        return
    end
    local timer = {}
    timer.ti = ti
    timer.current_co = co_self()
    timer.cb = cb
    timer.closed = nil
    function timer_out( ... )
        if not timer.closed then
            local ok, err = pcall(timer.cb)
            if not ok then
                print ("[INFO] timer_out error:", err)
            end
        end
        table.insert(TIMER_LIST, timer.ti)
        timer.ti:stop()
        timer = nil
        return
    end
    timer.co = co_new(timer_out)
    timer.ti:start(timeout, timeout, timer.co)
end

-- 定时器 --
function Timer.ti(repeats, cb)
    if not repeats or repeats <= 0 then
        return
    end
    local ti = Timer.get_timer()
    if not ti then
        print("[INFO] Create timer class error! memory maybe not enough...")
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
                timer = nil
                return
            end
            local ok, err = pcall(timer.cb)
            if not ok then
                table.insert(TIMER_LIST, timer.ti)
                timer.ti:stop()
                timer = nil
                print("[ERROR] timer_repeats error:", err)
                return
            end
            co_suspend()
        end
    end
    timer.co = co_new(timer_repeats)
    timer.ti:start(repeats, repeats, timer.co)
    return timer
end

-- 仅让出执行权 --
function Timer.sleep(second)
    if not second or second <= 0 then
        return
    end
    local ti = Timer.get_timer()
    if not ti then
        LOG("INFO", "new timer class error! memory maybe not enough...")
        return
    end
    local timer = { }
    timer.ti = ti
    timer.current_co = co_self()
    timer.co = co_new(function ( ... )
        local co = timer.co
        local ti = timer.ti
        local current_co = timer.current_co
        table.insert(TIMER_LIST, ti)
        ti:stop()
        co_wakeup(current_co)
        timer = nil
    end)
    timer.ti:start(second, second, timer.co)
    return co_suspend()
end

return Timer