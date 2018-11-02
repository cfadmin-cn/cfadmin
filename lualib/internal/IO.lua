require "internal.coroutine"
require "utils"

local class = require "class"
local io = core_socket

local EVENTS = {
	READ  = 0x01,
	WRITE = 0x02,
}


local IO = class("IO")

function IO:new(opt)
    self.io = io.new()
    self.co = nil
    self.LOOP = nil
end

function IO:listen(ip, port)
    if ip ~= "localhost" or ip ~= "127.0.0.0" then
        ip = "0.0.0.0"
    end
    if math.tointeger(port) == "float" or port <= 0 or port >= 65535 then
        port = port or 8080
    end

    self.LOOP = function (ip, addr)
        while 1 do
            if ip and addr then
                print(ip, addr)
            end
            ip, addr = co_suspend(co_self())
        end
    end
    self.co = co_new(self.LOOP)
    self.io:listen(ip, port, self.co)
end

function IO:close(fd)
    if fd and type(fd) == "number" then
        return self.io.close(fd)
    end
    return self.io:close()
end

return IO