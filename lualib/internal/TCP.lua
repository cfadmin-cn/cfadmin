local class = require "class"

local log = require "logging"
local Log = log:new({ dump = true, path = 'internal-TCP' })

local split = string.sub
local insert = table.insert
local remove = table.remove

local dns = require "protocol.dns"
local dns_resolve = dns.resolve

local co = require "internal.Co"
local co_new = co.new
local co_wakeup = co.wakeup
local co_spwan = co.spwan
local co_self = co.self
local co_wait = coroutine.yield

local ti = require "internal.Timer"
local ti_timeout = ti.timeout

local tcp = require "tcp"
local tcp_new = tcp.new
local tcp_start = tcp.start
local tcp_stop = tcp.stop
local tcp_free_ssl = tcp.free_ssl
local tcp_close = tcp.close
local tcp_connect = tcp.connect
local tcp_ssl_do_handshak = tcp.ssl_connect
local tcp_read = tcp.read
local tcp_sslread = tcp.ssl_read
local tcp_write = tcp.write
local tcp_ssl_write = tcp.ssl_write
local tcp_listen = tcp.listen
local tcp_sendfile = tcp.sendfile

local tcp_new_client_fd = tcp.new_client_fd
local tcp_new_server_fd = tcp.new_server_fd


local EVENT_READ  = 0x01
local EVENT_WRITE = 0x02

local POOL = {}
local function tcp_pop()
  if #POOL > 0 then
      return remove(POOL)
  end
  return tcp_new()
end

