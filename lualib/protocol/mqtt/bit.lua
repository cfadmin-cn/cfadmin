-- wrapper around BitOp module

if _VERSION == "Lua 5.1" or _VERSION == "Lua 5.2" or type(jit) == "table" then
	return require("bit")
else
	return require("mqtt.bit53")
end

-- vim: ts=4 sts=4 sw=4 noet ft=lua
