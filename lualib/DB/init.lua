local mysql = require "protocol.mysql"
local timer = require "internal.Timer"
local co = require "internal.Co"
local class = require "class"
local log = require "logging"
local Log = log:new({ dump = true, path = 'DB'})

local co_self = co.self
local co_wait = co.wait
local co_wakeup = co.wakeup

local type = type
local tostring = tostring
local tonumber = tonumber
local assert = assert
local ipairs = ipairs

local rep = string.rep
local find = string.find
local fmt = string.format
local lower = string.lower
local upper = string.upper
local match = string.match

local insert = table.insert
local remove = table.remove
local concat = table.concat
local unpack = table.unpack

local SELECT = "SELECT"

local INSERT = "INSERT INTO"

local UPDATE = "UPDATE"

local DELETE = "DELETE"

local SET = "SET"

local FROM = "FROM"

local WHERE = "WHERE"

local IN = "IN"

local IS = "IS"

local NOT = "NOT"

local BETWEEN = "BETWEEN"

local AND = " AND "

local LIMIT = "LIMIT"

local DESC = "DESC"

local ASC = "ASC"

local ORDERBY = "ORDER BY"

local GROUPBY = "GROUP BY"

local COMMA = ", "

-- 空闲连接时间
local WAIT_TIMEOUT = 31536000

-- 数据库连接创建函数
local function DB_CREATE (opt)
    local times = 1
    local db
    while 1 do
        db = mysql:new()
        db:set_timeout(3)
        local connect, err = db:connect(opt)
        if connect then
          break
        end
        db:close()
        Log:ERROR('第'..tostring(times)..'次连接失败:'..err.." 3 秒后尝试再次连接")
        times = times + 1
        timer.sleep(3)
    end
    if not opt.INITIALIZATION then -- 设置连接超时时间
      db:query(fmt('SET GLOBAL wait_timeout=%s', WAIT_TIMEOUT))
      db:query(fmt('SET GLOBAL interactive_timeout=%s', WAIT_TIMEOUT))
    end
    return db
end

local function add_wait(self, co)
  insert(self.co_pool, 1, co)
end

local function pop_wait(self)
    return remove(self.co_pool)
end

local function add_db(self, db)
  insert(self.db_pool, 1, db)
end

-- 负责创建连接/加入等待队列
local function pop_db(self)
    if #self.db_pool > 0 then
      return remove(self.db_pool)
    end
    if self.current < self.max then
      self.current = self.current + 1
      return DB_CREATE(self)
    end
    add_wait(self, co_self())
    return co_wait()
end


