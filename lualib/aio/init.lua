local laio = require "laio"

local new_tab = require "sys".new_tab

local cf = require "cf"
local co_new = coroutine.create
local co_self = cf.self
local co_wait = cf.wait
local co_wakeup = cf.wakeup

local type = type
local assert = assert
local toint = math.tointeger


local aio = new_tab(0, 1 << 16)

-- 创建指定文件
function aio.create(filename)
  filename = assert(type(filename) == 'string' and filename ~= '' and filename, "Invalide filename.")
  local t = {}
  t.current_co = co_self()
  t.event_co = co_new(function ( ok, err )
    aio[t] = nil  
    return co_wakeup(t.current_co, ok, err)
  end)
  aio[t] = true
  laio.create(event_co, filename)
  return co_wait()
end

-- 创建指定目录
function aio.mkdir(dir)
  dir = assert(type(dir) == 'string' and dir ~= '' and dir, "Invalid folder.")
  local t = {}
  t.current_co = co_self()
  t.event_co = co_new(function ( ok, err )
    aio[t] = nil  
    return co_wakeup(t.current_co, ok, err)
  end)
  aio[t] = true
  laio.mkdir(t.event_co, dir)
  return co_wait()
end

-- 删除指定目录
function aio.rmdir(dir)
  local t = {}
  t.current_co = co_self()
  t.event_co = co_new(function ( ok, err )
    aio[t] = nil  
    return co_wakeup(t.current_co, ok, err)
  end)
  aio[t] = true
  laio.rmdir(t.event_co, assert(type(dir) == 'string' and dir ~= '' and dir, "Invalid folder."))
  return co_wait()
end

-- 获取文件/目录状态
function aio.attributes(path)
  return aio.stat(path)
end

-- 获取文件/目录状态
function aio.stat(path)
  local t = {}
  t.current_co = co_self()
  t.event_co = co_new(function ( list )
    aio[t] = nil  
    return co_wakeup(t.current_co, list)
  end)
  aio[t] = true
  laio.stat(t.event_co, assert(type(path) == 'string' and path ~= '' and path, "Invalid path."))
  return co_wait()
end

-- 获取目录下所有文件
function aio.dir(path)
  path = assert(type(path) == 'string' and path ~= '' and path, "Invalid path.")
  local t = {}
  t.current_co = co_self()
  t.event_co = co_new(function ( dirs )
    aio[t] = nil  
    return co_wakeup(t.current_co, dirs )
  end)
  aio[t] = true
  laio.readdir(t.event_co, path)
  return co_wait()
end

-- 创建指定文件
function aio.rename(old_name, new_name)
  old_name = assert(type(old_name) == 'string' and old_name ~= '' and old_name, "Invalid old_name.")
  new_name = assert(type(new_name) == 'string' and new_name ~= '' and new_name, "Invalid new_name.")
  local t = {}
  t.current_co = co_self()
  t.event_co = co_new(function ( ok )
    aio[t] = nil  
    return co_wakeup(t.current_co, ok)
  end)
  aio[t] = true
  laio.rename(t.event_co, old_name, new_name)
  return co_wait()
end

-- 获取当前目录完整路径
function aio.currentdir(...)
  return aio.readpath()
end

-- 获取指定目录完整路径
function aio.readpath(path)
  local t = {}
  t.current_co = co_self()
  t.event_co = co_new(function ( path )
    aio[t] = nil  
    return co_wakeup(t.current_co, path )
  end)
  aio[t] = true
  if type(path) ~= 'string' or path == '' then
    path = "."
  end
  laio.readpath(t.event_co, path)
  return co_wait()
end

-- 清空文件或者缩减文件大小. 当length为0或者nil的时候将会清空文件.
-- 注意: 这个操作是非常危险的, 您需要非常清楚自己的做什么.
function aio.truncate(filename, length)
  filename = assert(type(filename) == 'string' and filename ~= '' and filename, "Invalid filename.")
  local t = {}
  t.current_co = co_self()
  t.event_co = co_new(function ( ok, err )
    aio[t] = nil  
    return co_wakeup(t.current_co, ok, err)
  end)
  aio[t] = true
  laio.truncate(t.event_co, filename, (toint(length) and toint(length) > 0) and toint(length) or 0)
  return co_wait()
end

return aio