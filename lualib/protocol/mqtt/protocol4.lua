--[[

Here is a MQTT v3.1.1 protocol implementation

MQTT v3.1.1 documentation (DOC):
	http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html

]]

-- module table
local protocol4 = {}


-- required modules
local bit = require("protocol.mqtt.bit")
local protocol = require("protocol.mqtt.protocol")


-- cache to locals
local assert = assert
local tostring = tostring
local setmetatable = setmetatable
local error = error
local str_sub = string.sub
local str_byte = string.byte
local bor = bit.bor
local band = bit.band
local lshift = bit.lshift
local rshift = bit.rshift
local make_uint8 = protocol.make_uint8
local make_uint16 = protocol.make_uint16
local make_string = protocol.make_string
local make_header = protocol.make_header
local check_qos = protocol.check_qos
local check_packet_id = protocol.check_packet_id
local combine = protocol.combine
local parse_var_length = protocol.parse_var_length
local packet_type = protocol.packet_type
local packet_mt = protocol.packet_mt


-- CONNACK return code strings
protocol4.connack_return_code = {
	[0] = "Connection Accepted",
	[1] = "Connection Refused, unacceptable protocol version",
	[2] = "Connection Refused, identifier rejected",
	[3] = "Connection Refused, Server unavailable",
	[4] = "Connection Refused, bad user name or password",
	[5] = "Connection Refused, not authorized",
}

-- Create Connect Flags data, DOC: 3.1.2.3 Connect Flags
local function make_connect_flags(args)
	local byte = 0 -- bit 0 should be zero
	-- DOC: 3.1.2.4 Clean Session
	if args.clean ~= nil then
		assert(type(args.clean) == "boolean", "expecting .clean to be a boolean")
		if args.clean then
			byte = bor(byte, lshift(1, 1))
		end
	end
	-- DOC: 3.1.2.5 Will Flag
	if args.will ~= nil then
		-- check required args are presented
		assert(type(args.will) == "table", "expecting .will to be a table")
		assert(type(args.will.payload) == "string", "expecting .will.payload to be a string")
		assert(type(args.will.topic) == "string", "expecting .will.topic to be a string")
		assert(type(args.will.qos) == "number", "expecting .will.qos to be a number")
		assert(check_qos(args.will.qos), "expecting .will.qos to be a valid QoS value")
		assert(type(args.will.retain) == "boolean", "expecting .will.retain to be a boolean")
		-- will flag should be set to 1
		byte = bor(byte, lshift(1, 2))
		-- DOC: 3.1.2.6 Will QoS
		byte = bor(byte, lshift(args.will.qos, 3))
		-- DOC: 3.1.2.7 Will Retain
		if args.will.retain then
			byte = bor(byte, lshift(1, 5))
		end
	end
	-- DOC: 3.1.2.8 User Name Flag
	if args.username ~= nil then
		assert(type(args.username) == "string", "expecting .username to be a string")
		byte = bor(byte, lshift(1, 7))
	end
	-- DOC: 3.1.2.9 Password Flag
	if args.password ~= nil then
		assert(type(args.password) == "string", "expecting .password to be a string")
		assert(args.username, "the .username is required to set .password")
		byte = bor(byte, lshift(1, 6))
	end
	return make_uint8(byte)
end

