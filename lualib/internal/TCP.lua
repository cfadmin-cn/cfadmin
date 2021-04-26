local class = require "class"

local new_tab = require("sys").new_tab

local log = require "logging"
local Log = log:new({ dump = true, path = 'internal-TCP' })

local type = type
local assert = assert
local io_open = io.open
local spack = string.pack
local insert = table.insert
local remove = table.remove

local dns = require "protocol.dns"
local dns_resolve = dns.resolve

local co = require "internal.Co"
local co_new = co.new
local co_wakeup = co.wakeup
local co_spawn = co.spawn
local co_self = co.self
local co_wait = coroutine.yield

local ti = require "internal.Timer"
local ti_timeout = ti.timeout

local tcp = require "tcp"
local tcp_new = tcp.new
local tcp_ssl_new = tcp.new_ssl
local tcp_ssl_new_fd = tcp.new_ssl_fd
local tcp_start = tcp.start
local tcp_stop = tcp.stop
local tcp_free_ssl = tcp.free_ssl
local tcp_close = tcp.close
local tcp_connect = tcp.connect
local tcp_ssl_do_handshake = tcp.ssl_connect
local tcp_read = tcp.read
local tcp_sslread = tcp.ssl_read
local tcp_write = tcp.write
local tcp_ssl_write = tcp.ssl_write
local tcp_listen = tcp.listen
local tcp_listen_ex = tcp.listen_ex
local tcp_sendfile = tcp.sendfile

local tcp_peek = tcp.peek
local tcp_sslpeek = tcp.sslpeek

local tcp_new_client_fd = tcp.new_client_fd
local tcp_new_server_fd = tcp.new_server_fd
local tcp_new_unixsock_fd = tcp.new_unixsock_fd

local tcp_ssl_verify = tcp.ssl_verify
local tcp_ssl_set_fd = tcp.ssl_set_fd
local tcp_ssl_set_alpn = tcp.ssl_set_alpn
local tcp_ssl_get_alpn = tcp.ssl_get_alpn
local tcp_set_read_buf = tcp.tcp_set_read_buf
local tcp_set_write_buf = tcp.tcp_set_write_buf
local ssl_set_connect_server = tcp.ssl_set_connect_server
local tcp_ssl_set_accept_mode = tcp.ssl_set_accept_mode
local tcp_ssl_set_connect_mode = tcp.ssl_set_connect_mode
local tcp_ssl_set_privatekey = tcp.ssl_set_privatekey
local tcp_ssl_set_certificate = tcp.ssl_set_certificate
local tcp_ssl_set_userdata_key = tcp.ssl_set_userdata_key

local EVENT_READ  = 0x01
local EVENT_WRITE = 0x02

local POOL = new_tab(1 << 10, 0)
local function tcp_pop()
  return remove(POOL) or tcp_new()
end

local function tcp_push(tcp)
  return insert(POOL, tcp)
end

local TCP = class("TCP")

function TCP:ctor(...)
--[[
  -- 当前socke运行模式
  self.mode = nil
  -- 默认关闭定时器
  self._timeout = nil
  -- 默认backlog
  self._backlog = 128
  -- connect 或 accept 得到的文件描述符
  self.fd = nil
  -- listen unix domain socket 文件描述符
  self.ufd = nil
  -- ssl 对象
  self.ssl = nil
  self.ssl_ctx = nil
  -- 密钥与证书路径
  self.privatekey_path = nil
  self.certificate_path = nil
  -- 配套密码
  self.ssl_password = nil
--]]
end

-- 超时时间
function TCP:timeout(Interval)
  if Interval and Interval > 0 then
    self._timeout = Interval
  end
  return self
end

-- 设置fd
function TCP:set_fd(fd)
  if not self.fd then
    self.fd = fd
  end
  return self
end

-- 设置backlog
function TCP:set_backlog(backlog)
  if type(backlog) == 'number' and backlog > 0 then
    self._backlog = backlog
  end
  return self
