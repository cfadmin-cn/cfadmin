local ti = require "internal.Timer"
local co = require "internal.Co"
local tcp = require "tcp"
local log = require "log"
-- require "utils"

local split = string.sub
local co_new = co.new
local co_wakeup = co.wakeup
local co_spwan = co.spwan
local co_wait = co.wait
local co_self = co.self

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
                        self.write_co = nil
                        return co_wakeup(co)
                    end
                    buf = split(buf, len + 1, -1)
                    co_wait()
                end
            end)
            tcp.start(self.IO, self.fd, EVENT_WRITE, self.write_co)
            return co_wait()
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
                    local len = tcp.ssl_write(self.ssl, buf, #buf)
                    if not len or len == #buf then
                        tcp.stop(self.IO)
                        -- 这里在发送数据的时候, 客户端可能已经关闭了链接
                        -- if not len then log.error("write error.")
                        self.write_co = nil
                        return co_wakeup(co)
                    end
                    buf = split(buf, len + 1, -1)
                    co_wait()
                end
            end)
            tcp.start(self.IO, self.fd, EVENT_WRITE, self.write_co)
            return co_wait()
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
        self.read_co = nil
        if not buf then
            return co_wakeup(co)
        end
        return co_wakeup(co, buf, len)
    end)
    self.timer = ti.timeout(self._timeout, function ( ... )
        tcp.stop(self.IO)
        self.timer = nil
        self.read_co = nil
        return co_wakeup(co, nil, "read timeout")
    end)
    tcp.start(self.IO, self.fd, EVENT_READ, self.read_co)
    return co_wait()
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
                self.read_co = nil
                return co_wakeup(co)
            end
            if buf and len then
                tcp.stop(self.IO)
                self.read_co = nil
                return co_wakeup(co, buf, len)
            end
            co_wait()
        end
    end)
    self.timer = ti.timeout(self._timeout, function ( ... )
        tcp.stop(self.IO)
        self.read_co = nil
        self.timer = nil
        return co_wakeup(co, nil, "read timeout")
    end)
    tcp.start(self.IO, self.fd, EVENT_READ, self.read_co)
    return co_wait()
end

function TCP:listen(ip, port, cb)
    if not self.IO then
        return log.error("Listen Socket Create Error! :) ")
    end
    self.fd = tcp.new_tcp_fd(ip, port, SERVER)
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
    return tcp.listen(self.IO, self.fd, self.co)
end


function TCP:connect(ip, port)
    if not self.IO then
        return log.error("Create a Connect Socket Error! :) ")
    end
    self.fd = tcp.new_tcp_fd(ip, port, CLIENT)
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
        self.connect_co = nil
        if connected then
            return co_wakeup(co, true)
        end
        return co_wakeup(co)
    end)
    self.timer = ti.timeout(self._timeout, function ( ... )
        tcp.stop(self.IO)
        self.timer = nil
        self.connect_co = nil
        return co_wakeup(co, nil, 'connect timeot.')
    end)
    tcp.connect(self.IO, self.fd, self.connect_co)
    return co_wait()
end

function TCP:ssl_connect(ip, port)
    if not self.IO then
        return log.error("Create a Connect Socket Error! :) ")
    end
    local _start = os.time() + os.clock()
    -- print("ssl_connect 开始连接")
    if not self:connect(ip, port) then
        -- print("ssl_connect 连接失败")
        return
    end
    -- local _end = os.time() + os.clock()
    -- print("ssl_connect 端口连接成功! 用时: ", _end - _start)
    self.ssl = tcp.new_ssl(self.fd)
    if not self.ssl then
        log.error("Create a SSL Error! :) ")
        return
    end
    -- print("ssl创建成功")
    local co = co_self()
    self.connect_co = co_new(function (connected)
        -- local _start = os.time() + os.clock()
        -- print("ssl 开始握手!")
        while 1 do
            local ok, EVENT = tcp.ssl_connect(self.ssl)
            if self.timer then
                self.timer:stop()
                self.timer = nil
            end
            if ok then
                -- print("ssl 开始握手完成! 用时: ", os.time() + os.clock() - _start)
                tcp.stop(self.IO)
                self.connect_co = nil
                return co_wakeup(co, true)
            end
            co_wait()
        end
    end)
    self.timer = ti.timeout(self._timeout, function ( ... )
        -- print("ssl_connect 超时")
        tcp.stop(self.IO)
        self.timer = nil
        self.connect_co = nil
        return co_wakeup(co, nil, 'ssl_connect timeot.')
    end)
    tcp.start(self.IO, self.fd, EVENT_WRITE, self.connect_co)
    return co_wait()
end

function TCP:close()

    if self.IO then
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

    setmetatable(self, nil)
    -- var_dump(self)
end

return TCP
