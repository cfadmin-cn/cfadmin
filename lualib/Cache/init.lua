local log = require "logging"
local Co = require "internal.Co"
local timer = require "internal.Timer"
local redis = require "protocol.redis"

local co_self = Co.self
local co_wait = Co.wait
local co_wakeup = Co.wakeup

local type = type
local ipairs = ipairs
local setmetatable = setmetatable

local table = table
local unpack = table.unpack
local remove = table.remove
local upper = string.upper
local lower = string.lower
local splite = string.gmatch

local Log = log:new()


-- 默认情况下, 保持50个redis连接
local MAX, COUNT = 50, 0

-- 连接池
local POOL = {}

-- 是否已经初始化
local INITIALIZATION = false

-- session创建函数
local CREATE_CACHE

-- 注册命令
local commands = {
    'sismember', 'exists'
}

local function in_command(cmd)
    for _, command in ipairs(commands) do
        if lower(cmd) == command then
            return true
        end
    end
    return false
end

local wlist = {}

local function add_wait(co)
    wlist[#wlist+1] = co
end

local function pop_wait()
    return remove(wlist)
end

local function add_cache(session)
    POOL[#POOL+1] = session
end

local function pop_cache()
    if #POOL > 0 then
        return remove(POOL)
    end
    if COUNT < MAX then
        COUNT = COUNT + 1
        return CREATE_CACHE()
    end
    add_wait(co_self())
    return co_wait()
end


local Cache = setmetatable({}, {__index = function (_, key)
    if not INITIALIZATION then
        return nil, 'Cache尚未初始化'
    end
    if lower(key) == "publish" or lower(key) == "subscribe" or lower(key) == "psubscribe" then
        return nil, 'Cache error: Cache不支持在缓存中直接使用此命令.'
    end
    local cache = pop_cache()
    if in_command(key) then
        return function (_, ...)
            local ok, ret
            while 1 do
                ok, ret = cache[key](cache, ...)
                if ret ~= 'server close!!' then
                    break
                end
                cache:close()
                cache = CREATE_CACHE()
            end
            if #wlist > 0 then
                co_wakeup(pop_wait(), cache)
            else
                add_cache(cache)
            end
            return ok, ret
        end
    end
    return function (_, ...)
        local ok, ret
        local keys = {}
        for k in splite(key, "([^_]+)") do
            keys[#keys+1] = k
        end
        while 1 do
            if #keys > 1 then
                ok, ret = cache:cmd(upper(keys[1]), upper(keys[2]), ...)
            else
                ok, ret = cache:cmd(upper(keys[1]), ...)
            end
            if ret ~= 'server close!!' then
                break
            end
            cache:close()
            cache = CREATE_CACHE()
        end
        if #wlist > 0 then
            co_wakeup(pop_wait(), cache)
        else
            add_cache(cache)
        end
        return ok, ret
    end
end})

-- 初始化
function Cache.init(opt)
    if INITIALIZATION then
        return nil, "Cache已经初始化."
    end

    assert(type(opt) == 'table', "Cache error: 错误的Cache配置文件.")

    assert(type(opt.host) == 'string' and opt.host ~= '', "Cache error: 异常的主机名.")

    assert(type(opt.port) == 'number' and opt.port > 0 and opt.port <= 65535, "Cache error: 异常的端口.")

    assert(not opt.auth or type(opt.auth) == 'string' , "Cache error: 异常的auth.")

    assert(not opt.db or type(opt.db) == 'number' and opt.db >= 0 and opt.db <= 15, "Cache error: 异常的db.")

    if type(opt.max) == 'number' and opt.max > 0 then
        MAX = opt.max
    end

    CREATE_CACHE = function ()
        local times = 1
        local rds
        while 1 do
            rds = redis:new(opt)
            local ok, err = rds:connect()
            if ok then
                break
            end
            Log:ERROR('第'..tostring(times)..'次连接失败:'..err.." 3 秒后尝试再次连接")
            times = times + 1
            rds:close()
            timer.sleep(3)
        end
        local ok, ret = rds:cmd("CONFIG", "GET", "TIMEOUT")
        if not INITIALIZATION and ret[2] ~= '0' then
            rds:cmd("CONFIG SET", "TIMEOUT", "0")
        end
        return rds
    end
    add_cache(CREATE_CACHE())
    INITIALIZATION = true
    COUNT = COUNT + 1
    return true
end

-- 连接池数量
function Cache.count()
    return #POOL
end

return Cache
