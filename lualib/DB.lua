local mysql = require "protocol.mysql"
local co = require "internal.Co"
local log = require "log"

local co_self = co.self
local co_wait = co.wait
local co_wakeup = co.wakeup

local type = type
local pairs = pairs
local ipairs = ipairs

local rep = string.rep
local fmt = string.format
local lower = string.lower
local upper = string.upper
local spliter = string.gsub

local insert = table.insert
local remove = table.remove
local concat = table.concat
local unpack = table.unpack

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

local SELECT = "SELECT"

local INSERT = "INSERT INTO"

local UPDATE = "UPDATE"

local SET = "SET"

local FROM = "FROM"

local WHERE = "WHERE"

local IN = "IN"

local NOT = "NOT"

local BETWEEN = "BETWEEN"

local AND = " AND "

local LIMIT = "LIMIT"

local ORDERBY = "ORDER BY"

local COMMA = ", "

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
function DB.select(fields, tablename, conditions, orderby, sort, limit)

    if not tablename or tablename == "" or type(tablename) ~= "string" then
        return log.error('请输入正确的表名: ', tablename)
    end

    local CONDITIONS = {}

    for index, condition in ipairs(conditions) do
        local con = condition[2]
        if upper(con) == IN or upper(con) == BETWEEN then -- 若条件是IN或BETWEEN, 变量则应该是数组 [1,2,3,4]
            local LEFT, RIGHT = '', ''
            local c = AND
            if upper(con) == IN then
                c = COMMA
                LEFT, RIGHT = '(', ')'
            end
            for i = 1, #condition[3] do
                condition[3][i] = '"'..condition[3][i]..'"'
            end
            insert(CONDITIONS, concat({condition[1], upper(con), LEFT..concat(condition[3], c)..RIGHT}, " "))
        elseif upper(con) == NOT then  -- 如果条件为NOT应该有第四个参数, 变量则应该是数组 [1,2,3,4]
            if upper(condition[3]) == IN or upper(condition[3]) == BETWEEN then
                local LEFT, RIGHT = '', ''
                local c = AND
                if upper(condition[3]) == IN then
                    c = COMMA
                    LEFT, RIGHT = '(', ')'
                end
                for i = 1, #condition[4] do
                    condition[4][i] = '"'..condition[4][i]..'"'
                end
                insert(CONDITIONS, concat({condition[1], upper(condition[2]), upper(condition[3]), LEFT..concat(condition[4], c)..RIGHT}, " "))
            else
                insert(CONDITIONS, fmt("%s %s '%s'", unpack(condition)))
            end
        else
            insert(CONDITIONS, fmt("%s %s '%s'", unpack(condition)))
        end
    end

    local query = {
        SELECT,
        concat(fields, COMMA),
        FROM,
        tablename,
        WHERE,
        concat(CONDITIONS, AND),
    }

    if orderby then
        insert(query, ORDERBY ..' '.. concat(orderby, COMMA))
        if sort and tostring(sort) then
            insert(query, sort)
        end
    end

    if limit then
        insert(query, LIMIT ..' '.. concat(limit, COMMA))
    end

    local db = get_db()

    -- print(concat(query, " "))
    local response, err = db:query(concat(query, " "))

    if #wlist > 0 then
        co_wakeup(remove(wlist), db)
    else
        insert(POOL, db)
    end

    return response, err

end

-- 插入语句
function DB.insert(tablename, keys, values)

    if not tablename or tablename == "" or type(tablename) ~= "string" then
        return log.error('请输入正确的表名: ', tablename)
    end

    local KEYS = {}

    for _, key in ipairs(keys) do
        insert(KEYS, fmt('`%s`', tostring(key)))
    end

    local VALUES = {}

    for index, value in ipairs(values) do
        local t1 = {}
        local t2 = {}
        for i = 1, #value do
            insert(t1, '"%s"')
            insert(t2, tostring(value[i]))
        end
        insert(VALUES, "("..fmt(concat(t1, ", "), unpack(t2))..")")
    end

    local query = concat({
        INSERT,
        tablename..'('..concat(KEYS, COMMA)..')',
        "VALUES"..concat(VALUES, COMMA)
    }, " ")

    local db = get_db()

    -- print(query)
    local response, err = db:query(query)

    if #wlist > 0 then
        co_wakeup(remove(wlist), db)
    else
        insert(POOL, db)
    end

    return response, err

end

-- 更新语句
function DB.update(tablename, values, conditions, limit)

    if not tablename or tablename == "" or type(tablename) ~= "string" then
        return log.error('请输入正确的表名: ', tablename)
    end

    local query = {
        UPDATE,
        '`'..tablename..'`',
        SET,
    }

    local VALUES = {}

    for index, value in ipairs(values) do
        insert(VALUES, fmt("%s %s '%s'", unpack(value)))
    end

    insert(query, concat(VALUES, COMMA))

    insert(query, WHERE)

    local CONDITIONS = {}

    for index, condition in ipairs(conditions) do
        local con = condition[2]
        if upper(con) == IN or upper(con) == BETWEEN then -- 若条件是IN或BETWEEN, 变量则应该是数组 [1,2,3,4]
            local LEFT, RIGHT = '', ''
            local c = AND
            if upper(con) == IN then
                c = COMMA
                LEFT, RIGHT = '(', ')'
            end
            for i = 1, #condition[3] do
                condition[3][i] = '"'..condition[3][i]..'"'
            end
            insert(CONDITIONS, concat({condition[1], upper(con), LEFT..concat(condition[3], c)..RIGHT}, " "))
        elseif upper(con) == NOT then  -- 如果条件为NOT应该有第四个参数, 变量则应该是数组 [1,2,3,4]
            if upper(condition[3]) == IN or upper(condition[3]) == BETWEEN then
                local LEFT, RIGHT = '', ''
                local c = AND
                if upper(condition[3]) == IN then
                    c = COMMA
                    LEFT, RIGHT = '(', ')'
                end
                for i = 1, #condition[4] do
                    condition[4][i] = '"'..condition[4][i]..'"'
                end
                insert(CONDITIONS, concat({condition[1], upper(condition[2]), upper(condition[3]), LEFT..concat(condition[4], c)..RIGHT}, " "))
            else
                insert(CONDITIONS, fmt("%s %s '%s'", unpack(condition)))
            end
        else
            insert(CONDITIONS, fmt("%s %s '%s'", unpack(condition)))
        end
    end
    insert(query, concat(CONDITIONS, AND))

    if limit then
        insert(query, concat(limit, COMMA))
    end

    local db = get_db()

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