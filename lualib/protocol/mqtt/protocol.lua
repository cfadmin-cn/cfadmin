--[[

Here is a generic implementation of MQTT protocols of all supported versions.

MQTT v3.1.1 documentation (DOCv3.1.1):
	http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html

MQTT v5.0 documentation (DOCv5.0):
	http://docs.oasis-open.org/mqtt/mqtt/v5.0/mqtt-v5.0.html

CONVENTIONS:

	* read_func - function to read data from some stream-like object (like network connection).
		We are calling it with one argument: number of bytes to read.
		Use currying/closures to pass other arguments to this function.
		This function should return string of given size on success.
		On failure it should return false/nil and an error message.

]]

-- module table
local protocol = {}


-- required modules
local bit = require("protocol.mqtt.bit")
local tools = require("protocol.mqtt.tools")

-- cache to locals
local assert = assert
local tostring = tostring
local setmetatable = setmetatable
local error = error
local tbl_concat = table.concat
local str_char = string.char
local str_byte = string.byte
local str_format = string.format
local bor = bit.bor
local band = bit.band
local lshift = bit.lshift
local rshift = bit.rshift
local div = tools.div
local unpack = unpack or table.unpack


-- Create uint8 value data
function protocol.make_uint8(val)
	if val < 0 or val > 0xFF then
		error("value is out of range to encode as uint8: "..tostring(val))
	end
	return str_char(val)
end

-- Create uint16 value data
local function make_uint16(val)
	if val < 0 or val > 0xFFFF then
		error("value is out of range to encode as uint16: "..tostring(val))
	end
	return str_char(rshift(val, 8), band(val, 0xFF))
end
protocol.make_uint16 = make_uint16

-- Create UTF-8 string data
-- DOCv3.1.1: 1.5.3 UTF-8 encoded strings
-- DOCv5.0: 1.5.4 UTF-8 Encoded String
function protocol.make_string(str)
	return make_uint16(str:len())..str
end

-- Returns bytes of given integer value encoded as variable length field
-- DOCv3.1.1: 2.2.3 Remaining Length
-- DOCv5.0: 2.1.4 Remaining Length
local function make_var_length(len)
	if len < 0 or len > 268435455 then
		error("value is invalid for encoding as variable length field: "..tostring(len))
	end
	local bytes = {}
	local i = 1
	repeat
		local byte = len % 128
		len = div(len, 128)
		if len > 0 then
			byte = bor(byte, 128)
		end
		bytes[i] = byte
		i = i + 1
	until len <= 0
	return unpack(bytes)
end
protocol.make_var_length = make_var_length

-- Create fixed packet header data
-- DOCv3.1.1: 2.2 Fixed header
-- DOCv5.0: 2.1.1 Fixed Header
function protocol.make_header(ptype, flags, len)
	local byte1 = bor(lshift(ptype, 4), band(flags, 0x0F))
	return str_char(byte1, make_var_length(len))
end

-- Returns true if given value is a valid QoS
function protocol.check_qos(val)
	return (val == 0) or (val == 1) or (val == 2)
end

-- Returns true if given value is a valid Packet Identifier
-- DOCv3.1.1: 2.3.1 Packet Identifier
-- DOCv5.0: 2.2.1 Packet Identifier
function protocol.check_packet_id(val)
	return val >= 1 and val <= 0xFFFF
end

-- Returns the next Packet Identifier value relative to given current value
-- DOCv3.1.1: 2.3.1 Packet Identifier
-- DOCv5.0: 2.2.1 Packet Identifier
function protocol.next_packet_id(curr)
	if not curr then
		return 1
	end
	assert(type(curr) == "number", "expecting curr to be a number")
	assert(curr >= 1, "expecting curr to be >= 1")
	curr = curr + 1
	if curr > 0xFFFF then
		curr = 1
	end
	return curr
end

