local class = require "class"
local socket = core_socket

local co_new = coroutine.create
local co_start = coroutine.resume
local co_wakeup = coroutine.resume
local co_suspend = coroutine.yield
local co_self = coroutine.running

local EVENT_READ  = 0x01
local EVENT_WRITE = 0x02

local SERVER = 0
local CLIENT = 1

local Socket = class("Socket")

function Socket:ctor(opt)
    self.co = nil           -- 当前协程(相对来说)
    self.fd = nil           -- 套接字文件描述符
    self.type = nil         -- client or server
    self.socket = nil       -- 套接字对象
    self.accept_co = nil    -- accept 协程
    self.connect_co = nil   -- connect 协程
    self.status = "inited"
end

function Socket:set_status(status)
    self.status = status
end

-- 设置回调函数
function Socket:set_cb(action, cb)
    if not self[action] and action and type(cb) == "function" then
        self[action] = cb  -- 运行时不能替换回调
    end
end

-- 设置fd
function Socket:set_fd(fd)
    if not self.fd then
        self.fd = fd
    end
end

function Socket:write(data)
    if self.status ~= "connected" then
        return
    end
    if not self.socket and not self.fd then
        return
    end
    self.co = co_self()
    self.write_co = co_new(function (...)
        local send_data = data
        local send_len
        while 1 do
            send_len = self.socket:write(send_data)
            if not send_len or #send_data == send_len then
                local co = self.co
                self.co = nil
                self.socket:stop()
                self.write_co = nil
                local ok, err = co_wakeup(co, send_len)
                if not ok then
                    print(err)
                    self.socket:close()
                end
                return
            end
            if #send_data > send_len then
                send_data = string.sub(send_data, send_len + 1, -1)
            end
            co_suspend()
        end
    end)
    self.socket:start(self.fd, EVENT_WRITE, self.write_co)
    return co_suspend()
end

function Socket:readall()
    if self.status ~= "connected" then
        return
    end
    if not self.socket and not self.fd then
        return
    end
    self.co = co_self()
    self.read_co = co_new(function ( ... )
        local buf, len = self.socket:readall()
        local co = self.co
        self.co = nil
        self.read_co = nil
        self.socket:stop()
        if not buf then
            self.status = "closed"
            return co_wakeup(co)
        end
        return co_wakeup(co, buf, len)
    end)
    self.socket:start(self.fd, EVENT_READ, self.read_co)
    return co_suspend()
end

function Socket:read(bytes)
    if self.status ~= "connected" then
        return
    end
    if not self.socket and not self.fd then
        return
    end
    self.co = co_self()
    self.read_co = co_new(function ( ... )
        local buf, len = self.socket:read(bytes)
        if not buf then
            self:set_status("closed")
            local co = self.co
            self.co = nil
            self.read_co = nil
            self.socket:stop()
            local ok, err = co_wakeup(co)
            if not ok then
                print(err)
                self.socket.close()
            end
            return
        end
        if len > 0 then
            local co = self.co
            self.co = nil
            self.read_co = nil
            self.socket:stop()
            local ok, err = co_wakeup(co, buf, len)
            if not ok then
                print(err)
                self.socket.close()
            end
            return 
        end
        co_suspend()
    end)
    self.socket:start(self.fd, EVENT_READ, self.read_co)
    return co_suspend()
end

function Socket:listen(ip, port)
    if self.type == CLIENT then
        print("this socket object already used in client mode! :) ")
        return
    end
    self.type = SERVER
    self.socket = self.socket or socket:new()
    if not self.socket then
        print("Listen Socket Create Error! :) ")
        return
    end
    self.fd = self.fd or self.socket:new_tcp_fd(ip, port, SERVER)
    if not self.fd then
        print("this IP and port Create A bind or listen method Faild! :) ")
        self.socket = nil
        return
    end
    self.accept_co = co_new(function (fd, ipaddr)
        while 1 do
            print(fd, ipaddr)
            if fd and ipaddr then
                if self.accept and type(self.accept) == "function" then
                    local ok, msg = co_start(co_new(self.accept, fd, ipaddr))
                    if not ok then
                        print("Socket Accept error:", msg)
                        self.fd = nil
                        self.accept_co = nil
                        self.socket:close()
                        return
                    end
                else
                    print("Please Set Socket Accept Callback Method! :) ")
                    self.fd = nil
                    self.accept_co = nil
                    self.socket:close()
                end
            end
            fd, ipaddr = co_suspend()
        end
    end)
    return self.socket:listen(self.fd, self.accept_co)
end

function Socket:connect(domain, port)
    if self.type == SERVER then
        print("this socket object already used in server mode! :) ")
        return
    end
    self.socket = self.socket or socket:new()
    if not self.socket then
        print("Create a Connect Socket Error! :) ")
        return
    end
    self.fd = self.socket:new_tcp_fd(domain, port, CLIENT)
    if not self.fd then
        print("Connect This IP or Port Faild! :) ")
        self.socket = nil
        return
    end
    self.type = CLIENT
    self.co = co_self()
    self.connect_co = co_new(function (connected)
        self.socket:stop()
        self.connect_co = nil
        local co = self.co
        if connected then
            self:set_status("connected")
            return co_wakeup(co, true)
        end
        return co_wakeup(self.co)
    end)
    self.socket:connect(self.fd, self.connect_co)
    return co_suspend()
end

-- clear 用于清理后再使用
function Socket:clear(...)
    if self.socket then
        self.co = nil
        self.fd = nil
        self.type = nil
        self.accept_co = nil
        self.connect_co = nil
        self.socket:close()
    end
end

-- clear 用于关闭
function Socket:close(...)
    if self.socket then
        self.socket:close()
        self.socket = nil
    end
    self.co = nil
    self.fd = nil
    self.type = nil
    self.accept_co = nil
    self.connect_co = nil
end

return Socket