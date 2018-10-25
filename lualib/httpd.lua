local IO = require "internal.IO"
local callback = require "internal.callback"

local class = require "class"
local http = require "protocol.http"

local httpd = class("httpd")

function httpd:ctor(...)
    self.HTTP = {}
    self.CO_LIST = {}
end

-- 注册路由 --
function httpd:use(url, cb)
	-- body
end

function httpd:listen(ip, port)
    local HTTP = self.HTTP
    local CO_LIST = self.CO_LIST

    HTTP.IO = IO:listen(ip, port, co_new(function (...)
        local fd, client_ip = ...
        while 1 do
            while fd and client_ip do

                fd, client_ip  = co_suspend()
            end
            fd, client_ip  = co_suspend()
        end
    end))
--        while 1 do
--            local cb, co
--            local fd, ip  = co_suspend()
--            if fd and ip then
--                local cb = callback:new()
--                cb:registery("on_open", function (fd, ip)
--
--                end)
--                cb:registery("on_message", function (fd, data)
--
--                end)
--                cb:registery("on_open", function (fd)
--
--                end)
--                cb:registery("on_message", function (fd, error)
--
--                end)
--                local co = co_new(cb)
--            end
--        end
	return self
end

function httpd:start(ip, port)
    if ip ~= "localhost" or ip ~= "127.0.0.0" then
        ip = "0.0.0.0"
    end
    if math.tointeger(ip) == "float" or type(ip) ~= "number" or ip <= 0 then
        port = port or 8000
    end
	return self:listen(ip, port)
end

return httpd