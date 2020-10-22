local class = require "class"

local timer = require "internal.Timer"
local mssql = require "protocol.mssql"

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
  local db
  while 1 do
    db = mssql:new(opt)
    db:set_timeout(3)
    local connect, err = db:connect()
    if connect then
      -- assert(db:query(fmt('SET wait_timeout=%u', WAIT_TIMEOUT)))
      -- assert(db:query(fmt('SET interactive_timeout=%u', INTERACTIVE_TIMEOUT)))
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

local DB = class("DB")

function DB:ctor(opt)
  self.host = opt.host
  self.port = opt.port
  self.username = opt.username
  self.password = opt.password
  self.database = opt.database
  self.TSQL = opt.TSQL
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

-- 原始查询语句
function DB:query(query)
  assert(self.INITIALIZATION, "DB needs to be initialized first.")
  return run_query(self, assert(type(query) == 'string' and query ~= '' and query , "Invalid MSSQL syntax."))
end

-- 字符串安全转义
function DB.quote_to_str( str )
  return mssql.quote_to_str(str)
end

function DB:count()
  assert(self.INITIALIZATION, "DB needs to be initialized first.")
  return self.current, self.max, #self.co_pool, #self.db_pool
end

return DB
