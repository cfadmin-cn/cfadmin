local class = require "class"

local cf = require "cf"
local co_new = coroutine.create
local co_self = cf.self
local co_wait = cf.wait
local co_wakeup = cf.wakeup

local laio = require "laio"
local aio_open = laio.open
local aio_stat = laio.stat
local aio_flush = laio.flush
local aio_read = laio.read
local aio_write = laio.write
local aio_close = laio.close
local aio_rmdir = laio.rmdir
local aio_mkdir = laio.mkdir
local aio_rename = laio.rename
local aio_readdir = laio.readdir
local aio_readpath = laio.readpath
local aio_truncate = laio.truncate

local new_tab = require "sys".new_tab

local type = type
local assert = assert
local toint = math.tointeger


local aio = new_tab(0, 1 << 16)

local File = class("__AIO__")

function File:ctor(opt)
  self.fd = opt.fd
  self.path = opt.path
  self.stat = opt.stat
  self.status = "open"
end

-- 触发gc时检查是否回收self.fd
function File:__gc()
  if self.fd and self.status == "open" then
    return self:close()
  end
  return true
end

-- 读取文件指定大小内容
function File:read( bytes )
  if self.status == "closed" then
    return nil, "File already Closed."
  end
  bytes = toint(bytes)
  if not bytes or bytes <= 0 then
    return nil, "Invalid file read bytes."
  end
  assert(not self.__READ__, "File:read方法不可以在多个协程中并发调用.")
  if not self.read_offset then
    self.read_offset = 0
  end
  self.__READ__ = { current_co = co_self() }
  self.__READ__.event_co = co_new(function ( data, size )
    local current_co = self.__READ__.current_co
    if type(data) == 'string' then
      self.read_offset = self.read_offset + size
    end
    self.__READ__ = nil
    return co_wakeup(current_co, data, size)
  end)
  aio_read(self.__READ__.event_co, self.fd, bytes, self.read_offset)
  return co_wait()
end

-- 读取文件所有内容
function File:readall()
  if self.status == "closed" then
    return nil, "File already Closed."
  end
  local bytes = toint(self.stat.size)
  if not bytes or bytes < 1 then
    return ""
  end
  assert(not self.__READ__, "File:readall方法不可以在多个协程中并发调用.")
  if not self.read_offset then
    self.read_offset = 0 -- 如果没有读取过, 则一次性全部读取完毕.
  else
    -- 如果调用这个之前有调用过read, 那么将使用read_offset将之后的字节全部读取出来
    -- 如果已经读到末尾, 则直接返回空字符串并且调整read_offset确保一致性.
    bytes = bytes > self.read_offset and bytes - self.read_offset or 0
    if bytes == 0 then
      self.read_offset = self.stat.size
      return ""
    end
  end
  self.__READ__ = { current_co = co_self() }
  self.__READ__.event_co = co_new(function ( data, size )
    local current_co = self.__READ__.current_co
    if type(data) == 'string' then
      self.read_offset = self.read_offset + size
    end
    self.__READ__ = nil
    return co_wakeup(current_co, data, size)
  end)
  aio_read(self.__READ__.event_co, self.fd, bytes, self.read_offset)
  return co_wait()
end

-- 写入文件
function File:write( data )
  if self.status == "closed" then
    return nil, "File already Closed."
  end
  assert(not self.__WRITE__, "File:write方法不可以在多个协程中并发调用.")
  if type(data) ~= 'string' or data == "" then
    return nil, "Invalid file write data."
  end
  self.__WRITE__ = { current_co = co_self() }
  self.__WRITE__.event_co = co_new(function ( data, err )
    local current_co = self.__WRITE__.current_co
    self.__WRITE__ = nil
    return co_wakeup(current_co, data, err)
  end)
  aio_write(self.__WRITE__.event_co, self.fd, data, self.stat.size)
  self.stat.size =  self.stat.size + #data
  return co_wait()
