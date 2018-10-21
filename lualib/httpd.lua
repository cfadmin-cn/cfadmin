local class = require "class"
local socket = core_socket
local ti = core_timer

local co_create = coroutine.create
local co_resume = coroutine.resume
local co_yield = coroutine.yield
local co_status = coroutine.status

local httpd = class("httpd")

function httpd:ctor(...)
	
end

-- 注册路由 --
function httpd:use(url, cb)
	-- body
end

-- 解析请求 --
function httpd:request_parser(data)
	-- body
end

local function listen_cb(fd, data)
	-- body
end

local function accept_cb(fd, addr, data)
	while 1 do
		print("接受到来自: [", fd, addr, "] 的链接")
		cb(fd, data)
		fd, addr = co_yield()
	end
end

function httpd:listen(port)
	return socket.listen(port, accept_cb)
end

function httpd:start(ip, port)
	print("正在监听IP地址为:", ip,"的", port, "端口")
	return self:listen(port)
end

return httpd