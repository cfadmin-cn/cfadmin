local ti = core_timer
local co_new = coroutine.create
local co_start = coroutine.resume
local co_wakeup = coroutine.resume
local co_suspend = coroutine.yield
local co_self = coroutine.running

local insert = table.insert
local remove = table.remove

local Timer = {}

local TIMER_LIST = {}

function Timer.get_timer()
    if #TIMER_LIST > 0 then
        return remove(TIMER_LIST)
    end
    return ti:new()
end

-- 超时器 --
function Timer.timeout(timeout, cb)
    if not timeout or timeout < 0 then
        return
    end
    ti = Timer.get_timer()
    if not ti then
        print("[INFO] Create timer class error! memory maybe not enough...")
        return
    end
    print(ti)
    local t = {
        stop = function ( ... )
            print("stop it..")
            ti:stop()
            insert(TIMER_LIST, ti)
        end,
        co = co_new(function ( ... )
            local ok, err = pcall(cb)
            if not ok then
                print ("[INFO] timeout error:", err)
            end
            ti:stop()
            insert(TIMER_LIST, ti)
        end)
    }
    ti:start(timeout, timeout, t.co)
    return t
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
    local t = {
        stop = function ( ... )
            ti:stop()
            insert(TIMER_LIST, ti)
        end,
        co = co_new(function ( ... )
            while 1 do
                local ok, err = pcall(cb)
                if not ok then
                    insert(TIMER_LIST, ti)
                    ti:stop()
                    return print("[ERROR] repeats error:", err)
                end
                co_suspend()
            end
        end)
    }
    ti:start(repeats, repeats, t.co)
    return t
end

-- 仅让出执行权 --
function Timer.sleep(second)
    if not second or second < 0 then
        return
    end
    local ti = Timer.get_timer()
    if not ti then
        LOG("INFO", "new timer class error! memory maybe not enough...")
        return
    end
    local current_co = co_self()
    local co = co_new(function ( ... )
        ti:stop()
        insert(TIMER_LIST, ti)
        co_wakeup(current_co)
    end)
    ti:start(second, second, co)
    return co_suspend()
end

return Timer