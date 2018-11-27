local Loop = require "internal.Loop"
local Timer = require "internal.Timer"
local tcp = require "internal.TCP"

local co = coroutine
local co_new = co.create
local co_start = co.resume
local co_wakeup = co.resume
local co_suspend = co.yield
local co_self = co.running

local class = require "class"

local httpd = class("httpd")

function httpd:ctor(opt)
	self.cos = {}
    self.IO = nil
end

function httpd:registery(co, fd, ipaddr)
	if type(co) == "thread" then
		self.cos[co] = {fd = fd, ipaddr = ipaddr}
	end
end

function httpd:unregistery(co)
	if type(co) == "thread" then
		self.cos[co] = nil
	end
end

function httpd:listen (ip, port)
	self.IO = tcp:new()
    self.accept_co = co_new(function (fd, ipaddr)
        while 1 do
        	if fd and ipaddr then
        		local co = co_new(function (fd, ipaddr)
                    local socket = tcp:new():set_fd(fd):timeout(3)
                    print(fd, ipaddr)
                    while 1 do
                        local buf, len = socket:recv(1024)
                        if not buf then
                            self:unregistery(co)
                            return socket:close()
                        end
                        socket:send("HTTP/1.1 200 OK\r\nServer: cf/0.1\r\nConnection: Keep-Alive\r\nContent-Type: text/html\r\n\r\n<html><body>Hello world!</body></html>")
                    end
                end)
        		self:registery(co, fd, ipaddr)
        		local ok, msg = co_start(co, fd, ipaddr)
        		if not ok then
        			self:unregistery(co)
        			print(msg)
        		end
        	end
            fd, ipaddr = co_suspend()
        end
    end)
    self.IO:listen(ip, port, self.accept_co)
	return Loop.run()
end

function httpd:start(ip, port)
	return self:listen(ip, port)
end

return httpd