end

-- 开启验证
function TCP:ssl_set_verify()
  if not self.ssl or not self.ssl_ctx then
    self.ssl, self.ssl_ctx = tcp_ssl_new()
  end
  return tcp_ssl_verify(self.ssl, self.ssl_ctx)
end

-- 设置NPN/ALPN
function TCP:ssl_set_alpn(protocol)
  if type(protocol) == 'string' and protocol ~= '' then
   if not self.ssl or not self.ssl_ctx then
      self.ssl, self.ssl_ctx = tcp_ssl_new()
    end
    self.alpn = protocol
  end
end

-- 获取NPN/ALPN
function TCP:ssl_get_alpn()
 if not self.ssl or not self.ssl_ctx then
    return
  end
  return tcp_ssl_get_alpn(self.ssl, self.ssl_ctx)
end

-- 设置私钥
function TCP:ssl_set_privatekey(privatekey_path)
  if not self.ssl or not self.ssl_ctx then
    self.ssl, self.ssl_ctx = tcp_ssl_new()
  end
  assert(type(privatekey_path) == 'string' and privatekey_path ~= '', "Invalid privatekey_path")
  self.privatekey_path = privatekey_path
  return tcp_ssl_set_privatekey(self.ssl, self.ssl_ctx, self.privatekey_path)
end

-- 设置证书
function TCP:ssl_set_certificate(certificate_path)
  if not self.ssl or not self.ssl_ctx then
    self.ssl, self.ssl_ctx = tcp_ssl_new()
  end
  assert(type(certificate_path) == 'string' and certificate_path ~= '', "Invalid certificate_path")
  self.certificate_path = certificate_path
  return tcp_ssl_set_certificate(self.ssl, self.ssl_ctx, self.certificate_path)
end

-- 设置证书与私钥的密码
function TCP:ssl_set_password(password)
  if not self.ssl or not self.ssl_ctx then
    self.ssl, self.ssl_ctx = tcp_ssl_new()
  end
  assert(type(password) == 'string', "not have ssl or ssl_ctx.")
  self.ssl_password = password
  return tcp_ssl_set_userdata_key(self.ssl, self.ssl_ctx, self.ssl_password)
end

-- sendfile实现.
function TCP:sendfile (filename, offset)
  if self.ssl or self.ssl_ctx then
    return self:ssl_sendfile(filename, offset)
  end
  if type(filename) == 'string' and filename ~= '' then
    local co = co_self()
    self.SEND_IO = tcp_pop()
    self.sendfile_current_co = co_self()
    self.sendfile_co = co_new(function (ok)
      tcp_stop(self.SEND_IO)
      tcp_push(self.SEND_IO)
      self.SEND_IO = nil
      self.sendfile_co = nil
      self.sendfile_current_co = nil
      return co_wakeup(co, ok)
    end)
    tcp_sendfile(self.SEND_IO, self.sendfile_co, filename, self.fd, offset or 65535)
    return co_wait()
  end
end

-- ssl_sendfile实现
function TCP:ssl_sendfile(filename, offset)
  if type(filename) ~= 'string' or filename == '' then
    return nil, "Invalid filename."
  end
  local f, err = io_open(filename, "r")
  if not f then
    return nil, err
  end
  for buf in f:lines(offset or 65535) do
    if not self:ssl_send(buf) then
      return false, f:close()
    end
  end
  return true, f:close()
end

