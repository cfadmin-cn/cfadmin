local class = require "class"

local tcp = require "tcp"
local tcp_read = tcp.read
local tcp_close = tcp.close

local sys = require "sys"
local new_tab = sys.new_tab

local cf = require "cf"
local co_new = coroutine.create
local co_self = cf.self
local co_wait = cf.wait
local co_wakeup = cf.wakeup

local laio = require "laio"
local aio_open = laio.open
local aio_stat = laio.stat
local aio_create = laio.create
local aio_flush = laio.flush
local aio_fflush = laio.fflush
local aio_remove = laio.remove
local aio_read = laio.read
local aio_write = laio.write
local aio_close = laio.close
local aio_rmdir = laio.rmdir
local aio_mkdir = laio.mkdir
local aio_rename = laio.rename
local aio_readdir = laio.readdir
local aio_readpath = laio.readpath
local aio_truncate = laio.truncate
local aio_popen = laio.popen
local aio_kill = laio.kill

local type = type
local assert = assert
local toint = math.tointeger
local tconcat = table.concat

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

-- 重置标志位
function File:lseek(read_offset, write_offset)
  if read_offset then
    self:read_lseek(read_offset)
  end
  if write_offset then
    self:write_lseek(write_offset)
  end
end

-- 重置read_offset; 这个方法一般情况下不会用到, 除非你非常明白自己在做什么.
function File:read_lseek(read_offset)
  if toint(read_offset) and toint(read_offset) >= 0 then
    self.read_offset = read_offset
  end
end

-- 重置write_offset; 这个方法一般情况下不会用到, 除非你非常明白自己在做什么.
function File:write_lseek(write_offset)
  if toint(write_offset) and toint(write_offset) >= 0 then
    self.write_offset = write_offset
  end
end

-- 读取文件指定大小内容; 除非调用read_lseek重置位置或有新内容写入, 否则超出文件长度后将会返回空字符串.
function File:read( bytes )
  if self.status == "closed" then
    return nil, "File already Closed."
  end
  bytes = toint(bytes)
  if not bytes or bytes <= 0 then
    if bytes == 0 then
      return "", 0
    end
    return nil, "Invalid file read bytes."
  end
  self.__READ__ = assert(not self.__READ__, "[File:read/readall ERROR] : This method cannot be called concurrently in multiple coroutines.")
  local stat, err = aio.stat(self.path)
  if not stat then
    self.__READ__ = nil
    return nil, err
  end
  self.stat = stat
  -- 这一段的意思是: 当存在offset则取offset, 否则将offset置0; 无特殊情况不需要改动此地方
  self.read_offset = stat.size - (stat.size - (toint(self.read_offset) and toint(self.read_offset) > 0 and toint(self.read_offset) or 0))
  local data, err = aio._read(self.fd, bytes, self.read_offset)
  self.read_offset = self.read_offset + #data
  self.__READ__ = nil
  return data, err
end

-- 读取文件所有内容; 除非调用read_lseek重置位置或有新内容写入, 否则超出文件长度后将会返回空字符串.
function File:readall()
  if self.status == "closed" then
    return nil, "File already Closed."
  end
  self.__READ__ = assert(not self.__READ__, "[File:read/readall ERROR] : This method cannot be called concurrently in multiple coroutines.")
  local stat, err = aio.stat(self.path)
  if not stat then
    self.__READ__ = nil
    return nil, err
  end
  self.stat = stat
  -- 这一段的意思是: 当存在offset则取offset, 否则将offset置0; 无特殊情况不需要改动此地方
  self.read_offset = stat.size - (stat.size - (toint(self.read_offset) and toint(self.read_offset) > 0 and toint(self.read_offset) or 0))
  local data, err = aio._read(self.fd, toint(self.stat.size), self.read_offset)
  self.read_offset = self.read_offset + #data
  self.__READ__ = nil
  return data, err
end