-- Create CONNECT packet, DOC: 3.1 CONNECT – Client requests a connection to a Server
local function make_packet_connect(args)
	-- check args
	assert(type(args.id) == "string", "expecting .id to be a string with MQTT client id")
	-- DOC: 3.1.2.10 Keep Alive
	local keep_alive_ival = 0
	if args.keep_alive then
		assert(type(args.keep_alive) == "number")
		keep_alive_ival = args.keep_alive
	end
	-- DOC: 3.1.2 Variable header
	local variable_header = combine(
		make_string("MQTT"), 				-- DOC: 3.1.2.1 Protocol Name
		make_uint8(4), 						-- DOC: 3.1.2.2 Protocol Level (4 is for MQTT v3.1.1)
		make_connect_flags(args), 			-- DOC: 3.1.2.3 Connect Flags
		make_uint16(keep_alive_ival) 		-- DOC: 3.1.2.10 Keep Alive
	)
	-- DOC: 3.1.3 Payload
	-- DOC: 3.1.3.1 Client Identifier
	local payload = combine(
		make_string(args.id)
	)
	if args.will then
		-- DOC: 3.1.3.2 Will Topic
		payload:append(make_string(args.will.topic))
		-- DOC: 3.1.3.3 Will Message
		payload:append(make_string(args.will.payload))
	end
	if args.username then
		-- DOC: 3.1.3.4 User Name
		payload:append(make_string(args.username))
		if args.password then
			-- DOC: 3.1.3.5 Password
			payload:append(make_string(args.password))
		end
	end
	-- DOC: 3.1.1 Fixed header
	local header = make_header(packet_type.CONNECT, 0, variable_header:len() + payload:len())
	return combine(header, variable_header, payload)
end

-- Create PUBLISH packet, DOC: 3.3 PUBLISH – Publish message
local function make_packet_publish(args)
	-- check args
	assert(type(args.topic) == "string", "expecting .topic to be a string")
	if args.payload ~= nil then
		assert(type(args.payload) == "string", "expecting .payload to be a string")
	end
	assert(type(args.qos) == "number", "expecting .qos to be a number")
	assert(check_qos(args.qos), "expecting .qos to be a valid QoS value")
	assert(type(args.retain) == "boolean", "expecting .retain to be a boolean")
	assert(type(args.dup) == "boolean", "expecting .dup to be a boolean")
	-- DOC: 3.3.1 Fixed header
	local flags = 0
	-- 3.3.1.3 RETAIN
	if args.retain then
		flags = bor(flags, 0x1)
	end
	-- DOC: 3.3.1.2 QoS
	flags = bor(flags, lshift(args.qos, 1))
	-- DOC: 3.3.1.1 DUP
	if args.dup then
		flags = bor(flags, lshift(1, 3))
	end
	-- DOC: 3.3.2  Variable header
	local variable_header = combine(
		make_string(args.topic)
	)
	-- DOC: 3.3.2.2 Packet Identifier
	if args.qos > 0 then
		assert(type(args.packet_id) == "number", "expecting .packet_id to be a number")
		assert(check_packet_id(args.packet_id), "expecting .packet_id to be a valid Packet Identifier")
		variable_header:append(make_uint16(args.packet_id))
	end
	local payload
	if args.payload then
		payload = args.payload
	else
		payload = ""
	end
	-- DOC: 3.3.1 Fixed header
	local header = make_header(packet_type.PUBLISH, flags, variable_header:len() + payload:len())
	return combine(header, variable_header, payload)
end

-- Create PUBACK packet, DOC: 3.4 PUBACK – Publish acknowledgement
local function make_packet_puback(args)
	-- check args
	assert(type(args.packet_id) == "number", "expecting .packet_id to be a number")
	assert(check_packet_id(args.packet_id), "expecting .packet_id to be a valid Packet Identifier")
	-- DOC: 3.4.1 Fixed header
	local header = make_header(packet_type.PUBACK, 0, 2)
	-- DOC: 3.4.2 Variable header
	local variable_header = make_uint16(args.packet_id)
	return combine(header, variable_header)
end

-- Create PUBREC packet, DOC: 3.5 PUBREC – Publish received (QoS 2 publish received, part 1)
local function make_packet_pubrec(args)
	-- check args
	assert(type(args.packet_id) == "number", "expecting .packet_id to be a number")
	assert(check_packet_id(args.packet_id), "expecting .packet_id to be a valid Packet Identifier")
	-- DOC: 3.5.1 Fixed header
	local header = make_header(packet_type.PUBREC, 0, 2)
	-- DOC: 3.5.2 Variable header
	local variable_header = make_uint16(args.packet_id)
	return combine(header, variable_header)
