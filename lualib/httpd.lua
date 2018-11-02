require "internal.coroutine"
require "utils"

local class = require "class"
local http = require "protocol.http"
local IO = require "internal.IO"

local httpd = class("httpd")

function httpd:ctor(opt)
    self.IO = IO:new()
    self.CLIENTS = {}
end

-- 注册路由 --
function httpd:use(url, cb)
	-- body
end

function httpd:listen (ip, port)
    if not self.IO then
        print(self.IO)
        return 
    end
    return self.IO:listen(ip, port, self.CO)
end

function httpd:start(ip, port)
	return self:listen(ip, port)
end

return httpd