-- MQTT protocol fixed header packet types
-- DOCv3.1.1: 2.2.1 MQTT Control Packet type
-- DOCv5.0: 2.1.2 MQTT Control Packet type
local packet_type = {
	CONNECT = 			1,
	CONNACK = 			2,
	PUBLISH = 			3,
	PUBACK = 			4,
	PUBREC = 			5,
	PUBREL = 			6,
	PUBCOMP = 			7,
	SUBSCRIBE = 		8,
	SUBACK = 			9,
	UNSUBSCRIBE = 		10,
	UNSUBACK = 			11,
	PINGREQ = 			12,
	PINGRESP = 			13,
	DISCONNECT = 		14,
	AUTH =				15, -- NOTE: new in MQTTv5.0
	[1] = 				"CONNECT",
	[2] = 				"CONNACK",
	[3] = 				"PUBLISH",
	[4] = 				"PUBACK",
	[5] = 				"PUBREC",
	[6] = 				"PUBREL",
	[7] = 				"PUBCOMP",
	[8] = 				"SUBSCRIBE",
	[9] = 				"SUBACK",
	[10] = 				"UNSUBSCRIBE",
	[11] = 				"UNSUBACK",
	[12] = 				"PINGREQ",
	[13] = 				"PINGRESP",
	[14] = 				"DISCONNECT",
	[15] =				"AUTH", -- NOTE: new in MQTTv5.0
}
protocol.packet_type = packet_type

-- Packet types requiring packet identifier field
-- DOCv3.1.1: 2.3.1 Packet Identifier
-- DOCv5.0: 2.2.1 Packet Identifier
local packets_requiring_packet_id = {
	[packet_type.PUBACK] 		= true,
	[packet_type.PUBREC] 		= true,
	[packet_type.PUBREL] 		= true,
	[packet_type.PUBCOMP] 		= true,
	[packet_type.SUBSCRIBE] 	= true,
	[packet_type.SUBACK] 		= true,
	[packet_type.UNSUBSCRIBE] 	= true,
	[packet_type.UNSUBACK] 		= true,
}

-- Returns true if Packet Identifier field are required for given packet
function protocol.packet_id_required(args)
	assert(type(args) == "table", "expecting args to be a table")
	assert(type(args.type) == "number", "expecting .type to be a number")
	local ptype = args.type
	if ptype == packet_type.PUBLISH and args.qos and args.qos > 0 then
		return true
	end
	return packets_requiring_packet_id[ptype]
end

-- Metatable for combined data packet, should looks like a string
local combined_packet_mt = {
	-- Convert combined data packet to string
	__tostring = function(self)
		local strings = {}
		for i, part in ipairs(self) do
			strings[i] = tostring(part)
		end
		return tbl_concat(strings)
	end,

	-- Get length of combined data packet
	len = function(self)
		local len = 0
		for _, part in ipairs(self) do
			len = len + part:len()
		end
		return len
	end,

	-- Append part to the end of combined data packet
	append = function(self, part)
		self[#self + 1] = part
	end
}

-- Make combined_packet_mt table works like a class
combined_packet_mt.__index = function(_, key)
	return combined_packet_mt[key]
end

-- Combine several data parts into one
function protocol.combine(...)
	return setmetatable({...}, combined_packet_mt)
end

-- Max variable length integer value
local max_mult = 128 * 128 * 128

-- Returns variable length field value calling read_func function read data, DOC: 2.2.3 Remaining Length
function protocol.parse_var_length(read_func)
	assert(type(read_func) == "function", "expecting read_func to be a function")
	local mult = 1
	local val = 0
	repeat
		local byte, err = read_func(1)
		if not byte then
			return false, err
		end
		byte = str_byte(byte, 1, 1)
		val = val + band(byte, 127) * mult
		if mult > max_mult then
			return false, "malformed variable length field data"
		end
		mult = mult * 128
	until band(byte, 128) == 0
	return val
end

-- Convert packet to string representation
local function packet_tostring(packet)
	local res = {}
	for k, v in pairs(packet) do
		res[#res + 1] = str_format("%s=%s", k, tostring(v))
	end
	return str_format("%s{%s}", tostring(packet_type[packet.type]), tbl_concat(res, ", "))
end
protocol.packet_tostring = packet_tostring

-- Parsed packet metatable
protocol.packet_mt = {
	__tostring = packet_tostring,
}

-- export module table
return protocol

-- vim: ts=4 sts=4 sw=4 noet ft=lua