-- 写入文件
function File:write( data )
  if self.status == "closed" then
    return nil, "File already Closed."
  end
  if type(data) ~= 'string' or data == "" then
    return nil, "Invalid file write data."
  end
  self.__WRITE__ = assert(not self.__WRITE__, "[File:write ERROR] : This method cannot be called concurrently in multiple coroutines.")
  -- 如果没有构建write_offset, 则需要通过stat构建; 否则永远只从尾部开始写入.
  if not self.write_offset then
    if not self.stat then
      self.stat = aio.stat(self.path)
    end
    self.write_offset = self.stat.size
  end
  local size, err = aio._write(self.fd, data, self.write_offset)
  if type(size) == 'number' then
    self.stat.size = self.stat.size + size
    self.write_offset = self.write_offset + size
  end
  self.__WRITE__ = nil
  return size, err
end

-- function

-- 刷新缓存
function File:flush()
  if self.status == "closed" then
    return nil, "File already Closed."
  end
  self.__FLUSH__ = assert(not self.__FLUSH__, "[File:flush ERROR] : This method cannot be called concurrently in multiple coroutines.")
  local ok, err = aio.flush(self.fd)
  self.__FLUSH__ = nil
  return ok, err
end

-- 清空文件
function File:clean()
  if self.status == "closed" then
    return nil, "File already Closed."
  end
  self.__CLEAN__ = assert(not self.__CLEAN__, "[File:clean ERROR] : This method cannot be called concurrently in multiple coroutines.")
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
  if toint(self.write_offset) then
    self.write_offset = 0
  end
  self.stat = stat
  self.__CLEAN__ = nil
  return true
end

-- 关闭文件描述符
function File:close( ... )
  if self.status == "closed" then
    return nil, "File already closed."
  end
  local fd = self.fd
  self.fd = nil
  self.status = "closed"
  return aio._close(fd)
end

-- 打开文件，并返回File(始终以rw模式打开, 没有则会创建)
function aio.open(filename)
  local fd, err = aio._open(filename)
  if not fd then
    return nil, err
  end
  local stat, err = aio.stat(filename)
  if not stat then
    local t = new_tab(0, 3)
    t.current_co = co_self()
    t.event_co = co_new(function ( ok, err )
      aio[t] = nil
      return co_wakeup(t.current_co, ok, err)
    end)
    aio[t] = true
    aio_close(t.event_co, fd)
    return co_wait()
  end
  return File:new { fd = fd, path = filename }
end

-- 打开文件，并返回fd(始终以rw模式打开, 没有则会创建)
function aio._open(filename)
  filename = assert(type(filename) == 'string' and filename ~= '' and filename ~= '.' and filename ~= '..' and filename, "Invalid filename.")
  local t = new_tab(0, 3)
  t.current_co = co_self()
  t.event_co = co_new(function ( fd, err)
    aio[t] = nil
    return co_wakeup(t.current_co, fd, err)
  end)
  aio[t] = true
  aio_open(t.event_co, filename)
  return co_wait()
end

-- 打开文件, 如果不存在则创建(返回File)
function aio.create(filename)
  local fd, err = aio._create(filename)
  if not fd then
    return nil, err
  end
  local stat, err = aio.stat(filename)
  if not stat then
    local t = new_tab(0, 3)
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

-- 打开文件, 如果存在则失败(返回fd)
function aio._create(filename)
  filename = assert(type(filename) == 'string' and filename ~= '' and filename ~= '.' and filename ~= '..' and filename, "Invalid filename.")
  local t = new_tab(0, 3)
  t.current_co = co_self()
  t.event_co = co_new(function ( fd, err)
    aio[t] = nil
    return co_wakeup(t.current_co, fd, err)
  end)
  aio[t] = true
  aio_create(t.event_co, filename)
  return co_wait()
end

