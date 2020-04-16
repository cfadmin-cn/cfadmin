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
local ipairs = ipairs
local assert = assert
local tostring = tostring
local tonumber = tonumber

local fmt = string.format

local insert = table.insert
local remove = table.remove
local concat = table.concat

-- 空闲连接时间
local WAIT_TIMEOUT = 31536000
local INTERACTIVE_TIMEOUT = 31536000

-- 数据库连接创建函数
local function DB_CREATE (opt)
  local times = 1
  local db
  while 1 do
    db = mysql:new()
    db:set_timeout(3)
    local connect, err = db:connect(opt)
    if connect then
      assert(db:query(fmt('SET wait_timeout=%u', WAIT_TIMEOUT)))
      assert(db:query(fmt('SET interactive_timeout=%u', INTERACTIVE_TIMEOUT)))
      if opt.stmts then
        local stmts = opt.stmts
        for _, rkey in ipairs(stmts) do
          assert(db:prepare(stmts[rkey].sql))
        end
      end
      db:set_timeout(0)
      break
    end
    Log:WARN("The connection failed. The reasons are: [" .. err .. "], Try to reconnect after 3 seconds")
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

local function run_query(self, query)
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

local function run_prepare(self, query)
  local db, ret, err
  while 1 do
    db = pop_db(self)
    if db then
      ret, err = db:prepare(query)
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

local function run_execute(self, stmt, ...)
  local db, ret, err
  while 1 do
    db = pop_db(self)
    if db then
      ret, err = db:execute(stmt, ...)
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

function DB:prepare(sql)
  assert(self.INITIALIZATION, "DB needs to be initialized first.")
  local stmts = self.stmts
  if not self.stmts then
    stmts = {}
    self.stmts = stmts
  end
  local rkey = hashkey(sql, true)
  if stmts[rkey] then
    return rkey
  end
  local stmt = assert(run_prepare(self, sql))
  stmts[#stmts + 1] = rkey
  stmts[rkey] = { stmt = stmt, sql = sql }
  return rkey
end

-- 初始化所有预处理语句
function DB:prepares(opt)
  assert(self.INITIALIZATION, "DB needs to be initialized first.")
  if type(opt) ~= 'table' or #opt < 1 then
    return
  end
  local stmts = self.stmts
  if not self.stmts then
    stmts = {}
    self.stmts = stmts
  end
  local list = {}
  for _, sql in ipairs(opt) do
    local rkey = hashkey(sql, true)
    if not stmts[rkey] then
      local stmt = assert(run_prepare(self, sql))
      list[#list + 1] = rkey
      stmts[#stmts + 1] = rkey
      stmts[rkey] = {stmt = stmt, sql = sql}
    end
  end
  return list
end

-- 执行预处理语句
function DB:execute(rkey, ...)
  assert(self.INITIALIZATION, "DB needs to be initialized first.")
  local stmts = self.stmts
  if type(stmts) ~= 'table' or #stmts < 1 then
    return nil, "DB has not any stmts."
  end
  local stmt = stmts[rkey]
  if not stmt then
    return nil, "DB Can't find this stmt."
  end
  return run_execute(self, stmt.stmt, ...)
end

-- 原始查询语句
function DB:query(query)
  assert(self.INITIALIZATION, "DB needs to be initialized first.")
  return run_query(self, assert(type(query) == 'string' and query ~= '' and query , "Invalid MySQL syntax."))
end

-- 字符串安全转义
function DB.quote_to_str( str )
  return mysql.quote_to_str(str)
end

function DB:count()
  assert(self.INITIALIZATION, "DB needs to be initialized first.")
  return self.current, self.max, #self.co_pool, #self.db_pool
end

return DB
