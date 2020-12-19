-- wrapper around BitOp module

if _VERSION == "Lua 5.1" or _VERSION == "Lua 5.2" then
	return require("bit")
else
	return require("protocol.mqtt.bit53")
end

-- vim: ts=4 sts=4 sw=4 noet ft=lua