end

-- Create PUBREL packet, DOC: 3.6 PUBREL – Publish release (QoS 2 publish received, part 2)
local function make_packet_pubrel(args)
	-- check args
	assert(type(args.packet_id) == "number", "expecting .packet_id to be a number")
	assert(check_packet_id(args.packet_id), "expecting .packet_id to be a valid Packet Identifier")
	-- DOC: 3.6.1 Fixed header
	local header = make_header(packet_type.PUBREL, 0x2, 2) -- flags are 0x2 == 0010 bits (fixed value)
	-- DOC: 3.6.2 Variable header
	local variable_header = make_uint16(args.packet_id)
	return combine(header, variable_header)
end

-- Create PUBCOMP packet, DOC: 3.7 PUBCOMP – Publish complete (QoS 2 publish received, part 3)
local function make_packet_pubcomp(args)
	-- check args
	assert(type(args.packet_id) == "number", "expecting .packet_id to be a number")
	assert(check_packet_id(args.packet_id), "expecting .packet_id to be a valid Packet Identifier")
	-- DOC: 3.7.1 Fixed header
	local header = make_header(packet_type.PUBCOMP, 0, 2)
	-- DOC: 3.7.2 Variable header
	local variable_header = make_uint16(args.packet_id)
	return combine(header, variable_header)
end

