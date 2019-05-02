-- DOC: http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html


local protocol_version = '3.1.1'

local library_version = "1.4.2"

local require = require
local string = require "string"
local calss = require "class"
local tcp = require "internal.TCP"
local Co = require "internal.Co"
local log = require "logging"
local protocol = require "protocol.mqtt.protocol"
local protocol4 = require "protocol.mqtt.protocol4"
local co = require "internal.Co"
local Timer = require "internal.Timer"
local packet_type = protocol.packet_type
local next_packet_id = protocol.next_packet_id
local packet_id_required = protocol.packet_id_required
local packet_tostring = protocol.packet_tostring
local make_packet4 = protocol4.make_packet
local parse_packet4 = protocol4.parse_packet
local connack_return_code = protocol4.connack_return_code

local Log = log:new({ dump = true, path = 'protocol-MQTT'})

-- cache to locals
local type = type
local pairs = pairs
local assert = assert
local tostring = tostring
local setmetatable = setmetatable
local os_time = os.time
local str_match = string.match
local str_format = string.format
local str_gsub = string.gsub
local tbl_remove = table.remove
local co_spwan = Co.spwan
-- Empty function to do nothing on MQTT client events
local empty_func = function() end

local client = class("mqtt")

function client:ctor(opt)
	self.host = opt.host
	self.port = opt.port
	self.sock = tcp:new():timeout(15) -- 超时时间将会再tcp连接后被清除
	self.id = opt.id
	self.ssl = opt.ssl
	self.clean = opt.clean
	self.auth = opt.auth
	self.will = opt.will
	self.keep_alive = opt.keep_alive or 300
	self.queue = {}
end

function client:subscribe(opt, func)
	local args = { type = packet_type.SUBSCRIBE, subscriptions = {opt} }
	self.handle = func
	self:_send_packet(args)
	local ok, err = self:_wait_packet_exact{type=packet_type.SUBACK, packet_id=args.packet_id}
	if not ok then
		return false, 'SUBSCRIBE wait for SUBACK failed'
	end
	co_spwan(function ( ... )
		local co_current = Co.self()
		local time = os_time()
		local timer = Timer.at(self.keep_alive, function ( ... )
			if os_time() >= time + self.keep_alive then
				return co.wakeup(co_current)
			end
			return self:ping()
		end)
		while 1 do
			local packet, perr = self:_wait_packet_queue()
			if not packet then
				if timer then
					timer:stop()
					timer = nil
				end
				local ok, err = pcall(self.handle, nil)
				if not ok then
					Log:ERROR(err)
				end
				return false, 'waiting for the next packet failed'
			end
			time = os_time()
			if packet.type == packet_type.PUBLISH then
				local ok, err = pcall(self.handle, packet)
				if not ok then
					Log:ERROR(err)
				end
				self:acknowledge(packet)
			elseif packet.type == packet_type.PUBACK then
				self:acknowledge(packet)
			-- elseif packet.type == packet_type.PINGRESP then
			-- 	-- pass
			-- else
			-- 	return false, "unexpected packet received: "..tostring(packet)
			end
		end
	end)
	return true
end

function client:acknowledge(msg)
	assert(type(msg) == "table", "expecting msg to be a table")
	if msg.qos == 0 then
		return true
	end
	assert(type(msg.packet_id) == "number", "expecting .packet_id to be a number")
	if msg.qos == 1 then
		return self:_send_packet{type = packet_type.PUBACK, packet_id = msg.packet_id}
	elseif msg.qos == 2 then
		-- DOC: 4.3.3 QoS 2: Exactly once delivery
		-- send PUBREC
		self:_send_packet{type = packet_type.PUBREC, packet_id = msg.packet_id}
		-- wait for PUBREL
		local ack, perr = self:_wait_packet_exact{type=packet_type.PUBREL, packet_id=msg.packet_id}
		if not ack then
			return false, 'acknowledge wait for PUBREL failed'
		end
		-- send PUBCOMP
		return self:_send_packet{type = packet_type.PUBCOMP, packet_id = msg.packet_id}
	end
end

function client:ping(opt)
	return self:send(tostring(make_packet4({type = packet_type.PINGREQ})))
end

