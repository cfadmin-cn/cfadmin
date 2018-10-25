local class = require "class"

local cb = class("callback")

-- 可以传入一个用户自定义参数
function cb:ctor(...)
    self.OPEN = nil
    self.MESSAGE = nil
    self.CLOSED = nil
    self.ERROR = nil
end

-- 客户端打开了一个连接
function cb:_on_open(fd, ipaddr)
    self.OPEN = true
    if self.open then
        return self:open(fd, ipaddr)
    end
    -- TODO
end

-- 客户端发送了数据
function cb:_on_message(fd, data)
    self.MESSAGE = true
    if self.on_message then
        return self:on_message(fd, data)
    end
    -- TODO
end

-- 客户端关闭连接 --
function cb:_on_close(fd)
    self.CLOSED = true
    if self.on_close then
        return self:on_close(fd)
    end
    -- TODO
end

-- 客户端错误 --
function cb:_on_error(fd, error)
    self.ERROR = true
    if self.on_error then
        return self:on_error(fd, error)
    end
    -- TODO
end

-- 注册回调 --
function cb:registery(action, func)
    if action == "on_open" and type(on_open == "function") then
        self.on_open = func
    end
    if on_message == "on_message" and type(on_message == "function") then
        self.on_message = func
    end
    if on_close == "on_close" and type(on_close == "function") then
        self.on_close = func
    end
    if on_error == "on_error" and type(on_error == "function") then
        self.on_error = func
    end
end

function cb:callback(fd, ip)
    print(self, fd, ip)
end

return cb