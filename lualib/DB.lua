local mysql = require "protocol.mysql"
local co = require "internal.Co"
local log = require "log"

local co_self = co.self
local co_wait = co.wait
local co_wakeup = co.wakeup

local lower = string.lower
local spliter = string.gsub

local insert = table.insert
local remove = table.remove
local concat = table.concat

-- 最大DB连接数量
local MAX, COUNT

-- 主机名, 端口
local HOST, PORT

-- 用户名、密码
local USER, PASSWD

-- DB
local DATABASE

-- 数据库连接池
local POOL = {}

-- 等待db对象的协程列表
local wlist = {}

-- 数据库连接创建函数
local DB_CREATE

local SELECT = "SELECT "

local INSERT = "INSERT INTO "

local UPDATE = "UPDATE "

local FROM = " FROM "

local WHERE = " WHERE "

local AND = " AND "

local ASC = false

local DESC = true

local LIMIT = "LIMIT "

local ORDERBY = "ORDER BY "

local DB = {}

-- 负责创建连接/加入等待队列
local function get_db()
    if #POOL > 0 then
        return remove(POOL)
    end
    if COUNT < MAX then
        local db = DB_CREATE()
        if db then
            return db
        end
        -- 连接失败或者其他情况, 将等待其他协程唤醒; 保证公平竞争数据库连接
    end
    insert(wlist, co_self())
    return co_wait()
end

function DB.init(driver, user, passwd, max_pool)
    if not user then
        return log.error("空的数据库用户名")
    end

    USER = user

    if not passwd then
        return log.error("空的数据库密码")
    end

    PASSWD = passwd

    COUNT = 0

    MAX = max_pool or 100

    spliter(driver, '([^:]+)://([^:]+):(%d+)/(.+)', function (db, host, port, database)
        if not db or lower(db) ~= 'mysql' then
            return error("暂不支持其他数据库驱动")
        end
        if not host or not port then
            return error("请输入正确的主机名或端口")
        end
        HOST = host
        PORT = port
        DATABASE = database
    end)

    DB_CREATE = function(...)
        local db, err = mysql:new()
        if not db then
            return log.error(err)
        end
        local ok, err, errno, sqlstate = db:connect({
            host = HOST or "localhost",
            port = PORT or 3306,
            database = DATABASE,
            user = USER,
            password = PASSWD,
        })
        if not ok then
            return print(err)
        end
        COUNT = COUNT + 1
        return db
    end

    local db = DB_CREATE()
    if not db then
        return false
    end

    insert(POOL, db)

    return true
end

-- 查询语句
function DB.select(fields, table, conditions, orderby, sort, limit)
    local db = get_db()

    local CONDITIONS = {}

    for index, condition in ipairs(conditions) do
        insert(CONDITIONS, concat(condition, " "))
    end

    local query = {
        SELECT,
        concat(fields, ", "),
        FROM,
        table,
        WHERE,
        concat(CONDITIONS, " AND "),
    }

    if orderby then
        insert(query, ORDERBY .. concat(orderby, ", "))
        if sort then
            insert(query, tostring(sort) or "")
        end
    end

    if limit then
        insert(query, LIMIT .. concat(limit, ", "))
    end

    -- print(concat(query, " "))
    local response, err = db:query(concat(query, " "))

    if #wlist > 0 then
        co_wakeup(remove(wlist), db)
    else
        insert(POOL, db)
    end

    return response, err

end


return DB