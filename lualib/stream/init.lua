local TCP = require "internal.TCP"
local sock_read = TCP.recv
local sock_write = TCP.send
local sock_readline = TCP.readline
local sock_connect = TCP.connect
local sock_connectx = TCP.connect_ex
local sock_sslconnect = TCP.ssl_connect

local new_tab = require "sys".new_tab

local cf = require "cf"
local cf_fork = cf.fork

local type = type
local error = error
local ipairs = ipairs
local getmetatable = getmetatable

local mtype = math.type
local strfmt = string.format
local tconcat = table.concat

local class = require "class"

local Stream = class("Stream")

function Stream:ctor(sock)
  if getmetatable(sock) ~= TCP then
    error(strfmt("[Stream Error]: Invalid Socket object in (%s:%d).", debug.getinfo(3, "S").source, debug.getinfo(3, "l").currentline))
  end
  self.tcp = sock
end

function Stream:set_fd(fd)
  self.tcp:set_fd(fd)
  return self
end

function Stream:timeout(ts)
  self.tcp:timeout(ts)
  return self
end

function Stream:connect(domain, port)
  return sock_connect(self.tcp, domain, port)
end

function Stream:ssl_connect(domain, port)
  return sock_sslconnect(self.tcp, domain, port)
end

function Stream:connectx(path)
  return sock_connectx(self.tcp, path)
end

---comment  @同步写入(阻塞当前协程)
---@param buf string  @待写入的数据
---@return boolean    @写入成功返回`true`, 写入失败返回`false`
function Stream:send(buf)
  if type (buf) ~= 'string' or buf == '' then
    error(strfmt("[Stream Error]: pass Invalid send buffer in (%s:%d)", debug.getinfo(2, "S").source, debug.getinfo(2, "l").currentline))
  end
  return sock_write(self.tcp, buf)
end

---comment  @异步写入(不会阻塞当前协程)
---@param buf string  @待写入的数据
function Stream:write(buf)
  if type (buf) ~= 'string' or buf == '' then
    error(strfmt("[Stream Error]: pass Invalid write buffer in (%s:%d)", debug.getinfo(2, "S").source, debug.getinfo(2, "l").currentline))
  end
  -- 异步写入队列
  if not self.wqueue then
    self.wqueue = new_tab(8, 0)
    cf_fork(function ()
      local sock = self.tcp
      if sock and self.wqueue then
        for _, buffer in ipairs(self.wqueue) do
          if not sock_write(sock, buffer) then
            break
          end
        end
      end
      self.wqueue = nil
    end)
  end
  self.wqueue[#self.wqueue+1] = buf
end

function Stream:recv(nbytes)
  return self:read(nbytes)
end

---comment @读取指定数量的网络数据(此函数只要缓冲区里有数据立刻返回)
---@param nbytes integer @指定的要读取的数量.
---@return string | nil  @读取成功返回内容, 失败返回`nil`
function Stream:read(nbytes)
  if mtype(nbytes) ~= 'integer' or nbytes < 1 then
    error(strfmt("[Stream Error]: Pass invalid nbytes in (%s:%d)", debug.getinfo(2, "S").source, debug.getinfo(2, "l").currentline))
  end
  return sock_read(self.tcp, nbytes)
end

---comment @读取数据直到遇到指定分隔符, 可以选择返回的数据不包括分隔符.
---@param sp string      @字符串类型的分隔符
---@param nosp boolean   @返回数据是否包括分隔符
---@return string | nil  @读取成功返回内容, 失败返回`nil`
function Stream:readline(sp, nosp)
  if type(sp) ~= 'string' or sp == '' then
    error(strfmt("[Stream Error]: Pass invalid readline char in (%s:%d)", debug.getinfo(2, "S").source, debug.getinfo(2, "l").currentline))
  end
  return sock_readline(self.tcp, sp, nosp)
end

---comment @读取指定数量的网络数据(读取足够字节或者连接断开才会返回).
---@param nbytes integer @指定的要读取的数量.
---@return string | nil  @读取成功返回内容, 失败返回`nil`
function Stream:readbytes(nbytes)
  if mtype(nbytes) ~= 'integer' or nbytes < 1 then
    error(strfmt("[Stream Error]: Pass invalid nbytes in (%s:%d)", debug.getinfo(2, "S").source, debug.getinfo(2, "l").currentline))
  end
  local sock, buffer, len, buffers = self.tcp, nil, nil, nil
  :: CONTINUE ::
  buffer, len = sock_read(sock, nbytes)
  if not buffer then
    return
  end
  -- 检查读取的字节数
  if len == nbytes then
    -- 如果是一次性读取完毕直接返回
    if not buffers then
      return buffer
    end
    -- 如果是多次读取完毕
    buffers[#buffers+1] = buffer
    return tconcat(buffers)
  end
  if not buffers then
    buffers = new_tab(3, 0)
  end
  -- 计算字节数并且准备继续读取
  buffers[#buffers+1] = buffer
  nbytes = nbytes - len
  goto CONTINUE
end

---comment @监听网络套接字
---@param ip string    @监听指定地址
---@param port integer @监听指定端口
---@param cb function  @连接建立成功的回调
function Stream:listen(ip, port, cb)
  self.tcp:listen(ip, port, function (fd, ...)
    return cb(Stream(TCP():set_fd(fd):timeout(0)), ...)
  end)
end

---comment @监听本机套接字
---@param path string  @本机套接字所在路径
---@param cb function  @连接建立成功的回调
function Stream:listenx(path, cb)
  self.tcp:listen_ex(path, function (fd, ...)
    return cb(Stream(TCP():set_fd(fd):timeout(0)), ...)
  end)
end

function Stream:run_forever()
  return cf.wait()
end

function Stream:run()
  return self:run_forever()
end

function Stream:close()
  if self.tcp then
    self.tcp:close()
    self.tcp = nil
  end
  if self.wqueue then
    self.wqueue = nil
  end
end

return Stream