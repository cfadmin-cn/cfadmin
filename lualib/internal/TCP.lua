local ti = require "internal.Timer"
local class = require "class"
local tcp = require "tcp"
local log = require "log"

local split = string.sub
local co_new = coroutine.create
local co_start = coroutine.resume
local co_wakeup = coroutine.resume
local co_suspend = coroutine.yield
local co_self = coroutine.running

local EVENT_READ  = 0x01
local EVENT_WRITE = 0x02

local SERVER = 0
local CLIENT = 1

local TCP = class("TCP")

function TCP:ctor(...)
    self.IO = tcp.new()
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
        log.error("Please use ssl_send method :)")
        return
    end
    if not self.IO then
        log.error("Can't find IO or Create IO Faild.")
        return
    end
    local len = tcp.write(self.fd, buf, #buf)
    if len == #buf then
        return
    end
    if len and len >= 0 then
        local co = co_self()
        local write_co = co_new(function ( ... )
            while 1 do
                local len = tcp.write(self.fd, buf, #buf)
                if not len or len == #buf then
                    tcp.stop(self.IO)
                    if not len then
                        log.error("send data faild")
                    end
                    local ok, msg = co_wakeup(co)
                    if not ok then
                        log.error(msg)
                    end
                    return
                end
                buf = split(buf, len + 1, -1)
                co_suspend()
            end
        end)
        tcp.start(self.IO, self.fd, EVENT_WRITE, write_co)
        return co_suspend()
    end
    -- 客户端关闭了, 连接不由write方法来处理
end

function TCP:ssl_send(buf)
    if not self.ssl then
        log.error("Please use send method :)")
        return
    end
    if not self.IO then
        log.error("Can't find IO or Create IO Faild.")
        return
    end
    local len = tcp.ssl_write(self.ssl, buf, #buf)
    if len == #buf then
        return
    end
    if len and len >= 0 then
        local ssl = self.ssl
        local co = co_self()
        local write_co = co_new(function ( ... )
            while 1 do
                local len = tcp.ssl_write(self.ssl, buf, #buf)
                if not len or len == #buf then
                    tcp.stop(self.IO)
                    if not len then
                        log.error("send data faild")
                    end
                    local ok, msg = co_wakeup(co)
                    if not ok then
                        log.error(msg)
                    end
                    return
                end
                buf = split(buf, len + 1, -1)
                co_suspend()
            end
        end)
        tcp.start(self.IO, self.fd, EVENT_WRITE, write_co)
        return co_suspend()
    end
    -- 客户端关闭了连接, 不由write方法来处理
end

function TCP:recv(bytes)
    if self.ssl then
        log.error("Please use ssl_recv method :)")
        return
    end
    if not self.IO then
        log.error("Create a READ Socket Error! :) ")
        return
    end
    local co = co_self()
    local timer, read_co
    read_co = co_new(function ( ... )
        local buf, len = tcp.read(self.fd, bytes)
        tcp.stop(self.IO)
        if timer then
            timer:stop()
        end
        if not buf then
            local ok, err = co_wakeup(co)
            if not ok then
                log.error(err)
            end
            return
        end
        local ok, err = co_wakeup(co, buf, len)
        if not ok then
            log.error(err)
        end
    end)
    timer = ti.timeout(self._timeout, function ( ... )
        tcp.stop(self.IO)
        local ok, err = co_wakeup(co, nil, "read timeout")
        if not ok then
            log.error(err)
        end
    end)
    tcp.start(self.IO, self.fd, EVENT_READ, read_co)
    return co_suspend()
end

function TCP:ssl_recv(bytes)
    if not self.ssl then
        log.error("Please use recv method :)")
        return
    end
    if not self.IO then
        log.error("Create a READ Socket Error! :) ")
        return
    end
    local co = co_self()
    local timer, read_co
    read_co = co_new(function ( ... )
        local buf, len = tcp.ssl_read(self.ssl, bytes)
        tcp.stop(self.IO)
        if timer then
            timer:stop()
        end
        if not buf then
            -- 客户端关闭了连接, 返回nil
            local ok, err = co_wakeup(co, buf, len)
            if not ok then
                log.error(err)
            end
            return
        end
        local ok, err = co_wakeup(co, buf, len)
        if not ok then
            log.error(err)
        end
    end)
    timer = ti.timeout(self._timeout, function ( ... )
        tcp.stop(self.IO)
        local ok, err = co_wakeup(co, nil, "read timeout")
        if not ok then
            log.error(err)
        end
    end)
    tcp.start(self.IO, self.fd, EVENT_READ, read_co)
    return co_suspend()
end

function TCP:listen(ip, port, co)
    if not self.IO then
        log.error("Listen Socket Create Error! :) ")
        return
    end
    self.fd = tcp.new_tcp_fd(ip, port, SERVER)
    if not self.fd then
        log.error("this IP and port Create A bind or listen method Faild! :) ")
        return
    end
    return tcp.listen(self.IO, self.fd, co)
end

function TCP:connect(domain, port)
    if not self.IO then
        log.error("Create a Connect Socket Error! :) ")
        return
    end
    self.fd = tcp.new_tcp_fd(domain, port, CLIENT)
    if not self.fd then
        log.error("Connect This IP or Port Faild! :) ")
        return
    end
    local co = co_self()
    local connect_co, timer
    connect_co = co_new(function (connected)
        tcp.stop(self.IO)
        if timer then
            timer:stop()
        end
        if connected then
            local ok, msg = co_wakeup(co, true)
            if not ok then
                log.error(msg)
            end
            return
        end
        local ok, msg = co_wakeup(co)
        if not ok then
            log.error(msg)
        end
    end)
    timer = ti.timeout(self._timeout, function ( ... )
        tcp.stop(self.IO)
        local ok, msg = co_wakeup(co, nil, 'connect timeot.')
        if not ok then
            log.error(msg)
        end
    end)
    tcp.connect(IO, self.fd, connect_co)
    return co_suspend()
end

function TCP:ssl_connect(domain, port)
    if not self.IO then
        log.error("Create a Connect Socket Error! :) ")
        return
    end
    self.fd = tcp.new_tcp_fd(domain, port, CLIENT)
    if not self.fd then
        log.error("Connect This IP or Port Faild! :) ")
        return
    end
    local co = co_self()
    local connect_co, timer
    connect_co = co_new(function (connected)
        tcp.stop(self.IO)
        if timer then
            timer:stop()
        end
        if connected == nil then
            local ok, msg = co_wakeup(co)
            if not ok then
                log.error(msg)
            end
            return
        end
        self.ssl = tcp.new_ssl(self.fd)
        if not self.ssl then
            log.error("Create a SSL Error! :) ")
            local ok, msg = co_wakeup(co)
            if not ok then
                log.error(msg)
            end
            return
        end
        while 1 do
            local ok, EVENT = tcp.ssl_connect(self.ssl)
            tcp.stop(self.IO)
            if ok then
                local ok, msg = co_wakeup(co, true)
                if not ok then
                    log.error(msg)
                end
                return
            end
            tcp.start(self.IO, self.fd, EVENT, connect_co)
            co_suspend()
        end
    end)
    timer = ti.timeout(self._timeout, function ( ... )
        tcp.stop(self.IO)
        local ok, msg = co_wakeup(co, nil, 'connect timeot.')
        if not ok then
            log.error(msg)
        end
    end)
    tcp.connect(self.IO, self.fd, connect_co)
    return co_suspend()
end

function TCP:close()
    if self.IO then
        tcp.stop(self.IO)
        self.IO = nil
    end
    if self.ssl then
        tcp.free_ssl(self.ssl)
        self.ssl = nil
    end
    if self.fd then
        tcp.close(self.fd)
        self.fd = nil
    end
end

return TCP
