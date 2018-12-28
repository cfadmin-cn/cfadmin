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
	self.udp = udp.new()
end

-- 超时时间
function UDP:timeout(Interval)
    if Interval and Interval > 0 then
        self._timeout = Interval
    end
    return self
end


function UDP:connect(ip, port)
	if not self.udp then
		return nil, "Can't Create a UDP socket."
	end
	self.fd = udp.connect(ip, port)
	if self.fd < 0 then
		return nil, "a peer of connect from udp port maybe closed."
	end
	return true
end

function UDP:recv(...)
	if self.udp then
		local co = co_self()
		self.read_co = co_new(function ( ... )
			local data, len = udp.recv(self.fd)
			if self.timer then
				self.timer:stop()
				self.timer = nil
			end
			udp.stop(self.udp)
			self.read_co = nil
			if data then
				return co_wakeup(co, data, len)
			end
			return co_wakeup(co, nil, '未知的udp错误')
		end)
		self.timer = ti.timeout(self._timeout, function ( ... )
			udp.stop(self.udp)
			self.read_co = nil
			self.timer = nil
			return co_wakeup(co, nil, 'udp_recv timout(超时)..')
		end)
		udp.start(self.udp, self.fd, self.read_co)
		return co_wait()
	end
end

function UDP:send(data)
	assert(not self.udp or self.fd or self.fd < 0, "UDP ERROR 参数不完整.")
	return udp.send(self.fd, data, #data)
end

function UDP:close()

	if self.udp then
		self.udp = nil
	end

	if self.fd then
		udp.close(self.fd)
		self.fd = nil
	end

	if self._timeout then
		self._timeout = nil
	end

	-- var_dump(self)
end

return UDP