-- DOC: http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html


--[[

CONVENTIONS:

	* errors:
		* passing invalid arguments to function in this library will raise exception
		* all other errors will be returned in format: false, "error-text"
			* you can wrap function call into standard lua assert() to raise exception

]]

-- module table
local mqtt = {
	-- supported MQTT protocol versions
	protocol_version = {
		"3.1.1",
	},
	-- mqtt library version
	library_version = "1.4.2",
}


local require = require

-- required modules
local string = require("string")
local calss = require("class")
local tcp = require("internal.TCP")
local protocol = require("protocol.mqtt.protocol")
local protocol4 = require("protocol.mqtt.protocol4")


-- cache to locals
local setmetatable = setmetatable
local str_match = string.match
local str_format = string.format
local str_gsub = string.gsub
local tbl_remove = table.remove
local math_random = math.random
local math_randomseed = math.randomseed
local os_time = os.time
local packet_type = protocol.packet_type
local make_packet4 = protocol4.make_packet
local parse_packet4 = protocol4.parse_packet
local connack_return_code = protocol.connack_return_code
local next_packet_id = protocol.next_packet_id
local packet_id_required = protocol.packet_id_required
local packet_tostring = protocol.packet_tostring


-- Empty function to do nothing on MQTT client events
local empty_func = function() end

local client = class("mqtt")

function client:ctor(opt)
	self.host = opt.host
	self.port = opt.port
	self.sock = tcp:new()
	self.id = str_format("luamqtt-v%s-%07x", str_gsub(mqtt.library_version, "%.", "-"), math_random(1, 0xFFFFFFF))
	self.ssl = opt.ssl
	self.clean = opt.clean
	self.auth = opt.auth
	self.will = opt.will
	self.handlers = {
		connect = empty_func,
		message = empty_func,
		error = empty_func,
		close = empty_func,
	}
end

function client:on(event, func)
	assert(type(event) == "string", "监听事件必须是一个字符串")
	assert(type(func) == "function", "事件回调函数无效")
	assert(self.handlers[event], "不支持的事件:"..event)
	self.handlers[event] = func
end

function client:subscribe(...)
	local args = {
		type = packet_type.SUBSCRIBE,
		subscriptions = {...},
	}
	local ok, err = self:_send_packet(args)
	if not ok then
		err = "SUBSCRIBE send failed: "..err
		self.handlers.error(err)
		return false, err
	end
	ok, err = self:_wait_packet_exact{type=packet_type.SUBACK, packet_id=args.packet_id}
	if not ok then
		err = "SUBSCRIBE wait for SUBACK failed: "..err
		self.handlers.error(err)
		return false, err
	end
	return true
end

function client:unsubscribe(args, ...)
	local args = {
		type = packet_type.UNSUBSCRIBE,
		subscriptions = {...},
	}
	local ok, err = self:_send_packet(args)
	if not ok then
		err = "UNSUBSCRIBE send failed: "..err
		self.handlers.error(err)
		return false, err
	end
	ok, err = self:_wait_packet_exact{type=packet_type.UNSUBACK, packet_id=args.packet_id}
	if not ok then
		err = "UNSUBSCRIBE wait for UNSUBACK failed: "..err
		self.handlers.error(err)
		return false, err
	end
	return true
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
		err = "PUBLISH send failed: "..err
		self.handlers.error(err)
		return false, err
	end
	-- check we need to wait for acknowledge packets
	if acopy.qos == 1 then
		local puback, perr = self:_wait_packet_exact{type=packet_type.PUBACK, packet_id=acopy.packet_id}
		if not puback then
			perr = "PUBLISH wait for PUBACK failed: "..perr
			self.handlers.error(perr)
			return false, perr
		end
	elseif acopy.qos == 2 then
		-- DOC: 4.3.3 QoS 2: Exactly once delivery
		-- wait for PUBREC
		local ack, perr = self:_wait_packet_exact{type=packet_type.PUBREC, packet_id=acopy.packet_id}
		if not ack then
			perr = "PUBLISH wait for PUBREC failed: "..perr
			self.handlers.error(perr)
			return false, perr
		end
		-- send PUBREL
		ok, err = self:_send_packet{type=packet_type.PUBREL, packet_id=acopy.packet_id}
		if not ok then
			err = "PUBLISH send PUBREL failed: "..err
			self.handlers.error(err)
			return false, err
		end
		-- wait for PUBCOMP
		ack, perr = self:_wait_packet_exact{type=packet_type.PUBCOMP, packet_id=acopy.packet_id}
		if not ack then
			perr = "PUBLISH wait for PUBCOMP failed: "..perr
			self.handlers.error(perr)
			return false, perr
		end
	end
	return true
end