-- Create SUBSCRIBE packet, DOC: 3.8 SUBSCRIBE - Subscribe to topics
local function make_packet_subscribe(args)
	-- check args
	assert(type(args.packet_id) == "number", "expecting .packet_id to be a number")
	assert(check_packet_id(args.packet_id), "expecting .packet_id to be a valid Packet Identifier")
	assert(type(args.subscriptions) == "table", "expecting .subscriptions to be a table")
	assert(#args.subscriptions > 0, "expecting .subscriptions to be a non-empty array")
	-- DOC: 3.8.2 Variable header
	local variable_header = combine(
		make_uint16(args.packet_id)
	)
	-- DOC: 3.8.3 Payload
	local payload = combine()
	for i, subscription in ipairs(args.subscriptions) do
		assert(type(subscription) == "table", "expecting .subscriptions["..i.."] to be a table")
		assert(type(subscription.topic) == "string", "expecting .subscriptions["..i.."].topic to be a string")
		if subscription.qos ~= nil then
			assert(type(subscription.qos) == "number", "expecting .subscriptions["..i.."].qos to be a number")
			assert(check_qos(subscription.qos), "expecting .subscriptions["..i.."].qos to be a valid QoS value")
		end
		payload:append(make_string(subscription.topic))
		payload:append(make_uint8(subscription.qos or 0))
	end
	-- DOC: 3.8.1 Fixed header
	local header = make_header(packet_type.SUBSCRIBE, 2, variable_header:len() + payload:len()) -- NOTE: fixed flags value 0x2
	return combine(header, variable_header, payload)
end

-- Create UNSUBSCRIBE packet, DOC: 3.10 UNSUBSCRIBE – Unsubscribe from topics
local function make_packet_unsubscribe(args)
	-- check args
	assert(type(args.packet_id) == "number", "expecting .packet_id to be a number")
	assert(check_packet_id(args.packet_id), "expecting .packet_id to be a valid Packet Identifier")
	assert(type(args.subscriptions) == "table", "expecting .subscriptions to be a table")
	assert(#args.subscriptions > 0, "expecting .subscriptions to be a non-empty array")
	-- DOC: 3.10.2 Variable header
	local variable_header = combine(
		make_uint16(args.packet_id)
	)
	-- DOC: 3.10.3 Payload
	local payload = combine()
	for i, subscription in ipairs(args.subscriptions) do
		assert(type(subscription) == "string", "expecting .subscriptions["..i.."] to be a string")
		payload:append(make_string(subscription))
	end
	-- DOC: 3.10.1 Fixed header
	local header = make_header(packet_type.UNSUBSCRIBE, 2, variable_header:len() + payload:len()) -- NOTE: fixed flags value 0x2
	return combine(header, variable_header, payload)
end

-- Create packet of given {type: number} in args
function protocol4.make_packet(args)
	assert(type(args) == "table", "expecting args to be a table")
	assert(type(args.type) == "number", "expecting .type number in args")
	local ptype = args.type
	if ptype == packet_type.CONNECT then
		return make_packet_connect(args)
	elseif ptype == packet_type.PUBLISH then
		return make_packet_publish(args)
	elseif ptype == packet_type.PUBACK then
		return make_packet_puback(args)
	elseif ptype == packet_type.PUBREC then
		return make_packet_pubrec(args)
	elseif ptype == packet_type.PUBREL then
		return make_packet_pubrel(args)
	elseif ptype == packet_type.PUBCOMP then
		return make_packet_pubcomp(args)
	elseif ptype == packet_type.SUBSCRIBE then
		return make_packet_subscribe(args)
	elseif ptype == packet_type.UNSUBSCRIBE then
		return make_packet_unsubscribe(args)
	elseif ptype == packet_type.PINGREQ then
		-- DOC: 3.12 PINGREQ – PING request
		return combine("\192\000") -- 192 == 0xC0, type == 12, flags == 0
	elseif ptype == packet_type.DISCONNECT then
		-- DOC: 3.14 DISCONNECT – Disconnect notification
		return combine("\224\000") -- 224 == 0xD0, type == 14, flags == 0
	else
		error("unexpected packet type to make: "..ptype)
	end
end

-- Parse packet using given read_func
-- Returns packet on success or false and error message on failure
function protocol4.parse_packet(read_func)
	assert(type(read_func) == "function", "expecting read_func to be a function")
	-- parse fixed header
	local byte1, byte2, err, len, data, rc
	byte1, err = read_func(1)
	if not byte1 then
		return false, err
	end
	byte1 = str_byte(byte1, 1, 1)
	local ptype = rshift(byte1, 4)
	local flags = band(byte1, 0xF)
	len, err = parse_var_length(read_func)
	if not len then
		return false, err
	end
	if len > 0 then
		data, err = read_func(len)
	else
		data = ""
	end
	if not data then
		return false, err
	end
	local data_len = data:len()
	-- parse readed data according type in fixed header
	if ptype == packet_type.CONNACK then
		-- DOC: 3.2 CONNACK – Acknowledge connection request
		if data_len ~= 2 then
			return false, "expecting data of length 2 bytes"
		end
		byte1, byte2 = str_byte(data, 1, 2)
		local sp = (band(byte1, 0x1) ~= 0)
		return setmetatable({type=ptype, sp=sp, rc=byte2}, packet_mt)
	elseif ptype == packet_type.PUBLISH then
		-- DOC: 3.3 PUBLISH – Publish message
		-- DOC: 3.3.1.1 DUP
		local dup = (band(flags, 0x8) ~= 0)
		-- DOC: 3.3.1.2 QoS
		local qos = band(rshift(flags, 1), 0x3)
		-- DOC: 3.3.1.3 RETAIN
		local retain = (band(flags, 0x1) ~= 0)
		-- DOC: 3.3.2.1 Topic Name
		if data_len < 2 then
			return false, "expecting data of length at least 2 bytes"
		end
		byte1, byte2 = str_byte(data, 1, 2)
		local topic_len = bor(lshift(byte1, 8), byte2)
		if data_len < 2 + topic_len then
			return false, "malformed PUBLISH packet: not enough data to parse topic"
		end
		local topic = str_sub(data, 3, 3 + topic_len - 1)
		-- DOC: 3.3.2.2 Packet Identifier
		local packet_id, packet_id_len = nil, 0
		if qos > 0 then
			-- DOC: 3.3.2.2 Packet Identifier
			if data_len < 2 + topic_len + 2 then
				return false, "malformed PUBLISH packet: not enough data to parse packet_id"
			end
			byte1, byte2 = str_byte(data, 3 + topic_len, 3 + topic_len + 1)
			packet_id = bor(lshift(byte1, 8), byte2)
			packet_id_len = 2
		end
		-- DOC: 3.3.3 Payload
		local payload
		if data_len > 2 + topic_len + packet_id_len then
			payload = str_sub(data, 2 + topic_len + packet_id_len + 1)
		end
		return setmetatable({type=ptype, dup=dup, qos=qos, retain=retain, packet_id=packet_id, topic=topic, payload=payload}, packet_mt)
	elseif ptype == packet_type.PUBACK then
		-- DOC: 3.4 PUBACK – Publish acknowledgement
		if data_len ~= 2 then
			return false, "expecting data of length 2 bytes"
		end
		-- DOC: 3.4.2 Variable header
		byte1, byte2 = str_byte(data, 1, 2)
		return setmetatable({type=ptype, packet_id=bor(lshift(byte1, 8), byte2)}, packet_mt)
	elseif ptype == packet_type.PUBREC then
		-- DOC: 3.5 PUBREC – Publish received (QoS 2 publish received, part 1)
		if data_len ~= 2 then
			return false, "expecting data of length 2 bytes"
		end
		-- DOC: 3.5.2 Variable header
		byte1, byte2 = str_byte(data, 1, 2)
		return setmetatable({type=ptype, packet_id=bor(lshift(byte1, 8), byte2)}, packet_mt)
	elseif ptype == packet_type.PUBREL then
		-- DOC: 3.6 PUBREL – Publish release (QoS 2 publish received, part 2)
		if data_len ~= 2 then
			return false, "expecting data of length 2 bytes"
		end
		-- also flags should be checked to equals 2 by the server
		-- DOC: 3.6.2 Variable header
		byte1, byte2 = str_byte(data, 1, 2)
		return setmetatable({type=ptype, packet_id=bor(lshift(byte1, 8), byte2)}, packet_mt)
	elseif ptype == packet_type.PUBCOMP then
		-- 3.7 PUBCOMP – Publish complete (QoS 2 publish received, part 3)
		if data_len ~= 2 then
			return false, "expecting data of length 2 bytes"
		end
		-- DOC: 3.7.2 Variable header
		byte1, byte2 = str_byte(data, 1, 2)
		return setmetatable({type=ptype, packet_id=bor(lshift(byte1, 8), byte2)}, packet_mt)
	elseif ptype == packet_type.SUBACK then
		-- DOC: 3.9 SUBACK – Subscribe acknowledgement
		if data_len ~= 3 then
			return false, "expecting data of length 3 bytes"
		end
		-- DOC: 3.9.2 Variable header
		-- DOC: 3.9.3 Payload
		byte1, byte2, rc = str_byte(data, 1, 3)
		return setmetatable({type=ptype, packet_id=bor(lshift(byte1, 8), byte2), rc=rc, failure=(rc == 0x80)}, packet_mt)
	elseif ptype == packet_type.UNSUBACK then
		-- DOC: 3.11 UNSUBACK – Unsubscribe acknowledgement
		if data_len ~= 2 then
			return false, "expecting data of length 2 bytes"
		end
		-- DOC: 3.11.2 Variable header
		byte1, byte2 = str_byte(data, 1, 2)
		return setmetatable({type=ptype, packet_id=bor(lshift(byte1, 8), byte2)}, packet_mt)
	elseif ptype == packet_type.PINGRESP then
		-- DOC: 3.13 PINGRESP – PING response
		if data_len ~= 0 then
			return false, "expecting data of length 0 bytes"
		end
		return setmetatable({type=ptype}, packet_mt)
	else
		return false, "unexpected packet type received: "..tostring(ptype)
	end
end

-- export module table
return protocol4

-- vim: ts=4 sts=4 sw=4 noet ft=lua