function client:publish(args)
	assert(type(args) == "table", "expecting args to be a table")
	-- copy args
	local acopy = {
		type = packet_type.PUBLISH,
	}
	for k, v in pairs(args) do
		acopy[k] = v
	end
	assert(type(acopy.topic) == "string", "expecting .topic to be a string")
	acopy.qos = acopy.qos or 0
	acopy.retain = acopy.retain or false
	if acopy.payload ~= nil then
		assert(type(acopy.payload) == "string", "expecting .payload to be a string")
	end
	acopy.dup = false
	local ok, err = self:_send_packet(acopy)
	if not ok then
		return false, 'PUBLISH send failed'
	end
	-- check we need to wait for acknowledge packets
	if acopy.qos == 1 then
		local puback, perr = self:_wait_packet_exact{type=packet_type.PUBACK, packet_id=acopy.packet_id}
		if not puback then
			return false, 'PUBLISH wait for PUBACK failed'
		end
	elseif acopy.qos == 2 then
		-- DOC: 4.3.3 QoS 2: Exactly once delivery
		-- wait for PUBREC
		local ack, perr = self:_wait_packet_exact{type=packet_type.PUBREC, packet_id=acopy.packet_id}
		if not ack then
			return false, 'PUBLISH wait for PUBREC failed'
		end
		-- send PUBREL
		ok, err = self:_send_packet{type=packet_type.PUBREL, packet_id=acopy.packet_id}
		if not ok then
			return false, 'PUBLISH send PUBREL failed'
		end
		-- wait for PUBCOMP
		ack, perr = self:_wait_packet_exact{type=packet_type.PUBCOMP, packet_id=acopy.packet_id}
		if not ack then
			return false, 'PUBLISH wait for PUBCOMP failed'
		end
	end
	return true
end

function client:_assign_packet_id(args)
	if not args.packet_id then
		if packet_id_required(args) then
			self._last_packet_id = next_packet_id(self._last_packet_id)
			args.packet_id = self._last_packet_id
		end
	end
end

function client:_send_packet(args)
	if not self.sock then
		return false, "network connection is not opened"
	end
	self:_assign_packet_id(args)
	return self:send(tostring(make_packet4(args)))
end

function client:_send_connect( ... )
	if not self.sock then
		return false, "network connection is not opened"
	end
	-- construct CONNECT packet table
	local args = {
		type = packet_type.CONNECT,
		id = self.id,
		clean = self.clean,
		keep_alive = self.keep_alive
	}
	if self.auth then
		args.username = self.auth.username
		args.password = self.auth.password
	end
	if self.will then
		args.will = {}
		for k, v in pairs(self.will) do
			args.will[k] = v
		end
		args.will.qos = args.will.qos or 0
		args.will.retain = args.will.retain or false
	end
	return self:_send_packet(args)
end

function client:connect()
	local ok, err = self:connection(self.host, self.port)
	if not ok then
		return false, "open network connection failed."
	end
	-- send CONNECT packet
	local ok = self:_send_connect()
	if not ok then
		return false, "send connection packet faild."
	end
	-- wait for CONNACK with return code == 0
	local packet, err = self:_wait_packet()
	if not packet then
		return false, "waiting for CONNACK failed: "..tostring(err)
	end
	-- check received packet type and return code
	if packet.type ~= packet_type.CONNACK then
		return false, "expecting CONNACK packet but received: "
	end
	if packet.rc ~= 0 then
		return false, str_format("CONNECT failed with CONNACK rc=[%d] %s", packet.rc, tostring(connack_return_code[packet.rc]))
	end
	return true, packet
end

function client:_wait_packet( ... )
	if not self.sock then
		return false, "network connection is not opened"
	end
	local recv_func = function(size)
		local size = size
		local buf = ''
		while 1 do
			local data, len = self:recv(size)
			if not data then
				return
			end
			buf = buf..data
			if len == size then
				return buf
			end
			size = size - len
		end
	end
	-- parse packet
	local packet, err = parse_packet4(recv_func)
	if not packet then
		return false, err
	end
	return packet
end

function client:_wait_packet_exact(args)
	while true do
		-- receive next packet
		local packet, err = self:_wait_packet()
		if not packet then
			return false, err
		end
		-- check this packet match given args
		local match = true
		for k, v in pairs(args) do
			if packet[k] ~= v then
				match = false
				break
			end
		end
		if match then
			return packet
		end
		self.queue[#self.queue+1] = packet
	end
end

function client:_wait_packet_queue()
	if #self.queue > 0 then
		return tbl_remove(self.queue, 1)
	end
	return self:_wait_packet()
end

function client:send(buf)
	if self.ssl then
		return self.sock:ssl_send(buf)
	end
	return self.sock:send(buf)
end

function client:recv(size)
	if self.ssl then
		return self.sock:ssl_recv(size)
	end
	return self.sock:recv(size)
end

function client:connection(ip, port)
	local ok, err
	if self.ssl then
		ok, err = self.sock:ssl_connect(ip, port)
		self.sock._timeout = nil
		return ok, err
	end
	ok, err = self.sock:connect(ip, port)
	self.sock._timeout = nil
	return ok, err
end

function client:close( ... )
	self.sock:close()
	self.sock = nil
end

return client