-- 读取指定字节
function aio._read(fd, bytes, offset)
  fd = assert(toint(fd) and toint(fd) >= 0 and toint(fd), "Invalid fd.")
  bytes = assert(toint(bytes) and toint(bytes) >= 0 and toint(bytes), "Invalid read bytes.")
  offset = assert(toint(offset) and toint(offset) >= 0 and toint(offset), "Invalid read offset.")
  local t = new_tab(0, 3)
  t.current_co = co_self()
  t.event_co = co_new(function ( data, size )
    aio[t] = nil
    return co_wakeup(t.current_co, data, size)
  end)
  aio[t] = true
  aio_read(t.event_co, fd, bytes, offset)
  return co_wait()
end

-- 写入(追加)指定大小数据
function aio._write(fd, data, offset)
  fd = assert(toint(fd) and toint(fd) >= 0 and toint(fd), "Invalid fd.")
  data = assert(type(data) == 'string' and data ~= '' and data, "Invalid write data.")
  local t = new_tab(0, 3)
  t.current_co = co_self()
  t.event_co = co_new(function ( size, err )
    aio[t] = nil
    return co_wakeup(t.current_co, size, err)
  end)
  aio[t] = true
  aio_write(t.event_co, fd, data, offset)
  return co_wait()
end

-- 仅关闭fd
function aio._close(fd)
  fd = assert(toint(fd) and toint(fd) >= 0 and toint(fd), "Invalid fd.")
  local t = new_tab(0, 3)
  t.current_co = co_self()
  t.event_co = co_new(function ( ok, err )
    aio[t] = nil
    return co_wakeup(t.current_co, ok, err)
  end)
  aio[t] = true
  aio_close(t.event_co, fd)
  return co_wait()
end

-- 创建指定文件夹
function aio.mkdir(dir)
  dir = assert(type(dir) == 'string' and dir ~= '' and dir, "Invalid folder.")
  local t = new_tab(0, 3)
  t.current_co = co_self()
  t.event_co = co_new(function ( ok, err )
    aio[t] = nil
    return co_wakeup(t.current_co, ok, err)
  end)
  aio[t] = true
  aio_mkdir(t.event_co, dir)
  return co_wait()
end

-- 删除指定文件夹
function aio.rmdir(dir)
  dir = assert(type(dir) == 'string' and dir ~= '' and dir, "Invalid folder.")
  local t = new_tab(0, 3)
  t.current_co = co_self()
  t.event_co = co_new(function ( ok, err )
    aio[t] = nil
    return co_wakeup(t.current_co, ok, err)
  end)
  aio[t] = true
  aio_rmdir(t.event_co, dir)
  return co_wait()
end

-- 获取文件/文件夹状态
function aio.attributes(path)
  return aio.stat(path)
end

-- 获取文件/文件夹状态
function aio.stat(path)
  local t = new_tab(0, 3)
  t.current_co = co_self()
  t.event_co = co_new(function ( list, err )
    aio[t] = nil
    return co_wakeup(t.current_co, list, err)
  end)
  aio[t] = true
  aio_stat(t.event_co, assert(type(path) == 'string' and path ~= '' and path, "Invalid path."))
  return co_wait()
end

-- 获取文件夹下所有文件(文件夹)
function aio.dir(path)
  path = assert(type(path) == 'string' and path ~= '' and path, "Invalid path.")
  local t = new_tab(0, 3)
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
  local t = new_tab(0, 3)
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
  path = assert(type(path) == "string" and path ~= "" and path, "Invalid read path.")
  local t = new_tab(0, 3)
  t.current_co = co_self()
  t.event_co = co_new(function ( path )
    aio[t] = nil
    return co_wakeup(t.current_co, path )
  end)
  aio[t] = true
  aio_readpath(t.event_co, path)
  return co_wait()
end

-- 清空文件或者缩减文件内容到指定大小. 当length为0或者nil的时候将会清空文件.
-- 注意: 这个操作是非常危险的, 您需要非常清楚自己的做什么.
function aio.truncate(filename, length)
  filename = assert(type(filename) == 'string' and filename ~= '' and filename, "Invalid filename.")
  local t = new_tab(0, 3)
  t.current_co = co_self()
  t.event_co = co_new(function ( ok, err )
    aio[t] = nil
    return co_wakeup(t.current_co, ok, err)
  end)
  aio[t] = true
  aio_truncate(t.event_co, filename, (toint(length) and toint(length) > 0) and toint(length) or 0)
  return co_wait()