function client:acknowledge(msg)
	assert(type(msg) == "table", "expecting msg to be a table")
	if msg.qos == 0 then
		return true
	end
	assert(type(msg.packet_id) == "number", "expecting .packet_id to be a number")
	if msg.qos == 1 then
		local ok, err = self:_send_packet{type = packet_type.PUBACK, packet_id = msg.packet_id}
		if not ok then
			err = "acknowledge PUBACK send failed: "..err
			self.handlers.error(err)
			return false, err
		end
	elseif msg.qos == 2 then
		-- DOC: 4.3.3 QoS 2: Exactly once delivery
		-- send PUBREC
		local ok, err = self:_send_packet{type = packet_type.PUBREC, packet_id = msg.packet_id}
		if not ok then
			err = "acknowledge PUBREC send failed: "..err
			self.handlers.error(err)
			return false, err
		end
		-- wait for PUBREL
		local ack, perr = self:_wait_packet_exact{type=packet_type.PUBREL, packet_id=msg.packet_id}
		if not ack then
			perr = "acknowledge wait for PUBREL failed: "..perr
			self.handlers.error(perr)
			return false, perr
		end
		-- send PUBCOMP
		ok, err = self:_send_packet{type = packet_type.PUBCOMP, packet_id = msg.packet_id}
		if not ok then
			err = "acknowledge PUBCOMP send failed: "..err
			self.handlers.error(err)
			return false, err
		end
	end
	return true
end

function client:close_connection( ... )
	if self.connection then
		self.connector.shutdown(self.connection)
		self.connection = nil
		self.handlers.close()
	end
end

function client:disconnect( ... )
	if self.connection then
		self:_send_packet{type=packet_type.DISCONNECT}
		self:close_connection()
	end
end

function client:receive_iteration( ... )
	local packet, perr = self:_wait_packet_queue()
	if not packet then
		perr = "waiting for the next packet failed: "..perr
		self.handlers.error(perr)
		return false, perr
	end
	if packet.type == packet_type.PUBLISH then
		self.handlers.message(packet)
	-- elseif packet.type == packet_type.PUBACK then
		-- received acknowledge of some published packet
	else
		return false, "unexpected packet received: "..tostring(packet)
	end
	return true
end

function client:_send_packet(args)
	if not self.sock then
		return false, "network connection is not opened"
	end
	-- assign next packet id, if packet is requiring it
	self:_assign_packet_id(args)
	-- create binary packet
	local packet = make_packet4(args)
	local data = tostring(packet)
	local len = data:len()
	if len <= 0 then
		return false, "sending empty packet"
	end
	return self:send(data)
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
	-- send CONNECT packet
	local ok, err = self:_send_packet(args)
	if not ok then
		err = "send CONNECT failed: "..err
		self.handlers.error(err)
		return false, err
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

function client:connect( ... )
	-- open network connection to MQTT broker
	local ok, err = self:connection(self.host, self.port)
	if not ok then
		err = "open network connection failed: "..err
		self.handlers.error(err)
		return false, err
	end
	-- send CONNECT packet
	ok, err = self:_send_connect()
	if not ok then
		err = "sending CONNECT failed: "..err
		self.handlers.error(err)
		return false, err
	end
	-- wait for CONNACK with return code == 0
	local packet
	packet, err = self:_wait_packet()
	if not packet then
		err = "waiting for CONNACK failed: "..err
		self.handlers.error(err)
		return false, err
	end
	-- check received packet type and return code
	if packet.type ~= packet_type.CONNACK then
		err = "expecting CONNACK packet but received: "..tostring(packet.type)
		self.handlers.error(err)
		return false, err
	end
	if packet.rc ~= 0 then
		err = str_format("CONNECT failed with CONNACK rc=[%d] %s", packet.rc, tostring(connack_return_code[packet.rc]))
		self.handlers.error(err)
		return false, err
	end
	return true, packet
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
		-- if not match - queue it for future processing
		self.connection.queue[#self.connection.queue + 1] = packet
	end
end

function client:_wait_packet_queue( ... )
	if self.connection.queue[1] then
		-- remove already received packet from queue and return it
		return tbl_remove(self.connection.queue, 1)
	end
	return self:_wait_packet()
end

function client:_wait_packet( ... )
	if not self.sock then
		return false, "network connection is not opened"
	end
	local recv_func = function(size)
		return self:recv(size)
	end
	-- parse packet
	local packet, err = parse_packet4(recv_func)
	if not packet then
		return false, err
	end
	return packet
end

function client:__tostring()
	return str_format("mqtt.client{id=%q}", tostring(self.id))
end

function client:__gc()
	if self.connection then
		self:close_connection()
	end
end

function client:connect_and_run( ... )
	-- open network connection to MQTT broker and wait for CONNACK success
	local ok, err = self:connect()
	if not ok then
		err = "connection failed: "..err
		self.handlers.error(err)
		return false, err
	end
	-- fire connect event
	self.handlers.connect(err)
	-- start packet receiving loop
	ok, err = self:receive_loop()
	-- ensure network connection is closed
	self:close_connection()
	if not ok then
		return false, err
	end
	-- indicate graceful connection close
	return true
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
	if self.ssl then
		return self.sock:ssl_connect(ip, port)
	end
	return self.sock:connect(ip, port)
end

function client:puback( ... )
	return self:acknowledge(...)
end

function client:receive_loop( ... )
	while self.connection do
		self:receive_iteration()
	end
	return true
end

return client

-- vim: ts=4 sts=4 sw=4 noet ft=lua
