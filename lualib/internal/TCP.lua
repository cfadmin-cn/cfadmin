local ti = require "internal.Timer"
local tcp = require "tcp"

local class = require "class"

local co_new = coroutine.create
local co_start = coroutine.resume
local co_wakeup = coroutine.resume
local co_suspend = coroutine.yield
local co_self = coroutine.running

local insert = table.insert
local remove = table.remove

local EVENT_READ  = 0x01
local EVENT_WRITE = 0x02

local SERVER = 0
local CLIENT = 1

local TCP = class("Socket")

function TCP:ctor(opt)
    -- 
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
        print("Please use ssl_send method :)")
        return
    end
    if not self.queue then
        self.queue = {buf}
        self.IO_WRITE = tcp:new()
        local write_co = co_new(function ( ... )
            while 1 do
                if #self.queue < 1 then
                    self.queue = nil
                    return self.IO_WRITE:stop()
                end
                local data = remove(self.queue)
                while 1 do
                    local send_len = self.IO_WRITE:write(data, #data)
                    if send_len == #data then
                        break
                    end
                    if #data > send_len then
                        data = string.sub(data, send_len + 1, -1)
                    end
                    co_suspend()
                end
            end
        end)
        return self.IO_WRITE:start(self.fd, EVENT_WRITE, write_co)
    end
    return insert(self.queue, 1, buf)
end

function TCP:ssl_send(buf)
    if not self.ssl then
        print("Please use send method :)")
        return
    end
    if not self.queue  then
        self.queue = {buf}
        local write_co = co_new(function ( ... )
            while 1 do
                if #self.queue < 1 then
                    return self.IO_WRITE:stop()
                end
                local data = remove(self.queue)
                while 1 do
                    local send_len = self.IO_WRITE:ssl_write(self.ssl, data, #data)
                    if send_len == #data then
                        break
                    end
                    if #data > send_len then
                        data = string.sub(data, send_len + 1, -1)
                    end
                    co_suspend()
                end
            end
        end)
        return self.IO_WRITE:start(self.fd, EVENT_WRITE, write_co)
    end
    return insert(self.queue, 1, buf)
end

function TCP:ssl_recv(bytes)
    if not self.ssl then
        print("Please use recv method :)")
        return
    end
    self.IO_READ = self.IO_READ or tcp:new()
    if not self.IO_READ then
        print("Create a READ Socket Error! :) ")
        return
    end
    local co = co_self()
    local timer, read_co
    read_co = co_new(function ( ... )
        local buf, len = self.IO_READ:ssl_read(self.ssl, bytes)
        if timer then
            timer:stop()
        end
        self.IO_READ:stop()
        if not buf then
            local ok, err = co_wakeup(co, buf, len)
            if not ok then
                print(err)
            end
            return
        end
        local ok, err = co_wakeup(co, buf, len)
        if not ok then
            print(err)
        end
    end)
    timer = ti.timeout(self._timeout, co_new(function ( ... )
        self.IO_READ:stop()
        local ok, err = co_wakeup(co, nil, "read timeout")
        if not ok then
            print(err)
        end
    end))
    self.IO_READ:start(self.fd, EVENT_READ, read_co)
    return co_suspend()
end

function TCP:recv(bytes)
    if self.ssl then
        print("Please use ssl_recv method :)")
        return
    end
    self.IO_READ = self.IO_READ or tcp:new()
    if not self.IO_READ then
        print("Create a READ Socket Error! :) ")
        return
    end
    local co = co_self()
    local timer, read_co
    read_co = co_new(function ( ... )
        local buf, len = self.IO_READ:read(bytes)
        if timer then
            timer:stop()
        end
        self.IO_READ:stop()
        if not buf then
            local ok, err = co_wakeup(co)
            if not ok then
                print(err)
            end
            return
        end
        local ok, err = co_wakeup(co, buf, len)
        if not ok then
            print(err)
        end
    end)
    timer = ti.timeout(self._timeout, function ( ... )
        self.IO_READ:stop()
        local ok, err = co_wakeup(co, nil, "read timeout")
        if not ok then
            print(err)
        end
    end)
    self.IO_READ:start(self.fd, EVENT_READ, read_co)
    return co_suspend()
end

function TCP:listen(ip, port, co)
    self.IO_LISTEN = self.IO_LISTEN or tcp:new()
    if not self.IO_LISTEN then
        print("Listen Socket Create Error! :) ")
        return
    end
    self.fd = self.IO_LISTEN:new_tcp_fd(ip, port, SERVER)
    if not self.fd then
        print("this IP and port Create A bind or listen method Faild! :) ")
        self.IO_LISTEN = nil
        return
    end
    return self.IO_LISTEN:listen(self.fd, co)
end

function TCP:connect(domain, port)
    self.IO_WRITE = self.IO_WRITE or tcp:new()
    if not self.IO_WRITE then
        print("Create a Connect Socket Error! :) ")
        return
    end
    self.fd = self.fd or self.IO_WRITE:new_tcp_fd(domain, port, CLIENT)
    if not self.fd then
        print("Connect This IP or Port Faild! :) ")
        self.IO_WRITE = nil
        return
    end
    local co = co_self()
    local connect_co, timer
    connect_co = co_new(function (connected)
        self.IO_WRITE:stop()
        if timer then
            timer:stop()
        end
        if connected then
            local ok, msg = co_wakeup(co, true)
            if not ok then
                print(msg)
            end
            return
        end
        local ok, msg = co_wakeup(co)
        if not ok then
            print(msg)
        end
    end)
    timer = ti.timeout(self._timeout, function ( ... )
        self.IO_WRITE:stop()
        local ok, msg = co_wakeup(co, nil, 'connect timeot.')
        if not ok then
            print(msg)
        end
    end)
    self.IO_WRITE:connect(self.fd, connect_co)
    return co_suspend()
end

function TCP:ssl_connect(domain, port)
    self.IO_WRITE = self.IO_WRITE or tcp:new()
    if not self.IO_WRITE then
        print("Create a Connect Socket Error! :) ")
        return
    end
    self.fd = self.fd or self.IO_WRITE:new_tcp_fd(domain, port, CLIENT)
    if not self.fd then
        print("Connect This IP or Port Faild! :) ")
        self.IO_WRITE = nil
        return
    end
    local co = co_self()
    local connect_co, timer
    connect_co = co_new(function (connected)
        self.IO_WRITE:stop()
        if connected == nil then
            if timer then
                timer:stop()
            end
            local ok, msg = co_wakeup(co)
            if not ok then
                print(msg)
            end
            return
        end
        self.ssl = tcp.new_ssl(self.fd)
        if not self.ssl then
            print("Create a SSL Error! :) ")
            local ok, msg = co_wakeup(co)
            if not ok then
                print(msg)
            end
            return
        end
        while 1 do
            local ok, EVENT = self.IO_WRITE.ssl_connect(self.ssl)
            self.IO_WRITE:stop()
            if ok then
                local ok, msg = co_wakeup(co, true)
                if not ok then
                    print(msg)
                end
                return
            end
            self.IO_WRITE:start(self.fd, EVENT, connect_co)
            co_suspend()
        end
    end)
    timer = ti.timeout(self._timeout, function ( ... )
        self.IO_WRITE:stop()
        local ok, msg = co_wakeup(co, nil, 'connect timeot.')
        if not ok then
            print(msg)
        end
    end)
    self.IO_WRITE:connect(self.fd, connect_co)
    return co_suspend()
end

function TCP:close()
    if self.IO_WRITE then
        self.IO_WRITE:stop()
        self.IO_WRITE = nil
    end
    if self.IO_READ then
        self.IO_READ:stop()
        self.IO_WRITE = nil
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