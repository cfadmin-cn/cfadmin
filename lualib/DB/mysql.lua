local class = require "class"

local timer = require "internal.Timer"
local mysql = require "protocol.mysql"

local log = require "logging"
local Log = log:new({ dump = true, path = 'DB'})

local co = require "internal.Co"
local co_self = co.self
local co_wait = co.wait
local co_wakeup = co.wakeup

local type = type
local error = error
local xpcall = xpcall
local assert = assert

local fmt = string.format

local insert = table.insert
local remove = table.remove

-- 空闲连接时间
local WAIT_TIMEOUT = 31536000
local INTERACTIVE_TIMEOUT = 31536000

-- 数据库连接创建函数
local function DB_CREATE (opt)
  local db
  while 1 do
    db = mysql:new(opt)
    db:set_timeout(3)
    local connect, err = db:connect()
    if connect then
      assert(db:query(fmt('SET wait_timeout=%u', WAIT_TIMEOUT)))
      assert(db:query(fmt('SET interactive_timeout=%u', INTERACTIVE_TIMEOUT)))
      db:set_timeout(0)
      break
    end
    Log:WARN("The connection failed. The reasons are: [" .. err .. "], Try to reconnect after 3 seconds")
    timer.sleep(3)
    db:close()
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
  local session = remove(self.db_pool)
  if session then
    return session
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
  else
    add_db(self, db)
  end
  return ret, err
end

local function run_execute(self, query, ...)
  local db, ret, err
  while 1 do
    db = pop_db(self)
    if db then
      ret, err = db:execute(query, ...)
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
  else
    add_db(self, db)
  end
  return ret, err
end

-- 事务session
local session = class("session")

function session:ctor(opt)
  self.db   = opt.db
  self.over = false
end

function session:execute(sql, ...)
  if self.over then
    return nil, "Please use `return session:rollback()` or `return session:commit()` after the transaction process is over or Process error."
  end
  -- assert(self.db.state, "MySQL transaction session closed. 1")
  local ret, err = self.db:execute(sql, ...)
  assert(self.db.state, "MySQL transaction session closed. 1")
  return ret, err
end

function session:query(sql)
  if self.over then
    return nil, "Please use `return session:rollback()` or `return session:commit()` after the transaction process is over or Process error."
  end
  -- assert(self.db.state, "MySQL transaction session closed. 1")
  local ret, err = self.db:query(sql)
  assert(self.db.state, "MySQL transaction session closed. 2")
  return ret, err
end

function session:rollback()
  if self.over then
    return
  end
  assert(self.db.state, "MySQL transaction session closed. 3")
  self.db:query("rollback; set autocommit=1;")
  assert(self.db.state, "MySQL transaction session closed. 4")
  self.over = true
  self.db = nil
  return { state = "rollback" }
end

function session:commit()
  if self.over then
    return
  end
  assert(self.db.state, "MySQL transaction session closed. 5")
  self.db:query("set autocommit=1;")
  assert(self.db.state, "MySQL transaction session closed. 6")
  self.over = true
  self.db = nil
  return { state = "successed" }
end

local DB = class("DB")

function DB:ctor(opt)
  self.host = opt.host
  self.port = opt.port
  self.unixdomain = opt.unixdomain
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

local function traceback(msg)
  return fmt("[%s] %s", os.date("%Y/%m/%d %H:%M:%S"), debug.traceback(co_self(), msg, 3))
end

function DB:transaction(f)
  assert(self.INITIALIZATION, "DB needs to be initialized first.")
  assert(type(f) == 'function', "A function must be passed to describe the execution of the transaction.")
  local db, ret, err
  while 1 do
    db = pop_db(self)
    if db then
      ret, err = db:query("set autocommit=0;")
      if db.state then
        break
      end
      db:close()
      self.current = self.current - 1
    end
    -- db, ret, err = nil, nil, nil
  end

  local ok, info = xpcall(f, traceback, session:new{ db = db })
  if not ok then
    -- 如果在自定义事务流程的内部发生了错误
    if not db.state then
      self.current = self.current - 1
      db:close()
      local co = pop_wait(self)
      if co then
        co_wakeup(co, pop_db(self))
      end
      return nil, info
    end
    db:query("rollback; set autocommit=1;")
    local co = pop_wait(self)
    if co then
      co_wakeup(co, db)
    else
      add_db(self, db)
    end
    return nil, info
  end
  -- 如果定义的事务没有以`commit`或者`rollback`结尾.
  if type(info) ~= 'table' or (info.state ~= "successed" and info.state ~= 'rollback') then
    db:query("rollback; set autocommit=1;")
    local co = pop_wait(self)
    if co then
      co_wakeup(co, db)
    else
      add_db(self, db)
    end
    error("After the transaction ends, either 'return session:commit()' or 'return session:rollback()' must be required.")
  end
  local co = pop_wait(self)
  if co then
    co_wakeup(co, db)
  else
    add_db(self, db)
  end
  return info.state == "successed" and true or false
end

-- 查询接口
function DB:query(query)
  assert(self.INITIALIZATION, "DB needs to be initialized first.")
  return run_query(self, assert(type(query) == 'string' and query ~= '' and query , "Invalid MySQL query syntax."))
end

-- 预处理接口
function DB:execute(query, ...)
  assert(self.INITIALIZATION, "DB needs to be initialized first.")
  return run_execute(self, assert(type(query) == 'string' and query ~= '' and query , "Invalid MySQL prepare syntax."), ...)
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
