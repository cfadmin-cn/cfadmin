local tcp = require "internal.TCP"
local log = require "log"

local table = table
local concat = table.concat

local string = string
local find = string.find
local byte = string.byte
local sub = string.sub

local redis = {}
local command = {}
local meta = {
	__index = command,
	__name = "Redis",
	-- DO NOT close channel in __gc
}

---------- redis response
local redcmd = {}

local function read_response(sock)
	local result = ""
	while 1 do
		local data = sock:recv(1)
		result = result .. data
		if find(result, "\r\n") then
			break
		end
	end
	local firstchar = byte(result)
	return redcmd[firstchar](sock, sub(result, 2))
end

redcmd[36] = function(sock, data) -- '$'
	local bytes = tonumber(data)
	if bytes < 0 then
		return true, nil
	end
	local firstline = sock:recv(bytes + 2)
	return true, sub(firstline, 1, -3)
end

redcmd[43] = function(sock, data) -- '+'
	return true, data
end

redcmd[45] = function(sock, data) -- '-'
	return false, data
end

redcmd[58] = function(sock, data) -- ':'
	-- todo: return string later
	return true, tonumber(data)
end

redcmd[42] = function(sock, data)	-- '*'
	local n = tonumber(data)
	if n < 0 then
		return true, nil
	end
	local bulk = {}
	local noerr = true
	for i = 1,n do
		local ok, v = read_response(sock)
		if not ok then
			noerr = false
		end
		bulk[i] = v
	end
	return noerr, bulk
end

-------------------

function command:disconnect()
	self[1]:close()
	self[1] = nil
	setmetatable(self, nil)
end

function command:close()
	self[1]:close()
	self[1] = nil
	setmetatable(self, nil)
end

-- msg could be any type of value

local function make_cache(f)
	return setmetatable({}, {
		__mode = "kv",
		__index = f,
	})
end

local header_cache = make_cache(function(t,k)
		local s = "\r\n$" .. k .. "\r\n"
		t[k] = s
		return s
	end)

local command_cache = make_cache(function(t,cmd)
		local s = "\r\n$"..#cmd.."\r\n"..cmd:upper()
		t[cmd] = s
		return s
	end)

local count_cache = make_cache(function(t,k)
		local s = "*" .. k
		t[k] = s
		return s
	end)

local function compose_message(cmd, msg)
	local t = type(msg)
	local lines = {}

	if t == "table" then
		lines[1] = count_cache[#msg+1]
		lines[2] = command_cache[cmd]
		local idx = 3
		for _,v in ipairs(msg) do
			v= tostring(v)
			lines[idx] = header_cache[#v]
			lines[idx+1] = v
			idx = idx + 2
		end
		lines[idx] = "\r\n"
	else
		msg = tostring(msg)
		lines[1] = "*2"
		lines[2] = command_cache[cmd]
		lines[3] = header_cache[#msg]
		lines[4] = msg
		lines[5] = "\r\n"
	end

	return concat(lines)
end

local function redis_login(sock, auth, db)
	if auth then
		sock:send(compose_message("AUTH", auth))
		local ok, err = read_response(sock)
		if not ok then
			return nil, err
		end
	end
	if db then
		sock:send(compose_message("SELECT", db))
		local ok, err = read_response(sock)
		if not ok then
			return nil, err
		end
	end
	return true
end

function redis.connect(db_conf)
	local sock = tcp:new()
	if not sock then
		return nil, "Can't Create redis Socket"
	end
	local ok = sock:connect(db_conf.host, db_conf.port or 6379)
	if not ok then
		return nil, "Sorry, Connect redis server error."
	end
	local ok, err = redis_login(sock, db_conf.auth, db_conf.db)
	if not ok then
		return nil, "redis login error."
	end
	return true, setmetatable({ sock }, meta)
end

setmetatable(command, { __index = function(t, k)
	local cmd = string.upper(k)
	local f = function (self, v, ...)
		if type(v) == "table" then
			self[1]:send(compose_message(cmd, v))
			return read_response(self[1])
		else
			self[1]:send(compose_message(cmd, {v, ...}))
			return read_response(self[1])
		end
	end
	t[k] = f
	return f
end})

local function read_boolean(so)
	local ok, result = read_response(so)
	return ok, result ~= 0
end

function command:exists(key)
	self[1]:send(compose_message ("EXISTS", key))
	return read_boolean(self[1])
end

function command:sismember(key, value)
	self[1]:send(compose_message ("SISMEMBER", {key, value}))
	return read_boolean(self[1])
end


return redis