function TCP:send(buf)
  if self.ssl then
    return self:ssl_send(buf)
  end
  if not self.fd or type(buf) ~= 'string' or buf == '' then
    return
  end
  local wlen = tcp_write(self.fd, buf, 0)
  if not wlen or wlen == #buf then
    return wlen == #buf
  end
  -- 缓解发送大量数据集的时候调用频繁的问题
  if not self.wsize or self.wsize < #buf then
    self.wsize = #buf
    if self.wsize > (1 << 16) then
      if self.wsize > (1 << 20) then
        self.wsize = 1 << 20
      end
      tcp_set_write_buf(self.fd, self.wsize);
    end
  end
  local co = co_self()
  self.SEND_IO = tcp_pop()
  self.send_current_co = co_self()
  self.send_co = co_new(function ( )
    while 1 do
      local len = tcp_write(self.fd, buf, wlen)
      if not len or len + wlen == #buf then
        tcp_stop(self.SEND_IO)
        tcp_push(self.SEND_IO)
        self.SEND_IO = nil
        self.send_co = nil
        self.send_current_co = nil
        return co_wakeup(co, (len or 0) + wlen == #buf)
      end
      wlen = wlen + len
      co_wait()
    end
  end)
  tcp_start(self.SEND_IO, self.fd, EVENT_WRITE, self.send_co)
  return co_wait()
end

function TCP:ssl_send(buf)
  if not self.fd or not self.ssl or type(buf) ~= 'string' or buf == '' then
    return nil, "SSL Write Buffer error."
  end
  local ssl = self.ssl
  local wlen = tcp_ssl_write(ssl, buf, #buf)
  if not wlen or wlen == #buf then
    return wlen == #buf
  end
  -- 缓解发送大量数据集的时候调用频繁的问题
  if not self.wsize or self.wsize < #buf then
    self.wsize = #buf
    if self.wsize > (1 << 16) then
      if self.wsize > (1 << 20) then
        self.wsize = 1 << 20
      end
      tcp_set_write_buf(self.fd, self.wsize);
    end
  end
  local co = co_self()
  self.SEND_IO = tcp_pop()
  self.send_current_co = co_self()
  self.send_co = co_new(function ( )
    while 1 do
      local len = tcp_ssl_write(ssl, buf, #buf)
      if not len or len == #buf then
        tcp_stop(self.SEND_IO)
        tcp_push(self.SEND_IO)
        self.SEND_IO = nil
        self.send_co = nil
        self.send_current_co = nil
        return co_wakeup(co, len == #buf)
      end
      co_wait()
    end
  end)
  tcp_start(self.SEND_IO, self.fd, EVENT_WRITE, self.send_co)
  return co_wait()
end

-- READLINE
function TCP:readline(sp, nosp)
  if self.ssl then
    return self:ssl_readline(sp, nosp)
  end
  if type(sp) ~= 'string' or #sp < 1 then
    return nil, "Invalid separator."
  end
  local buffer
  local msize = 65535
  while 1 do
    ::CONTONIE::
    local buf, bsize = tcp_peek(self.fd, msize, true)
    if not buf then
      if bsize ~= 0 then
        return false, bsize
      end
      local co = co_self()
      self.READ_IO = tcp_pop()
      self.read_co = co_new(function ( )
        if self.timer then
          self.timer:stop()
          self.timer = nil
        end
        tcp_push(self.READ_IO)
        tcp_stop(self.READ_IO)
        self.READ_IO = nil
        self.read_co = nil
        return co_wakeup(co, true)
      end)
      self.timer = ti_timeout(self._timeout, function ( )
        tcp_push(self.READ_IO)
        tcp_stop(self.READ_IO)
        self.timer = nil
        self.READ_IO = nil
        self.read_co = nil
        self.read_current_co = nil
        return co_wakeup(co, nil, "read timeout")
      end)
      tcp_start(self.READ_IO, self.fd, EVENT_READ, self.read_co)
      local ok, errinfo = co_wait()
      if not ok then
        return false, errinfo
      end
      goto CONTONIE
    end
    buffer = buffer and (buffer .. buf) or buf
    local s, e = buffer:find(sp)
    if s and e then
      tcp_peek(self.fd, #buf - (#buffer - e), false)
      if nosp then
        e = s - 1
      end
      return buffer:sub(1, e), e
    end
    tcp_peek(self.fd, bsize, false)
  end
end

-- SSL READLINE
function TCP:ssl_readline(sp, nosp)
  if not self.ssl then
    return self:readline(sp, nosp)
  end
  if type(sp) ~= 'string' or #sp < 1 then
    return nil, "Invalid separator."
  end
  local buffer
  local msize = 65535
  -- 开始读取数据
  while 1 do
    ::CONTONIE::
    local buf, bsize = tcp_sslpeek(self.ssl, msize, true)
    if not buf then
      if bsize ~= 0 then
        return false, bsize
      end
      local co = co_self()
      self.READ_IO = tcp_pop()
      self.read_co = co_new(function ( )
        if self.timer then
          self.timer:stop()
          self.timer = nil
        end
        tcp_push(self.READ_IO)
        tcp_stop(self.READ_IO)
        self.READ_IO = nil
        self.read_co = nil
        return co_wakeup(co, true)
      end)
      self.timer = ti_timeout(self._timeout, function ( )
        tcp_push(self.READ_IO)
        tcp_stop(self.READ_IO)
        self.timer = nil
        self.READ_IO = nil
        self.read_co = nil
        self.read_current_co = nil
        return co_wakeup(co, nil, "read timeout")
      end)
      tcp_start(self.READ_IO, self.fd, EVENT_READ, self.read_co)
      local ok, errinfo = co_wait()
      if not ok then
        return false, errinfo
      end
      goto CONTONIE
    end
    buffer = buffer and (buffer .. buf) or buf
    local s, e = buffer:find(sp)
    if s and e then
      tcp_sslpeek(self.ssl, #buf - (#buffer - e), false)
      if nosp then
        e = s - 1
      end
      return buffer:sub(1, e), e
    end
    tcp_sslpeek(self.ssl, bsize, false)
  end
end

function TCP:recv(bytes)
  if self.ssl then
    return self:ssl_recv(bytes)
  end
  local fd = self.fd
  local data, len = tcp_read(fd, bytes)
  if type(len) ~= 'number' or len > 0 then
    return data, len
  end
  -- 优化大数据集的调用次数太多的问题
  if not self.rsize or self.rsize < bytes then
    self.rsize = bytes
    if self.rsize > (1 << 16) then
      if self.rsize > (1 << 20) then
        self.rsize = 1 << 20
      end
      tcp_set_read_buf(fd, self.rsize);
    end
  end
  local coctx = co_self()
  self.READ_IO = tcp_pop()
  self.read_current_co = co_self()
  self.read_co = co_new(function ( )
    local buf, bsize = tcp_read(fd, bytes)
    if self.timer then
      self.timer:stop()
      self.timer = nil
    end
    tcp_push(self.READ_IO)
    tcp_stop(self.READ_IO)
    self.READ_IO = nil
    self.read_co = nil
    self.read_current_co = nil
    return co_wakeup(coctx, buf, bsize)
  end)
  self.timer = ti_timeout(self._timeout, function ( )
    tcp_push(self.READ_IO)
    tcp_stop(self.READ_IO)
    self.timer = nil
    self.read_co = nil
    self.READ_IO = nil
    self.read_current_co = nil
    return co_wakeup(coctx, nil, "read timeout")
  end)
  tcp_start(self.READ_IO, fd, EVENT_READ, self.read_co)
  return co_wait()
end

function TCP:ssl_recv(bytes)
  local ssl = self.ssl
  if not ssl then
    Log:ERROR("Please use recv method :)")
    return nil, "Please use recv method :)"
  end
  local buf, len = tcp_sslread(ssl, bytes)
  if buf then
    return buf, len
  end
  -- 优化大数据集的调用次数太多的问题
  if not self.rsize or self.rsize < bytes then
    self.rsize = bytes
    if self.rsize > (1 << 16) then
      if self.rsize > (1 << 20) then
        self.rsize = 1 << 20
      end
      tcp_set_read_buf(self.fd, self.rsize);
    end
  end
  local coctx = co_self()
  self.READ_IO = tcp_pop()
  self.read_current_co = co_self()
  self.read_co = co_new(function ( )
    while true do
      local buffer, bsize = tcp_sslread(ssl, bytes)
      if (buffer and bsize) or (not buffer and not bsize) then
        if self.timer then
          self.timer:stop()
          self.timer = nil
        end
        tcp_push(self.READ_IO)
        tcp_stop(self.READ_IO)
        self.READ_IO = nil
        self.read_co = nil
        self.read_current_co = nil
        return co_wakeup(coctx, buffer, bsize)
      end
      co_wait()
    end
  end)
  self.timer = ti_timeout(self._timeout, function ( )
    tcp_push(self.READ_IO)
    tcp_stop(self.READ_IO)
    self.timer = nil
    self.READ_IO = nil
    self.read_co = nil
    self.read_current_co = nil
    return co_wakeup(coctx, nil, "read timeout")
  end)
  tcp_start(self.READ_IO, self.fd, EVENT_READ, self.read_co)
  return co_wait()
end

function TCP:listen(ip, port, cb)
  self.mode = "server"
  self.LISTEN_IO = tcp_pop()
  self.fd = tcp_new_server_fd(ip, port, self._backlog or 128)
  if not self.fd then
    return nil, "Listen port failed. Please check if the port is already occupied."
  end
  if type(cb) ~= 'function' then
    return nil, "Listen function was invalid."
  end
  self.listen_co = co_new(function (fd, ipaddr, port)
    while 1 do
      if fd and ipaddr then
        co_spawn(cb, fd, ipaddr, port)
        fd, ipaddr, port = co_wait()
      end
    end
  end)
  return true, tcp_listen(self.LISTEN_IO, self.fd, self.listen_co)
end

local function ssl_accept(callback, fd, ipaddr, port, opt)
  local sock = TCP:new()
  sock:set_fd(fd):timeout(5) -- 如果ssl握手长期未完成则选择断开连接
  sock.ssl, sock.ssl_ctx = tcp_ssl_new_fd(fd)
  if type(opt.pw) == 'string' and opt.pw ~= '' then
    sock:ssl_set_password(opt.pw)
  end
  sock.mode = "server"
  sock:ssl_set_certificate(opt.cert)
  sock:ssl_set_privatekey(opt.key)
  tcp_ssl_set_accept_mode(sock.ssl, sock.ssl_ctx)
  if not sock:ssl_handshake() then
    return sock:close()
  end
  return callback(sock, ipaddr, port)
end

function TCP:listen_ssl(ip, port, opt, cb)
  self.mode = "server"
  self.LISTEN_SSL_IO = tcp_pop()
  self.sfd = tcp_new_server_fd(ip, port, self._backlog or 128)
  if not self.sfd then
    return nil, "Listen port failed. Please check if the port is already occupied."
  end
  if type(opt) ~= 'table' then
    return nil, "ssl listen must have key/cert/pw(optional)."
  end
  if type(opt.pw) == 'string' and opt.pw ~= '' then
    self:ssl_set_password(opt.pw)
  end
  self:ssl_set_certificate(opt.cert)
  self:ssl_set_privatekey(opt.key)
  -- 验证证书与私钥有效性
  if not self:ssl_set_verify() then
    return nil, "The certificate does not match the private key."
  end
  if type(cb) ~= 'function' then
    return nil, "Listen function was invalid."
  end
  self.listen_ssl_co = co_new(function (fd, ipaddr, port)
    while 1 do
      if fd and ipaddr then
        co_spawn(ssl_accept, cb, fd, ipaddr, port, opt)
        fd, ipaddr, port = co_wait()
      end
    end
  end)
  return true, tcp_listen(self.LISTEN_SSL_IO, self.sfd, self.listen_ssl_co)
end

function TCP:listen_ex(unix_domain_path, removed, cb)
  self.mode = "server"
  self.LISTEN_EX_IO = tcp_pop()
  self.ufd = tcp_new_unixsock_fd(unix_domain_path, removed or true, self._backlog or 128)
  if not self.ufd then
    return nil, "Listen_ex unix domain socket failed. Please check the domain_path was exists and access."
  end
  if type(cb) ~= 'function' then
    return nil, "Listen_ex function was invalid."
  end
  self.listen_ex_co = co_new(function (fd)
    while 1 do
      if fd then
        co_spawn(cb, fd, "127.0.0.1")
        fd = co_wait()
      end
    end
  end)
  return true, tcp_listen_ex(self.LISTEN_EX_IO, self.ufd, self.listen_ex_co)
end

function TCP:connect(domain, port)
  self.mode = "client"
  local ok, IP = dns_resolve(domain)
  if not ok then
      return nil, "Can't resolve this domain or ip:"..(domain or IP or "")
  end
  self.fd = tcp_new_client_fd(IP, port)
  if not self.fd then
      return nil, "Connect This host fault! "..(domain or "no domain")..":"..(port or "no port")
  end
  local co = co_self()
  self.CONNECT_IO = tcp_pop()
  self.connect_current_co = co_self()
  self.connect_co = co_new(function (connected, errinfo)
    if self.timer then
      self.timer:stop()
      self.timer = nil
    end
    tcp_push(self.CONNECT_IO)
    tcp_stop(self.CONNECT_IO)
    self.connect_current_co = nil
    self.CONNECT_IO = nil
    self.connect_co = nil
    return co_wakeup(co, connected, errinfo)
  end)
  self.timer = ti_timeout(self._timeout, function ()
      tcp_push(self.CONNECT_IO)
      tcp_stop(self.CONNECT_IO)
      self.timer = nil
      self.CONNECT_IO = nil
      self.connect_co = nil
      self.connect_current_co = nil
      return co_wakeup(co, nil, 'connect timeout.')
  end)
  tcp_connect(self.CONNECT_IO, self.fd, self.connect_co)
  return co_wait()
end

function TCP:ssl_connect(domain, port)
  local ok, errinfo = self:connect(domain, port)
  if not ok then
    return false, errinfo
  end
  return self:ssl_handshake(domain)
end

local function event_wait(self, event)
  -- 当前协程对象
  local co = co_self()
  self.connect_current_co = co
  -- 从对象池之中取出一个观察者对象
  self.CONNECT_IO = tcp_pop()
  -- 读/写回调
  self.connect_co = co_new(function ( )
    -- 如果事件在超时之前到来需要停止定时器
    if self.timer then
      self.timer:stop()
      self.timer = nil
    end
    -- 停止当前IO事件观察者并且将其放入对象池之中
    tcp_stop(self.CONNECT_IO)
    tcp_push(self.CONNECT_IO)
    self.CONNECT_IO = nil
    self.connect_co = nil
    self.connect_current_co = nil
    -- 唤醒协程
    return co_wakeup(co, true)
  end)
  -- 定时器回调
  self.timer = ti_timeout(self._timeout, function ( )
    -- 停止当前IO事件观察者并且将其放入对象池之中
    tcp_push(self.CONNECT_IO)
    tcp_stop(self.CONNECT_IO)
    self.timer = nil
    self.CONNECT_IO = nil
    self.connect_co = nil
    self.connect_current_co = nil
    -- 唤醒协程
    return co_wakeup(co, nil, 'connect timeout.')
  end)
  -- 注册I/O事件
  tcp_start(self.CONNECT_IO, self.fd, event, self.connect_co)
  -- 让出执行权
  return co_wait()
end

function TCP:ssl_handshake(domain)
  -- 如果设置了NPN/ALPN, 则需要在握手协商中指定.
  if self.alpn then
    tcp_ssl_set_alpn(self.ssl, self.ssl_ctx, spack(">B", #self.alpn) .. self.alpn)
  end
  -- 如果是服务端模式, 需要等待客户端先返送hello信息.
  -- 如果是客户端模式, 需要先发送hello信息.
  if self.mode == "server" then
    local ok, err = event_wait(self, EVENT_READ)
    if not ok then
      return nil, err
    end
  else
    if not self.ssl_ctx and not self.ssl then
      self.ssl, self.ssl_ctx = tcp_ssl_new_fd(self.fd)
    else
      tcp_ssl_set_fd(self.ssl, self.fd)
    end
    -- 如果有必要的话, 增加TLS的SNI特性支持.
    ssl_set_connect_server(self.ssl, domain or "localhost")
  end
  -- 开始握手
  :: CONTINUE ::
  local successe, event = tcp_ssl_do_handshake(self.ssl)
  if not successe then
    -- 握手失败无需继续尝试
    if not event then
      return nil, "ssl handshake failed."
    end
    -- 获取下次握手的等待事件: `READ` 或 `WRITE`
    local ok, errinfo = event_wait(self, event)
    if ok then
      -- 如果本次尝试成功则继续握手流程
      goto CONTINUE
    end
    -- 握手超时、连接超时或连接中断
    return nil, errinfo
  end
  -- 握手成功
  return true
end

function TCP:count()
    return #POOL
end

function TCP:close()

  if self.timer then
    self.timer:stop()
    self.timer = nil
  end

  if self.READ_IO then
    tcp_stop(self.READ_IO)
    tcp_push(self.READ_IO)
    self.READ_IO = nil
    self.read_co = nil
  end

  if self.SEND_IO then
    tcp_stop(self.SEND_IO)
    tcp_push(self.SEND_IO)
    self.SEND_IO = nil
    self.send_co = nil
    self.sendfile_co = nil
  end

  if self.CONNECT_IO then
    tcp_stop(self.CONNECT_IO)
    tcp_push(self.CONNECT_IO)
    self.CONNECT_IO = nil
    self.connect_co = nil
  end

  if self.LISTEN_IO then
    tcp_stop(self.LISTEN_IO)
    tcp_push(self.LISTEN_IO)
    self.LISTEN_IO = nil
    self.listen_co = nil
  end

  if self.LISTEN_EX_IO then
    tcp_stop(self.LISTEN_EX_IO)
    tcp_push(self.LISTEN_EX_IO)
    self.LISTEN_EX_IO = nil
    self.listen_ex_co = nil
  end

  if self.LISTEN_SSL_IO then
    tcp_stop(self.LISTEN_SSL_IO)
    tcp_push(self.LISTEN_SSL_IO)
    self.LISTEN_SSL_IO = nil
    self.listen_ssl_co = nil
  end

  if self.connect_current_co then
    co_wakeup(self.connect_current_co)
    self.connect_current_co = nil
  end

  if self.send_current_co then
    co_wakeup(self.send_current_co)
    self.send_current_co = nil
  end

  if self.read_current_co then
    co_wakeup(self.read_current_co)
    self.read_current_co = nil
  end

  if self.sendfile_current_co then
    co_wakeup(self.sendfile_current_co)
    self.sendfile_current_co = nil
  end

  if self._timeout then
    self._timeout = nil
  end

  if self.ssl and self.ssl_ctx then
    tcp_free_ssl(self.ssl, self.ssl_ctx)
    self.ssl_ctx = nil
    self.ssl = nil
  end

  if self.fd then
    tcp_close(self.fd)
    self.fd = nil
  end

  if self.ufd then
    tcp_close(self.ufd)
    self.ufd = nil
  end

  if self.sfd then
    tcp_close(self.sfd)
    self.sfd = nil
  end

end

return TCP