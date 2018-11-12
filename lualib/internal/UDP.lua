local class = require "class"
local ti = require "internal.Timer"

local udp = core_udp
local co_new = coroutine.create
local co_start = coroutine.resume
local co_wakeup = coroutine.resume
local co_suspend = coroutine.yield
local co_self = coroutine.running

local UDP = class("UDP")

function UDP:ctor(opt)
	self.udp = nil
	self.ip = nil
	self.port = nil
end

function UDP:settimeout(Interval)
	if Interval and Interval > 0 then
		self._timeout = Interval
	end
end

function UDP:connect(ip, port)
	self.udp = udp:new()
	if not self.udp then
		return nil, "Can't Create a UDP socket."
	end
	local ok = self.udp:connect(ip, port)
	if not ok then
		return nil, "a peer of connect from udp port maybe closed."
	end
end

function UDP:recv(...)
	if self.udp then

	end
end

function UDP:send(data)
	if self.upd then
		self.write_co = co_new(function ( ... )
			
		end)
		self.udp:start(self.fd, write_co)
		return co_suspend()
	end
end

function UDP:close(...)
	if self.udp then
		self.udp:close()
		self.upd = nil
	end
end