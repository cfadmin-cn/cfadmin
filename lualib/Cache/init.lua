local class = require "class"
local log = require "logging"
local Co = require "internal.Co"
local timer = require "internal.Timer"
local redis = require "protocol.redis"

local co_self = Co.self
local co_wait = Co.wait
local co_wakeup = Co.wakeup

local ipairs = ipairs
local setmetatable = setmetatable

local table = table
local insert = table.insert
local remove = table.remove
local upper = string.upper
local lower = string.lower
local splite = string.gmatch

local Log = log:new({ dump = true, path = 'Cache'})

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

local keys = {}

-- 注入函数
local function in_keys(key)
  return keys[key]
end

-- 创建Cache函数
local function CREATE_CACHE(opt)
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
  if not opt.INITIALIZATION then
    local ok, ret = rds:cmd("CONFIG", "GET", "TIMEOUT")
    if ret[2] ~= '0' then
      rds:cmd("CONFIG SET", "TIMEOUT", "0")
    end
  end
  return rds
end

-- 加入到连接池内
local function add_cache(self, cache)
  insert(self.cache_pool, 1, cache)
end

-- 从连接池内取出一个cache对象
local function pop_cache(self)
  if #self.cache_pool > 0 then
      return remove(self.cache_pool)
  end
  if self.current < self.max then
      self.current = self.current + 1
      return CREATE_CACHE(self)
  end
  add_wait(self, co_self())
  return co_wait()
end

-- 加入到协程池内
local function add_wait(self, co)
  insert(self.co_pool, 1, co)
end

-- 弹出一个等待协程
local function pop_wait(self)
  return remove(self.co_pool)
end

-- 构建Cache对象
local function setmeta(self)
  keys['count'] = self.count
  return setmetatable(self, {
    __index = function(t, key)
      local f = in_keys(key)
      if f then
        return f
      end
      if lower(key) == "publish" or lower(key) == "subscribe" or lower(key) == "psubscribe" then
          return nil, 'Cache error: Cache不支持在缓存中直接使用此命令.'
      end
      if in_command(key) then
          return function (_, ...)
              local ok, ret
              local session
              while 1 do
                  session = pop_cache(t)
                  ok, ret = session[key](session, ...)
                  if ret ~= 'server close!!' then
                      break
                  end
                  session:close()
                  session = nil
              end
              local co = pop_wait(t)
              if co then
                co_wakeup(co, session)
                return ok, ret
              end
              add_cache(t, session)
              return ok, ret
          end
      end
      return function (_, ...)
        local ok, ret
        local keys = {}
        for k in splite(key, "([^_]+)") do
            keys[#keys+1] = k
        end
        local session
        while 1 do
            session = pop_cache(t)
            if #keys > 1 then
                ok, ret = session:cmd(upper(keys[1]), upper(keys[2]), ...)
            else
                ok, ret = session:cmd(upper(keys[1]), ...)
            end
            if ret ~= 'server close!!' then
                break
            end
            session:close()
            session = nil
        end
        local co = pop_wait(t)
        if co then
          co_wakeup(co, session)
          return ok, ret
        end
        add_cache(t, session)
        return ok, ret
    end
  end}) == self
end

local Cache = class("Cache")

function Cache:ctor (opt)
  self.host = opt.host
  self.port = opt.port
  self.db = opt.db
  self.auth = opt.auth
  self.max = opt.max or 50
  self.current = 0
  -- 连接池
  self.cache_pool = {}
  -- 协程池
  self.co_pool = {}
end

function Cache:connect ()
  if not self.INITIALIZATION then
    add_cache(self, pop_cache(self))
    self.INITIALIZATION = true
    return setmeta(self)
  end
  return true
end

function Cache:count()
  return self.current, self.max
end

return Cache