-- 格式化处理函数
-- 将['field', '=', 'a'] 格式化为 field = a
-- 将['field', 'NOT', 'IN', '(1, 2, 3)'] 格式化为 field NOT IN (1, 2, 3)
local function format(t)
    local tab = {}
    for index=1, #t, 1 do
      tab[#tab+1] = "%s"
    end
    return fmt(concat(tab, ' '), unpack(t))
end

local function format_value1(t)
    return fmt("%s %s '%s'", unpack(t))
end

local function format_value2(t, split)
    local tmp = {}
    for i=1, #t do
        tmp[i] = "'%s'"
    end
    return fmt(concat(tmp, split), unpack(t))
end

local function format_value3(t)
    return fmt("%s %s '%s'", unpack(t))
end

local function format_value4(t)
    return fmt("%s %s %s '%s'", unpack(t))
end

local function limit(query, limit1, limit2)
    local t1 = type(limit1)
    local t2 = type(limit2)
    assert(query and type(query) == 'table' and (t1 == "number" or t1 == "string" ), "错误的限制条件(limit):"..tostring(limit1))

    insert(query, LIMIT)

    local limits = {tostring(limit1)}
    if t2 == "number" or tpy == "string" then
        insert(limits, tostring(limit2))
    end

    insert(query, concat(limits, COMMA))

    return query
end

-- 降序
local function desc(query)
    insert(query, DESC)
    return query
end
-- 升序
local function asc(query)
    insert(query, ASC)
    return query
end

-- 聚合字段
local function groupby(query, fields)
    local tpy = type(fields)
    assert(query and (tpy == "string" or tpy == "table"), "错误的聚合字段类型(fields):"..tostring(fields))
    insert(query, GROUPBY)
    if tpy == "string" then
        insert(query, fields)
    end
    if tpy == "table" then
        insert(query, concat(fields, COMMA))
    end
    return query
end

-- 排序字段
local function orderby(query, orders)
    local tpy = type(orders)
    assert(query and (tpy == "string" or tpy == "table"), "错误的排序条件(orders):"..tostring(orders))
    insert(query, ORDERBY)
    if tpy == "string" then
        insert(query, orders)
    end
    if tpy == "table" then
        insert(query, concat(orders, COMMA))
    end
    return query
end

-- 条件
local function where(query, conditions)
    local tpy = type(conditions)
    assert(query and (tpy == "string" or tpy == "table"), "错误的条件类型(where):"..tostring(conditions))
    insert(query, WHERE)
    if tpy == "string" then
        insert(query, conditions)
    end
    if tpy == "table" then
        local CONDITIONS = {}
        for index, condition in ipairs(conditions) do
            if type(condition) == "table" and #condition == 3 then
                local con2 = upper(condition[2])
                if con2 == IN or con2 == BETWEEN then -- 假设比较符是IN 或者 BETWEEN
                    local LEFT, RIGHT = '', ''
                    local c = AND
                    if con2 == IN then
                        c = COMMA
                        LEFT, RIGHT = '(', ')'
                    end
                    insert(CONDITIONS, format({condition[1], con2, LEFT..format_value2(condition[3], c)..RIGHT}))
                elseif con2 == IS then
                    insert(CONDITIONS, concat(condition, " "))
                elseif find(condition[3], condition[1]) or find(condition[3], '`') then
                    insert(CONDITIONS, concat(condition, " "))
                else
                    insert(CONDITIONS, format_value3(condition))
                end
            elseif type(condition) == "table" and #condition == 4 then
                local con2 = upper(condition[2])
                local con3 = upper(condition[3])
                if con3 == IN or con3 == BETWEEN then -- 假设比较符是IN 或者 BETWEEN
                    local LEFT, RIGHT = '', ''
                    local c = AND
                    if con3 == IN then
                        c = COMMA
                        LEFT, RIGHT = '(', ')'
                    end
                    insert(CONDITIONS, format({condition[1], con2, con3, LEFT..format_value2(condition[4], c)..RIGHT}))
                elseif con2 == IS then
                    insert(CONDITIONS, concat(condition, " "))
                else
                    insert(CONDITIONS, format_value4(condition))
                end
            else -- 假设condition为 "AND" 、 "OR"
                insert(CONDITIONS, upper(condition))
            end
        end
        insert(query, concat(CONDITIONS, " "))
    end
    query.WHERE = true
    return query
end

-- 表(s)
local function from(query, tables)
    local tpy = type(tables)
    assert(query and (tpy == "string" or tpy == "table"), "错误的表名:"..tostring(tables))
    insert(query, FROM)
    if tpy == "string" then
        insert(query, tables)
    end
    if tpy == "table" then
        insert(query, concat(tables, COMMA))
    end
    query.FROM = true
    return query
end

-- 插入语句专用函数 --
local function values(query, values)
    local tpy = type(values)
    assert(tpy == "table" and #values > 0 and type(values[1]) == "table" , "错误的值类型(values):"..tostring(values))
    local VALUES = {}
    for _, value in ipairs(values) do
        insert(VALUES, "("..format_value2(value, COMMA)..")")
    end
    insert(query, "VALUES")
    insert(query, concat(VALUES, COMMA))
    query.VALUES = true
    return query
end

local function fields(query, fields)
    local tpy = type(fields)
    assert(tpy == "table" and #fields > 0, "错误的字段类型(values):"..tostring(fields))
    insert(query, "("..concat(fields, COMMA)..")")
    query.FILEDS = true
    return query
end
-- 插入语句专用函数 --

-- 更新语句专用 --
local function set(query, values)
    local tpy = type(values)
    assert(tpy == "table" and #values > 0 and type(values[1]) == "table" , "错误的值类型(values):"..tostring(values))
    local VALUES = {}
    for _, value in ipairs(values) do
        insert(VALUES, format_value1(value))
    end
    insert(query, SET)
    insert(query, concat(VALUES, COMMA))
    return query
end
-- 更新语句专用 --

-- 执行
local function execute(query)
    -- Log:DEBUG(query)
    if query.SELECT then
        assert(query.FROM and query.WHERE, "查询语句必须使用from方法与where条件.")
    end
    if query.DELETE then
        assert(query.WHERE, "删除语句请加上where条件")
    end
    if query.INSERT then
        assert(query.FILEDS and query.VALUES, "插入语句请加上fields与values")
    end
    if query.UPDATE then
        assert(query.WHERE, "更新语句请加上where条件")
    end
    local QUERY = concat(query, " ")
    -- Log:DEBUG(QUERY)
    local self = query.self
    query.self = nil
    return self:query(QUERY)
end

local DB = class("DB")

function DB:ctor(opt)
  self.host = opt.host
  self.port = opt.port
  self.username = opt.username
  self.password = opt.password
  self.database = opt.database
  self.charset = opt.charset or 'utf8'
  self.max = opt.max or 50
  self.current = 0
  -- 协程池
  self.co_pool = {}
  -- 连接池
  self.db_pool = {}
end

function DB:connect ()
  if not self.INITIALIZATION then
    add_db(self, pop_db(self))
    self.INITIALIZATION = true
    return self.INITIALIZATION
  end
  return self.INITIALIZATION
end

-- 查询语句
function DB:select(fields)
    if not self.INITIALIZATION then
        return nil, "DB尚未初始化"
    end
    local tpy = type(fields)
    assert(tpy == "string" or tpy == "table", "错误的字段类型(fields):"..tostring(fields))
    local query = {
        self = self,
        [1] = SELECT,
        SELECT = true,
        from = from,
        where = where,
        orderby = orderby,
        groupby = groupby,
        desc = desc,
        asc = asc,
        limit = limit,
        execute = execute,
    }
    if tpy == "string" then
        insert(query, fields)
    end
    if tpy == "table" then
        insert(query, concat(fields, COMMA))
    end
    return query
end


-- 更新语句
function DB:update(table_name)
    if not self.INITIALIZATION then
        return nil, "DB尚未初始化"
    end
    local tpy = type(table_name)
    assert(tpy == "string" or tpy == "tables", "错误的表名(table_name):"..tostring(table_name))
    return {
        self = self,
        [1] = UPDATE,
        [2] = table_name,
        UPDATE = true,
        set = set,
        where = where,
        limit = limit,
        execute = execute,
    }
end


-- 插入语句
function DB:insert(table_name)
  if not self.INITIALIZATION then
      return nil, "DB尚未初始化"
  end
  local tpy = type(table_name)
  assert(tpy == "string", "错误的表名(table_name):"..tostring(table_name))
  return {
      self = self,
      [1] = INSERT,
      [2] = table_name,
      INSERT = true,
      fields = fields,
      values = values,
      execute = execute,
  }
end

-- 删除语句
function DB:delete(table_name)
    if not self.INITIALIZATION then
        return nil, "DB尚未初始化"
    end
    local tpy = type(table_name)
    assert(tpy == "string" or tpy == "tables", "错误的表名(table_name):"..tostring(table_name))
    return {
        self = self,
        [1] = DELETE,
        [2] = FROM,
        [3] = table_name,
        DELETE = true,
        where = where,
        limit = limit,
        orderby = orderby,
        execute = execute,
    }
end

-- 原始查询语句
function DB:query(query)
  if not self.INITIALIZATION then
      return nil, "DB尚未初始化"
  end
  assert(type(query) == 'string' and query ~= '' , "原始SQL类型错误(query):"..tostring(query))
  -- Log:DEBUG(query)
  local db, ret, err
  while 1 do
      db = pop_db(self)
      if db then
        ret, err = db:query(query)
        if db.state then
            break
        end
        -- Log:ERROR(err)
        db:close()
        self.current = self.current - 1
        db, ret, err = nil, nil, nil
      end
  end
  local co = pop_wait(self)
  if co then
    co_wakeup(co, db)
    return ret, err
  end
  add_db(self, db)
  return ret, err
end

function DB:count()
  return self.current, self.max, #self.co_pool, #self.db_pool
end

return DB