local function tcp_push(tcp)
    POOL[#POOL+1] = tcp
end

local TCP = class("TCP")

function TCP:ctor(...)

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

function TCP:sendfile (filename, offset)
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
    tcp_sendfile(self.SEND_IO, self.sendfile_co, filename, self.fd, offset or 4096)
    return co_wait()
  end
end

function TCP:send(buf)
  if self.ssl then
    Log:ERROR("Please use ssl_send method :)")
    return
  end
  if type(buf) ~= 'string' or buf == '' then
    return
  end
  local wlen = tcp_write(self.fd, buf, #buf)
  if not wlen or wlen == #buf then
    return wlen == #buf
  end
  buf = split(buf, wlen + 1, -1)
  local co = co_self()
  self.SEND_IO = tcp_pop()
  self.send_current_co = co_self()
  self.send_co = co_new(function ( ... )
    while 1 do
      local len = tcp_write(self.fd, buf, #buf)
      if not len or len == #buf then
        tcp_stop(self.SEND_IO)
        tcp_push(self.SEND_IO)
        self.SEND_IO = nil
        self.send_co = nil
        self.send_current_co = nil
        return co_wakeup(co, len == #buf)
      end
      buf = split(buf, len + 1, -1)
      co_wait()
    end
  end)
  tcp_start(self.SEND_IO, self.fd, EVENT_WRITE, self.send_co)
  return co_wait()
end

function TCP:ssl_send(buf)
  if not self.ssl then
    Log:ERROR("Please use send method :)")
    return
  end
  if type(buf) ~= 'string' or buf == '' then
    return
  end
  local wlen = tcp_ssl_write(self.ssl, buf, #buf)
  if not wlen or wlen == #buf then
    return wlen == #buf
  end
  buf = split(buf, wlen + 1, -1)
  self.SEND_IO = tcp_pop()
  local co = co_self()
  self.send_current_co = co_self()
  self.send_co = co_new(function ( ... )
    while 1 do
      local len = tcp_ssl_write(self.ssl, buf, #buf)
      if not len or len == #buf then
        tcp_stop(self.SEND_IO)
        tcp_push(self.SEND_IO)
        self.SEND_IO = nil
        self.send_co = nil
        self.send_current_co = nil
        return co_wakeup(co, len == #buf)
      end
      buf = split(buf, len + 1, -1)
      co_wait()
    end
  end)
  tcp_start(self.SEND_IO, self.fd, EVENT_WRITE, self.send_co)
  return co_wait()
end

function TCP:recv(bytes)
    if self.ssl then
      Log:ERROR("Please use ssl_recv method :)")
      return
    end
    local data, len = tcp_read(self.fd, bytes)
    if not len or len > 0 then
      return data, not len and 'close' or len
    end
    local co = co_self()
    self.READ_IO = tcp_pop()
    self.read_current_co = co_self()
    self.read_co = co_new(function ( ... )
        local buf, len = tcp_read(self.fd, bytes)
        if self.timer then
            self.timer:stop()
            self.timer = nil
        end
        tcp_push(self.READ_IO)
        tcp_stop(self.READ_IO)
        self.READ_IO = nil
        self.read_co = nil
        self.read_current_co =nil
        if not buf then
            return co_wakeup(co)
        end
        return co_wakeup(co, buf, len)
    end)
    self.timer = ti_timeout(self._timeout, function ( ... )
        tcp_push(self.READ_IO)
        tcp_stop(self.READ_IO)
        self.timer = nil
        self.read_co = nil
        self.READ_IO = nil
        self.read_current_co = nil
        return co_wakeup(co, nil, "read timeout")
    end)
    tcp_start(self.READ_IO, self.fd, EVENT_READ, self.read_co)
    return co_wait()
end

function TCP:ssl_recv(bytes)
    if not self.ssl then
      Log:ERROR("Please use recv method :)")
      return
    end
    local buf, len = tcp_sslread(self.ssl, bytes)
    if not buf then
        local co = co_self()
        self.read_current_co = co_self()
        self.READ_IO = tcp_pop()
        self.read_co = co_new(function ( ... )
            while 1 do
                local buf, len = tcp_sslread(self.ssl, bytes)
                if not buf and not len then
                    if self.timer then
                        self.timer:stop()
                        self.timer = nil
                    end
                    tcp_push(self.READ_IO)
                    tcp_stop(self.READ_IO)
                    self.READ_IO = nil
                    self.read_co = nil
                    self.read_current_co = nil
                    return co_wakeup(co)
                end
                if buf and len then
                    if self.timer then
                        self.timer:stop()
                        self.timer = nil
                    end
                    tcp_push(self.READ_IO)
                    tcp_stop(self.READ_IO)
                    self.READ_IO = nil
                    self.read_co = nil
                    self.read_current_co = nil
                    return co_wakeup(co, buf, len)
                end
                co_wait()
            end
        end)
        self.timer = ti_timeout(self._timeout, function ( ... )
            tcp_push(self.READ_IO)
            tcp_stop(self.READ_IO)
            self.timer = nil
            self.READ_IO = nil
            self.read_co = nil
            self.read_current_co = nil
            return co_wakeup(co, nil, "read timeout")
        end)
        tcp_start(self.READ_IO, self.fd, EVENT_READ, self.read_co)
        return co_wait()
    end
    return buf, len
end

function TCP:listen(ip, port, cb)
    self.LISTEN_IO = tcp_pop()
    self.fd = tcp_new_server_fd(ip, port, self._backlog)
    if not self.fd then
        return nil, "Listen port failed. Please check if the port is already occupied."
    end
    self.co = co_new(function (fd, ipaddr)
        while 1 do
            if fd and ipaddr then
                co_spwan(cb, fd, ipaddr)
                fd, ipaddr = co_wait()
            end
        end
    end)
    return true, tcp_listen(self.LISTEN_IO, self.fd, self.co)
end

function TCP:connect(domain, port)
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
  self.connect_co = co_new(function (connected)
    if self.timer then
        self.timer:stop()
        self.timer = nil
    end
    tcp_push(self.CONNECT_IO)
    tcp_stop(self.CONNECT_IO)
    self.connect_current_co = nil
    self.CONNECT_IO = nil
    self.connect_co = nil
    if connected then
        return co_wakeup(co, true)
    end
    return co_wakeup(co, false, '连接失败')
  end)
  self.timer = ti_timeout(self._timeout, function ( ... )
      tcp_push(self.CONNECT_IO)
      tcp_stop(self.CONNECT_IO)
      self.timer = nil
      self.CONNECT_IO = nil
      self.connect_co = nil
      self.connect_current_co = nil
      return co_wakeup(co, nil, 'connect timeot.')
  end)
  tcp_connect(self.CONNECT_IO, self.fd, self.connect_co)
  return co_wait()
end

function TCP:ssl_connect(domain, port)
  local ok, err = self:connect(domain, port)
  if not ok then
      return nil, "domain connect error."
  end
  self.ssl_ctx, self.ssl = tcp.new_ssl(self.fd)
  if not self.ssl_ctx or not self.ssl then
      return nil, "create a ssl ctx error."
  end
  local co = co_self()
  self.CONNECT_IO = tcp_pop()
  self.connect_current_co = co_self()
  self.connect_co = co_new(function ()
    local EVENTS = EVENT_WRITE
    while 1 do
      local ok, EVENT = tcp_ssl_do_handshak(self.ssl)
      if ok or not EVENT then
        if self.timer then
          self.timer:stop()
          self.timer = nil
        end
        tcp_push(self.CONNECT_IO)
        tcp_stop(self.CONNECT_IO)
        self.CONNECT_IO = nil
        self.connect_co = nil
        self.connect_current_co = nil
        return co_wakeup(co, ok)
      end
      if EVENTS ~= EVENT then
        EVENTS = EVENT
        tcp_stop(self.CONNECT_IO)
        tcp_start(self.CONNECT_IO, self.fd, EVENTS, self.connect_co)
      end
      co_wait()
    end
  end)
  self.timer = ti_timeout(self._timeout, function ( ... )
      tcp_push(self.CONNECT_IO)
      tcp_stop(self.CONNECT_IO)
      self.timer = nil
      self.CONNECT_IO = nil
      self.connect_co = nil
      self.connect_current_co = nil
      return co_wakeup(co, nil, 'ssl_connect timeot.')
  end)
  tcp_start(self.CONNECT_IO, self.fd, EVENT_WRITE, self.connect_co)
  return co_wait()
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
        tcp_free_ssl(self.ssl_ctx, self.ssl)
        self.ssl_ctx = nil
        self.ssl = nil
    end

    if self.fd then
        tcp_close(self.fd)
        self.fd = nil
    end

end

return TCP
