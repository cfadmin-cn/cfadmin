require "internal.coroutine"
local ti = core_timer

-- 这里需要注意的是:
--    定时器会循环触发, 不能被手动终止. 这适用于定时任务;
--    超时器只会被触发一次, 并且在启动(超时)之前, 被手动终止;

local Timer = {}

local TIMER_LIST = {}

function Timer.get_timer()
    if #TIMER_LIST > 0 then
        return table.remove(TIMER_LIST)
    end
    return ti:new()
end

-- 超时器 --
function Timer.timeout(timeout, func)
    local timer_ctx = {
        closed = nil,
        co = nil,
    }
    local ti = Timer.get_timer()
    if not ti then
        print("new timer class error! memory maybe not enough...")
        return
    end
    local function cb(...)
        if timer_ctx.closed then
            return
        end
        local ok, error_msg = pcall(func, ...)
        if not ok then
            print(string.format("Timer.timeout error: ", error_msg))
        end
        timer_ctx.co = nil
        table.insert(TIMER_LIST, ti)
    end
    timer_ctx.co = co_create(cb)
    ti:start(timeout, 0, timer_ctx.co)
    return timer_ctx
end

-- 定时器 --
function Timer.ti(repeats, func)
    local co
    local ti = Timer.get_timer()
    if not ti then
        print("new timer class error! memory maybe not enough...")
        return
    end
    local function cb(...)
        while 1 do
            local ok, error_msg = pcall(func, ...)
            if not ok then
                print(string.format("Timer.timeout error: ", error_msg))
                break
            end
            co_suspend(co)
        end
        table.insert(TIMER_LIST, ti:stop())
    end
    co = co_create(cb)
    return ti:start(repeats, repeats, co)
end

return Timer