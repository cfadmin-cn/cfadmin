local ti = require "internal.Timer"
local co = require "internal.Co"
local log = require "log"
local udp = require "udp"
local class = require "class"

local co_new = co.new
local co_self = co.self
local co_wakeup = co.wakeup
local co_wait = co.wait

local UDP = class("UDP")

function UDP:ctor(opt)
	self.udp = nil
	self.ip = nil
	self.port = nil
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
	return true
end

function UDP:recv(...)
	if self.udp then
		local co = co_self()
		self.read_co = co_new(function ( ... )
			local data, len = self.udp:recv()
			self.udp:stop()
			self.read_co = nil
			if data then
				return co_wakeup(co, data, len)
			end
			return co_wakeup(co)
		end)
		self.udp:start(self.read_co)
		return co_wait()
	end
end

function UDP:send(data)
	if self.udp then
		return self.udp:send(data, #data)
	end
end

function UDP:close()
	if self.udp then
		self.udp:close()
		self.udp = nil
	end
	-- var_dump(self)
end

return UDP