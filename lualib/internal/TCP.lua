local ti = require "internal.Timer"
local class = require "class"

local tcp = core_tcp
local co_new = coroutine.create
local co_start = coroutine.resume
local co_wakeup = coroutine.resume
local co_suspend = coroutine.yield
local co_self = coroutine.running

local EVENT_READ  = 0x01
local EVENT_WRITE = 0x02

local SERVER = 0
local CLIENT = 1

local TCP = class("Socket")

function TCP:ctor(opt)
    self.fd = nil           -- 套接字文件描述符
    self.type = nil         -- client or server
    self.tcp = nil       -- 套接字对象
end

function TCP:set_status(status)
    self.status = status
    return self
end

function TCP:get_status()
    return self.status
end

-- 设置回调函数
function TCP:set_cb(action, cb)
    if not self[action] and action and type(cb) == "function" then
        self[action] = cb  -- 运行时不能替换回调
    end
    return self
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

function TCP:send(data)
    self.tcp = self.tcp or tcp:new()
    if not self.tcp then
        print("Create a Connect Socket Error! :) ")
        return
    end
    local co = co_self()
    local write_co = co_new(function (...)
        local send_data = data
        local send_len
        while 1 do
            send_len = self.tcp:write(send_data, #send_data)
            if not send_len or #send_data == send_len then
                self.tcp:stop()
                local ok, err = co_wakeup(co, send_len)
                if not ok then
                    print(err)
                end
                return
            end
            if #send_data > send_len then
                send_data = string.sub(send_data, send_len + 1, -1)
            end
            co_suspend()
        end
    end)
    self.tcp:start(self.fd, EVENT_WRITE, write_co)
    return co_suspend()
end

function TCP:recvall()
    self.tcp = self.tcp or tcp:new()
    if not self.tcp then
        print("Create a Connect Socket Error! :) ")
        return
    end
    local co = co_self()
    local timer, read_co
    read_co = co_new(function ( ... )
        local buf, len = self.tcp:readall()
        if timer then
            timer:close()
        end
        self.tcp:stop()
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
        self.tcp:stop()
        local ok, err = co_wakeup(co, nil, "read timeout")
        if not ok then
            print(err)
        end
    end))
    self.tcp:start(self.fd, EVENT_READ, read_co)
    return co_suspend()
end

function TCP:recv(bytes)
    self.tcp = self.tcp or tcp:new()
    if not self.tcp then
        print("Create a Connect Socket Error! :) ")
        return
    end
    local co = co_self()
    local timer, read_co
    read_co = co_new(function ( ... )
        local buf, len = self.tcp:read(bytes)
        if timer then
            timer:close()
        end
        self.tcp:stop()
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
        self.tcp:stop()
        local ok, err = co_wakeup(co, nil, "read timeout")
        if not ok then
            print(err)
        end
    end)
    self.tcp:start(self.fd, EVENT_READ, read_co)
    return co_suspend()
end

function TCP:listen(ip, port, co)
    if self.type == CLIENT then
        print("this socket object already used in client mode! :) ")
        return
    end
    self.type = SERVER
    self.tcp = self.tcp or tcp:new()
    if not self.tcp then
        print("Listen Socket Create Error! :) ")
        return
    end
    self.fd = self.tcp:new_tcp_fd(ip, port, SERVER)
    if not self.fd then
        print("this IP and port Create A bind or listen method Faild! :) ")
        self.tcp = nil
        return
    end
    return self.tcp:listen(self.fd, co)
end

function TCP:connect(domain, port)
    if self.type == SERVER then
        print("this socket object already used in server mode! :) ")
        return
    end
    self.tcp = self.tcp or tcp:new()
    if not self.tcp then
        print("Create a Connect Socket Error! :) ")
        return
    end
    self.fd = self.fd or self.tcp:new_tcp_fd(domain, port, CLIENT)
    if not self.fd then
        print("Connect This IP or Port Faild! :) ")
        self.tcp = nil
        return
    end
    self.type = CLIENT
    local co = co_self()
    local connect_co, timer
    connect_co = co_new(function (connected)
        self.tcp:stop()
        if timer then
            timer:close()
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
        self.tcp:stop()
        local ok, msg = co_wakeup(co, nil, 'connect timeot.')
        if not ok then
            print(msg)
        end
    end)
    self.tcp:connect(self.fd, connect_co)
    return co_suspend()
end

function TCP:close(...)
    if self.tcp then
        self.tcp:close()
        self.tcp = nil
    end
    self.fd = nil
    self.type = nil
end

return TCP