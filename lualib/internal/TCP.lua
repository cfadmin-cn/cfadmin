local ti = require "internal.Timer"
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

local class = require "class"


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
        return log.error("Please use ssl_send method :)")
    end
    if not self.IO then
        return log.error("Can't find IO or Create IO Faild.")
    end
    while 1 do
        local len = tcp.write(self.fd, buf, #buf)
        if not len or len == #buf then
            return
        end
        if len == 0 then
            local co = co_self()
            self.write_co = co_new(function ( ... )
                while 1 do
                    local len = tcp.write(self.fd, buf, #buf)
                    if not len or len == #buf then
                        tcp.stop(self.IO)
                        -- 这里在发送数据的时候, 客户端可能已经关闭了链接
                        -- if not len then log.error("write error.")
                        local ok, msg = co_wakeup(co)
                        if not ok then
                            log.error(msg)
                        end
                        self.write_co = nil
                        return
                    end
                    buf = split(buf, len + 1, -1)
                    co_suspend()
                end
            end)
            tcp.start(self.IO, self.fd, EVENT_WRITE, self.write_co)
            return co_suspend()
        end
        buf = split(buf, len + 1, -1)
    end
    -- 客户端关闭了, 连接不由write方法来处理
end

function TCP:ssl_send(buf)
    if not self.ssl then
        return log.error("Please use send method :)")
    end
    if not self.IO then
        return log.error("Can't find IO or Create IO Faild.")
    end
    while 1 do
        local len = tcp.ssl_write(self.ssl, buf, #buf)
        if not len or len == #buf then
            return
        end
        if len == 0 then
            local co = co_self()
            self.write_co = co_new(function ( ... )
                while 1 do
                    local len = tcp.write(self.ssl, buf, #buf)
                    if not len or len == #buf then
                        tcp.stop(self.IO)
                        -- 这里在发送数据的时候, 客户端可能已经关闭了链接
                        -- if not len then log.error("write error.")
                        local ok, msg = co_wakeup(co)
                        if not ok then
                            log.error(msg)
                        end
                        self.write_co = nil
                        return
                    end
                    buf = split(buf, len + 1, -1)
                    co_suspend()
                end
            end)
            tcp.start(self.IO, self.fd, EVENT_WRITE, self.write_co)
            return co_suspend()
        end
        buf = split(buf, len + 1, -1)
    end
    -- 客户端关闭了连接, 不由write方法来处理
end

function TCP:recv(bytes)
    if self.ssl then
        return log.error("Please use ssl_recv method :)")
    end
    if not self.IO then
        return log.error("Create a READ Socket Error! :) ")
    end
    local co = co_self()
    self.read_co = co_new(function ( ... )
        local buf, len = tcp.read(self.fd, bytes)
        tcp.stop(self.IO)
        if self.timer then
            self.timer:stop()
            self.timer = nil
        end
        if not buf then
            local ok, err = co_wakeup(co)
            if not ok then
                log.error(err)
            end
            self.read_co = nil
            return
        end
        local ok, err = co_wakeup(co, buf, len)
        if not ok then
            log.error(err)
        end
        self.read_co = nil
    end)
    self.timer = ti.timeout(self._timeout, function ( ... )
        tcp.stop(self.IO)
        local ok, err = co_wakeup(co, nil, "read timeout")
        if not ok then
            log.error(err)
        end
        self.read_co = nil
    end)
    tcp.start(self.IO, self.fd, EVENT_READ, self.read_co)
    return co_suspend()
end

function TCP:ssl_recv(bytes)
    if not self.ssl then
        return log.error("Please use recv method :)")
    end
    if not self.IO then
        return log.error("Create a READ Socket Error! :) ")
    end
    local co = co_self()
    self.read_co = co_new(function ( ... )
        while 1 do
            local buf, len = tcp.ssl_read(self.ssl, bytes)
            if self.timer then
                self.timer:stop()
                self.timer = nil
            end
            if not len and not buf then
                tcp.stop(self.IO)
                -- 客户端关闭了连接, 返回nil
                local ok, err = co_wakeup(co)
                if not ok then
                    log.error(err)
                end
                self.read_co = nil
                return
            end
            if buf and len then
                tcp.stop(self.IO)
                local ok, err = co_wakeup(co, buf, len)
                if not ok then
                    log.error(err)
                end
                self.read_co = nil
                return
            end
            co_suspend()
        end
    end)
    self.timer = ti.timeout(self._timeout, function ( ... )
        tcp.stop(self.IO)
        local ok, err = co_wakeup(co, nil, "read timeout")
        if not ok then
            log.error(err)
        end
        self.read_co = nil
    end)
    tcp.start(self.IO, self.fd, EVENT_READ, self.read_co)
    return co_suspend()
end

function TCP:listen(ip, port, co)
    if not self.IO then
        return log.error("Listen Socket Create Error! :) ")
    end
    self.fd = tcp.new_tcp_fd(ip, port, SERVER)
    if not self.fd then
        return log.error("this IP and port Create A bind or listen method Faild! :) ")
    end
    return tcp.listen(self.IO, self.fd, co)
end

function TCP:connect(domain, port)
    if not self.IO then
        return log.error("Create a Connect Socket Error! :) ")
    end
    self.fd = tcp.new_tcp_fd(domain, port, CLIENT)
    if not self.fd then
        return log.error("Connect This IP or Port Faild! :) ")
    end
    local co = co_self()
    self.connect_co = co_new(function (connected)
        tcp.stop(self.IO)
        if self.timer then
            self.timer:stop()
            self.timer = nil
        end
        if connected then
            local ok, msg = co_wakeup(co, true)
            if not ok then
                log.error(msg)
            end
            self.connect_co = nil
            return
        end
        local ok, msg = co_wakeup(co)
        if not ok then
            log.error(msg)
        end
    end)
    self.timer = ti.timeout(self._timeout, function ( ... )
        tcp.stop(self.IO)
        local ok, msg = co_wakeup(co, nil, 'connect timeot.')
        if not ok then
            log.error(msg)
        end
        self.connect_co = nil
    end)
    tcp.connect(self.IO, self.fd, self.connect_co)
    return co_suspend()
end

function TCP:ssl_connect(domain, port)
    if not self.IO then
        return log.error("Create a Connect Socket Error! :) ")
    end
    self.fd = tcp.new_tcp_fd(domain, port, CLIENT)
    if not self.fd then
        return log.error("Connect This IP or Port Faild! :) ")
    end
    local co = co_self()
    self.connect_co = co_new(function (connected)
        tcp.stop(self.IO)
        if self.timer then
            self.timer:stop()
            self.timer = nil
        end
        if connected == nil then
            local ok, msg = co_wakeup(co)
            if not ok then
                log.error(msg)
            end
            self.connect_co = nil
            return
        end
        self.ssl = tcp.new_ssl(self.fd)
        if not self.ssl then
            log.error("Create a SSL Error! :) ")
            local ok, msg = co_wakeup(co)
            if not ok then
                log.error(msg)
            end
            self.connect_co = nil
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
                self.connect_co = nil
                return
            end
            tcp.start(self.IO, self.fd, EVENT, self.connect_co)
            co_suspend()
        end
    end)
    self.timer = ti.timeout(self._timeout, function ( ... )
        tcp.stop(self.IO)
        local ok, msg = co_wakeup(co, nil, 'connect timeot.')
        if not ok then
            log.error(msg)
        end
        self.connect_co = nil
    end)
    tcp.connect(self.IO, self.fd, self.connect_co)
    return co_suspend()
end

function TCP:close()

    if self.IO then
        self.IO = nil
    end

    if self.read_co then
        self.read_co = nil
    end

    if self.write_co then
        self.write_co = nil
    end

    if self.connect_co then
        self.connect_co = nil
    end

    if self.timer then
        self.timer = nil
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
