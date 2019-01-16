local ti = require "internal.Timer"
local co = require "internal.Co"
local class = require "class"
local tcp = require "tcp"
local log = require "log"

local split = string.sub
local insert = table.insert
local remove = table.remove

local co_new = co.new
local co_wakeup = co.wakeup
local co_spwan = co.spwan
local co_wait = co.wait
local co_self = co.self

local tcp_start = tcp.start
local tcp_stop = tcp.stop
local tcp_free_ssl = tcp.free_ssl
local tcp_close = tcp.close
local tcp_connect = tcp.connect
local tcp_ssl_connect = tcp.ssl_connect
local tcp_read = tcp.read
local tcp_sslread = tcp.ssl_read
local tcp_write = tcp.write
local tcp_ssl_write = tcp.ssl_write
local tcp_new_tcp_fd = tcp.new_tcp_fd

local EVENT_READ  = 0x01
local EVENT_WRITE = 0x02

local SERVER = 0
local CLIENT = 1


local POOL = {}
local function tcp_pop()
    if #POOL > 0 then
        return remove(POOL)
    end
    return tcp.new()
end

local function tcp_push(tcp)
    insert(POOL, tcp)
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

function TCP:send(buf)
    if self.ssl then
        return log.error("Please use ssl_send method :)")
    end
    while 1 do
        local len = tcp_write(self.fd, buf, #buf)
        if not len or len == #buf then
            return len == #buf
        end
        if len == 0 then
            self.SEND_IO = tcp_pop()
            local co = co_self()
            self.send_co = co_new(function ( ... )
                while 1 do
                    local len = tcp_write(self.fd, buf, #buf)
                    if not len or len == #buf then
                        tcp_push(self.SEND_IO)
                        tcp_stop(self.SEND_IO)
                        self.SEND_IO = nil
                        self.send_co = nil
                        -- 这里在发送数据的时候, 客户端可能已经关闭了链接
                        -- if not len then log.error("write error.")
                        return co_wakeup(co, len == #buf)
                    end
                    buf = split(buf, len + 1, -1)
                    co_wait()
                end
            end)
            tcp_start(self.SEND_IO, self.fd, EVENT_WRITE, self.send_co)
            return co_wait()
        end
        buf = split(buf, len + 1, -1)
    end
end

function TCP:ssl_send(buf)
    if not self.ssl then
        return log.error("Please use send method :)")
    end
    while 1 do
        local len = tcp_ssl_write(self.ssl, buf, #buf)
        if not len or len == #buf then
            return len == #buf
        end
        if len == 0 then
            self.SEND_IO = tcp_pop()
            local co = co_self()
            self.send_co = co_new(function ( ... )
                while 1 do
                    local len = tcp_ssl_write(self.ssl, buf, #buf)
                    if not len or len == #buf then
                        tcp_push(self.SEND_IO)
                        tcp_stop(self.SEND_IO)
                        self.SEND_IO = nil
                        self.send_co = nil
                        -- 这里在发送数据的时候, 客户端可能已经关闭了链接
                        -- if not len then log.error("write error.")
                        return co_wakeup(co, len == #buf)
                    end
                    buf = split(buf, len + 1, -1)
                    co_wait()
                end
            end)
            tcp_start(self.SEND_IO, self.fd, EVENT_WRITE, self.send_co)
            return co_wait()
        end
        buf = split(buf, len + 1, -1)
    end
end

function TCP:recv(bytes)
    if self.ssl then
        return log.error("Please use ssl_recv method :)")
    end
    self.READ_IO = tcp_pop()
    local co = co_self()
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
        if not buf then
            return co_wakeup(co)
        end
        return co_wakeup(co, buf, len)
    end)
    self.timer = ti.timeout(self._timeout, function ( ... )
        tcp_push(self.READ_IO)
        tcp_stop(self.READ_IO)
        self.timer = nil
        self.read_co = nil
        self.READ_IO = nil
        return co_wakeup(co, nil, "read timeout")
    end)
    tcp_start(self.READ_IO, self.fd, EVENT_READ, self.read_co)
    return co_wait()
end

function TCP:ssl_recv(bytes)
    if not self.ssl then
        return log.error("Please use recv method :)")
    end
    local buf, len = tcp_sslread(self.ssl, bytes)
    if not buf then
        local co = co_self()
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
                    return co_wakeup(co, buf, len)
                end
                co_wait()
            end
        end)
        self.timer = ti.timeout(self._timeout, function ( ... )
            tcp_push(self.READ_IO)
            tcp_stop(self.READ_IO)
            self.timer = nil
            self.READ_IO = nil
            self.read_co = nil
            return co_wakeup(co, nil, "read timeout")
        end)
        tcp_start(self.READ_IO, self.fd, EVENT_READ, self.read_co)
        return co_wait()
    end
    return buf, len
end

function TCP:listen(ip, port, cb)
    self.listen_IO = tcp_pop()
    self.fd = tcp_new_tcp_fd(ip, port, SERVER)
    if not self.fd then
        return log.error("this IP and port Create A bind or listen method Faild! :) ")
    end
    self.co = co_new(function (fd, ipaddr)
        while 1 do
            if fd and ipaddr then
                co_spwan(cb, fd, ipaddr)
                fd, ipaddr = co_wait()
            end
        end
    end)
    return tcp.listen(self.listen_IO, self.fd, self.co)
end


function TCP:connect(ip, port)
    self.fd = tcp_new_tcp_fd(ip, port, CLIENT)
    if not self.fd then
        return log.error("Connect This IP or Port Faild! :) ")
    end
    self.CONNECT_IO = tcp_pop()
    local co = co_self()
    self.connect_co = co_new(function (connected)
        if self.timer then
            self.timer:stop()
            self.timer = nil
        end
        tcp_push(self.CONNECT_IO)
        tcp_stop(self.CONNECT_IO)
        self.CONNECT_IO = nil
        self.connect_co = nil
        if connected then
            return co_wakeup(co, true)
        end
        return co_wakeup(co)
    end)
    self.timer = ti.timeout(self._timeout, function ( ... )
        tcp_push(self.CONNECT_IO)
        tcp_stop(self.CONNECT_IO)
        self.timer = nil
        self.CONNECT_IO = nil
        self.connect_co = nil
        return co_wakeup(co, nil, 'connect timeot.')
    end)
    tcp_connect(self.CONNECT_IO, self.fd, self.connect_co)
    return co_wait()
end

function TCP:ssl_connect(ip, port)
    local ok, err = self:connect(ip, port)
    if not ok then
        return nil, "SSL connect error."
    end
    self.ssl_ctx, self.ssl = tcp.new_ssl(self.fd)
    if not self.ssl_ctx or not self.ssl then
        return log.error("Create a SSL Error! :) ")
    end
    self.CONNECT_IO = tcp_pop()
    local co = co_self()
    self.connect_co = co_new(function ()
        local EVENTS = EVENT_WRITE
        while 1 do
            local ok, EVENT = tcp_ssl_connect(self.ssl)
            if ok then
                if self.timer then
                    self.timer:stop()
                    self.timer = nil
                end
                tcp_push(self.CONNECT_IO)
                tcp_stop(self.CONNECT_IO)
                self.CONNECT_IO = nil
                self.connect_co = nil
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
    self.timer = ti.timeout(self._timeout, function ( ... )
        tcp_push(self.CONNECT_IO)
        tcp_stop(self.CONNECT_IO)
        self.timer = nil
        self.CONNECT_IO = nil
        self.connect_co = nil
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
        tcp_pop(self.READ_IO)
        self.READ_IO = nil
        self.read_co = nil
    end

    if self.SEND_IO then
        tcp_stop(self.SEND_IO)
        tcp_pop(self.SEND_IO)
        self.SEND_IO = nil
        self.send_co = nil
    end

    if self.CONNECT_IO then
        tcp_stop(self.CONNECT_IO)
        tcp_pop(self.CONNECT_IO)
        self.CONNECT_IO = nil
        self.connect_co = nil
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