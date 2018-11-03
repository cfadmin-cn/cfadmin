require "internal.coroutine"
require "utils"

local class = require "class"
local socket = require "internal.socket"
local http = require "protocol.http"


local httpd = class("httpd")

function httpd:ctor(opt)
    self.IO = nil
end

-- 注册路由 --
function httpd:use(url, cb)

end

function httpd:listen (ip, port)
	self.socket = socket:new()
	self.socket:set_cb("accept", function(fd, ipaddr)
		LOG("INFO", fd, ipaddr)
		local s = socket:new()
		s:set_fd(fd)
		while 1 do
			local data, len
			while len > 0 do
				local str, len = s:read(2048)

			end
		end
	end)
	return self.socket:listen(ip, port)
end

function httpd:start(ip, port)
	return self:listen(ip, port)
end

return httpd