end

-- 刷新缓存
function File:flush()
  if self.status == "closed" then
    return nil, "File already Closed."
  end
  assert(not self.__FLUSH__, "File:flush方法不可以在多个协程中并发调用.")
  self.__FLUSH__ = { current_co = co_self() }
  self.__FLUSH__.event_co = co_new(function ( ok, err )
    local current_co = self.__FLUSH__.current_co
    self.__FLUSH__ = nil
    return co_wakeup(current_co, ok, err)
  end)
  aio_flush(self.__FLUSH__.event_co, self.fd)
  return co_wait()
end

-- 清空文件
function File:clean()
  if self.status == "closed" then
    return nil, "File already Closed."
  end
  self.__CLEAN__ = assert(not self.__CLEAN__, "File:clean方法不可以在多个协程中并发调用.")
  local ok, err = aio.truncate(self.path, 0)
  if not ok then
    self.__CLEAN__ = nil
    return nil, err
  end
  local stat, err = aio.stat(self.path)
  if type(stat) ~= 'table' then
    self.__CLEAN__ = nil
    return nil, err
  end
  if toint(self.read_offset) then
    self.read_offset = 0
  end
  self.stat = stat
  self.__CLEAN__ = nil
  return true
end

-- 关闭文件描述符
function File:close( ... )
  if self.status == "closed" then
    return nil, "File already Closed."
  end
  local fd = self.fd
  self.fd = nil
  self.status = "closed"
  return aio._close(fd)
end

-- 打开文件(始终以rw模式打开, 没有则会创建)
function aio.open(filename)
  local fd, err = aio._open(filename)
  if not fd then
    return nil, err
  end
  local stat, err = aio.stat(filename)
  if not stat then
    local t = {}
    t.current_co = co_self()
    t.event_co = co_new(function ( ok, err )
      aio[t] = nil  
      return co_wakeup(t.current_co, ok, err)
    end)
    aio[t] = true
    aio_close(t.event_co, fd)
    return co_wait()
  end
  return File:new { fd = fd, path = filename, stat = stat }
end

-- 仅返回fd
function aio._open(filename)
  filename = assert(type(filename) == 'string' and filename ~= '' and filename ~= '.' and filename ~= '..' and filename, "Invalid filename.")
  local t = {}
  t.current_co = co_self()
  t.event_co = co_new(function ( fd, err)
    aio[t] = nil
    return co_wakeup(t.current_co, fd, err)
  end)
  aio[t] = true
  aio_open(t.event_co, filename)
  return co_wait()
end

-- 仅关闭fd
function aio._close(fd)
  fd = assert(toint(fd) and toint(fd) >= 0 and toint(fd), "Invalid fd.")
  local t = {}
  t.current_co = co_self()
  t.event_co = co_new(function ( ok, err )
    aio[t] = nil
    return co_wakeup(t.current_co, ok, err)
  end)
  aio[t] = true
  aio_close(t.event_co, fd)
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
  aio_mkdir(t.event_co, dir)
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
  aio_rmdir(t.event_co, assert(type(dir) == 'string' and dir ~= '' and dir, "Invalid folder."))
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
  t.event_co = co_new(function ( list, err )
    aio[t] = nil  
    return co_wakeup(t.current_co, list, err)
  end)
  aio[t] = true
  aio_stat(t.event_co, assert(type(path) == 'string' and path ~= '' and path, "Invalid path."))
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
  aio_readdir(t.event_co, path)
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
  aio_rename(t.event_co, old_name, new_name)
  return co_wait()
end

-- 获取当前目录完整路径
function aio.currentdir(...)
  return aio.readpath(".")
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
  if type(path) ~= 'string' or path == "" then
    return nil, "Invalid path"
  end
  aio_readpath(t.event_co, path)
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
  aio_truncate(t.event_co, filename, (toint(length) and toint(length) > 0) and toint(length) or 0)
  return co_wait()
end

return aio