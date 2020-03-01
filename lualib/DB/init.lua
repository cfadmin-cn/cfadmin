local class = require "class"
local mysql = require "protocol.mysql"
local timer = require "internal.Timer"

local log = require "logging"
local Log = log:new({ dump = true, path = 'DB'})

local crypt = require "crypt"
local hashkey = crypt.hashkey

local co = require "internal.Co"
local co_self = co.self
local co_wait = co.wait
local co_wakeup = co.wakeup

local type = type
local pairs = pairs
local ipairs = ipairs
local assert = assert
local select = select
local tostring = tostring
local tonumber = tonumber

local fmt = string.format

local insert = table.insert
local remove = table.remove
local concat = table.concat

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
      assert(db:query(fmt('SET wait_timeout=%s', WAIT_TIMEOUT)), "SET wait_timeout faild.")
      assert(db:query(fmt('SET interactive_timeout=%s', WAIT_TIMEOUT)), "SET interactive_timeout faild.")
      if opt.stmts then
        for rkey, stmt in pairs(opt.stmts) do
          assert(db:query(stmt), "["..stmt.."] 预编译失败.")
        end
      end
      db:set_timeout(0)
      break
    end
    Log:WARN('第'..tostring(times)..'次连接失败:'..err.." 3 秒后尝试再次连接")
    db:close()
    times = times + 1
    timer.sleep(3)
  end
  return db
end

local function add_wait(self, co)
  insert(self.co_pool, co)
end

local function pop_wait(self)
  return remove(self.co_pool)
end

local function add_db(self, db)
  insert(self.db_pool, db)
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

-- PREPARE
function DB:prepare (sql)
  if type(sql) ~= 'string' or sql == '' then
    return nil, "试图传递一个无效的SQL语句"
  end
  if not self.stmts then
    self.stmts = {}
  end
  local rkey = hashkey(sql, true)
  if self.stmts[rkey] then
    return rkey
  end
  local stmt = fmt([[PREPARE %s FROM "%s"]], rkey, sql)
  assert(self:query(stmt), "["..sql.."] 预编译失败.")
  self.stmts[rkey] = stmt
  return rkey
end

-- EXECUTE
function DB:execute (rkey, ...)
  if not self.stmts then
    return nil, "尚未有任何预编译语句"
  end
  local stmt = self.stmts[rkey]
  if not stmt then
    return nil, "找不到这个预编译语句."
  end
  local qua = select("#", ...)
  if qua <= 0 then
    return self:query([[ EXECUTE ]]..rkey)
  end
  local arg_keys = {}
  local arg_key = "@cf_args"
  local arg_values = {...}
  local req1 = {}
  for q = 1, qua do
    local key = arg_key..q
    local value = arg_values[q]
    if type(value) == 'string' then
      value = value:gsub("'", "\\'")
    end
    arg_keys[#arg_keys+1] = key
    req1[#req1+1] = concat({key, "=", "'", value, "'"})
  end
  return self:query(concat({"SET ", concat(req1, ", "), ";", " EXECUTE ", rkey, " USING ", concat(arg_keys, ", "), ";"}))
end

-- 原始查询语句
function DB:query(query)
  if not self.INITIALIZATION then
    return nil, "DB尚未初始化"
  end
  assert(type(query) == 'string' and query ~= '' , "原始SQL类型错误(query):"..tostring(query))
  local db, ret, err
  while 1 do
    db = pop_db(self)
    if db then
      ret, err = db:query(query)
      if db.state then
        break
      end
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

-- 字符串安全转义
function DB.quote_to_str( str )
  return mysql.quote_to_str(str)
end

function DB:count()
  return self.current, self.max, #self.co_pool, #self.db_pool
end

return DB