end

-- 刷新fd缓存
function aio.flush(fd)
  fd = assert(toint(fd) and toint(fd) >= 0 and toint(fd), "Invalid fd.")
  local t = new_tab(0, 3)
  t.current_co = co_self()
  t.event_co = co_new(function ( ok, err )
    aio[t] = nil
    return co_wakeup(t.current_co, ok, err)
  end)
  aio[t] = true
  aio_flush(t.event_co, fd)
  return co_wait()
end

-- 刷新FILE指针缓存
function aio.fflush(file)
  local t = new_tab(0, 3)
  t.current_co = co_self()
  t.event_co = co_new(function ( ok, err )
    aio[t] = nil
    return co_wakeup(t.current_co, ok, err)
  end)
  aio[t] = aio_fflush(t.event_co, file)
  return co_wait()
end

-- 移除文件或文件夹
function aio.remove(filename)
  local t = new_tab(0, 3)
  t.current_co = co_self()
  t.event_co = co_new(function ( ok, err )
    aio[t] = nil
    return co_wakeup(t.current_co, ok, err)
  end)
  aio[t] = aio_remove(t.event_co, filename)
  return co_wait()
end

-- `pfile`对象
local pfile = { __name = "__PFILE__" }

pfile.__index = pfile

function pfile:read(bytes)
  if not self.fd then
    return false, "fd closed."
  end
  bytes = toint(bytes)
  if bytes and bytes > 0 then
    return tcp_read(self.fd, bytes)
  end
  bytes = 65535
  local buffers = {}
  while true do
    local buf = tcp_read(self.fd, bytes)
    if not buf then
      self:close()
      break
    end
    buffers[#buffers+1] = buf
  end
  return tconcat(buffers)
end

function pfile:__gc()
  self:close()
end

function pfile:close()
  if self.fd then
    tcp_close(self.fd)
    self.fd = nil
  end
end

---comment @`io.popen`的非阻塞版实现
---@param command string   @`command`是一个`string`类型的参数;
---@param timeout number   @`timeout`是一个`Number`类型的参数(可选), 可以指定合适的超时时间来控制进程运行时长.
---@return table|boolean   @子进程在退出后此方法才会返回; 正常退出返回`pfile`对象, 异常退出与错误退出返回`false`与出错信息;
---@return nil|string      @需要注意的是`pfile`对象必须开发者手动关闭, 否则可能会造成`fd`泄漏的问题.
function aio.popen(command, timeout)
  local ok, obj, co_timer, killed
  local co = co_self()
  local co_cb = co_new(function (id)
    -- 正常结束返回`0`, 异常结束返回`进程id`, 超时`kill`返回信号代码(9);
    -- print("进程结束: ", id)
    if co_timer then
      co_timer:stop()
    end
    return co_wakeup(co, id == 0 and true or false)
  end)
  ok, obj = pcall(aio_popen, command, co_cb)
  if not ok then
    return false, "[AIO_POPEN ERROR] : " .. obj
  end
  co_timer = cf.timeout(tonumber(timeout), function ()
    aio_kill(obj.pid)
    killed = true
    co_timer = nil
  end)
  tcp_close(obj.pipe[2])
  local f = setmetatable({ fd = obj.pipe[1] }, pfile)
  -- 等待子进程运行结束: 如果运行失败则返回错误信息, 如果运行成功则返回需要自己读取与手动关闭的`pfile`对象.
  if not co_wait() then
    local errinfo = f:read "*a"
    if killed then
      errinfo = "command timeout killed."
    end
    f:close()
    return false, "[AIO_POPEN ERROR] : " .. errinfo
  end
  return f
end

---comment `kill`指定进程
---@param pid    integer @进程的`PID`
---@param signum integer @信号的`num`
function aio.kill(pid, signum)
  aio_kill(pid, signum)
  return true
end

return aio
