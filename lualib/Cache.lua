local log = require "log"
local Co = require "internal.Co"
local timer = require "internal.Timer"
local redis = require "protocol.redis"

local type = type
local error = error
local toint = math.tointeger
local tostring = tostring
local setmetatable = setmetatable

local co_self = Co.self
local co_wait = Co.wait
local co_wakeup = Co.wakeup

local os_time = os.time
local remove = table.remove

-- 是否已经初始化
local INITIALIZATION

-- 最大重试次数
local MAX_TIMES = 5

-- 最大DB连接数量
local MAX, COUNT = 50, 0

-- 最大空闲连接时间
local WAIT_TIMEOUT

-- Cache连接创建函数
local CACHE_CREATE

-- 等待db对象的协程列表
local wlist = {}

local function add_wait(co)
    wlist[#wlist+1] = co
end

local function pop_wait()
    return remove(wlist)
end

-- Cache连接池
local POOL = {}

local function add_cache(cache)
    if not WAIT_TIMEOUT then
        POOL[#POOL+1] = {session = cache}
        return
    end
    POOL[#POOL+1] = {session = cache, ttl = os_time()}
end

local function pop_cache()
    if #POOL > 0 then
        while 1 do
            local cache = remove(POOL)
            if not cache then break end
            if not cache.ttl or cache.ttl > os_time() - WAIT_TIMEOUT then
                return cache.session
            end
            cache.session:close()
            COUNT = COUNT - 1
        end
    end
    if COUNT < MAX then
        COUNT = COUNT + 1
        local cache = CACHE_CREATE()
        if cache then
            return cache
        end
        COUNT = COUNT - 1
    end
    add_wait(co_self())
    return co_wait()
end

local f

local Cache = setmetatable({}, {__name = "Cache", __index = function (t, k)
    if not INITIALIZATION then
        return nil, "Cache尚未初始化"
    end
    f = f or function (self, ...)
        local cache = pop_cache()
        local OK, v1, v2 = pcall(cache[k], cache, ...)
        if not OK then
            cache:close()
            return nil, v1
        end
        if #wlist > 0 then
            co_wakeup(pop_wait(), cache)
        else
            add_cache(cache)
        end
        return v1, v2
    end
    return f
end})


function Cache.init(opt)
    if INITIALIZATION then
        return nil, "Cache已经初始化."
    end
    if type(opt) ~= 'table' then
        return nil, '错误的Cache配置文件.'
    end
    if type(opt.max) == 'number' then
        MAX = opt.max
    end
    CACHE_CREATE = function (...)
        local times = 1
        local cache
        while 1 do
            cache = redis:new()
            local ok, connect, err = pcall(cache.connect, cache, opt)
            if ok and connect then
                break
            end
            if times > MAX_TIMES then
                cache:close()
                error('超过最大重试次数, 请检查网络连接后重启Redis与本服务')
            end
            log.error('第'..tostring(times)..'次连接失败:'..err.." 3 秒后尝试再次连接")
            cache:close()
            times = times + 1
            timer.sleep(3)
        end
        local ok, ret = cache:get_config('timeout')
        if ret[1] == 'timeout' and ret[2] ~= '0' then
            WAIT_TIMEOUT = toint(ret[2])
        end
        return cache
    end
    add_cache(pop_cache())
    INITIALIZATION = true
    return true
end

function Cache.count( ... )
    return #POOL
end

return Cache