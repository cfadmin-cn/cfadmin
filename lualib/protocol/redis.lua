local tcp = require "internal.TCP"
local dns = require "protocol.dns"

local table = table
local concat = table.concat

local string = string
local find = string.find
local byte = string.byte
local sub = string.sub

local assert = assert

local redis = {}
local command = {}
local meta = {
	__index = command,
	-- DO NOT close channel in __gc
}

---------- redis response
local redcmd = {}

redcmd[36] = function(fd, data) -- '$'
	local bytes = tonumber(data)
	if bytes < 0 then
		return true, nil
	end
	local firstline = fd:recv(bytes + 2)
	return true, sub(firstline, 1, -3)
end

redcmd[43] = function(fd, data) -- '+'
	return true, data
end

redcmd[45] = function(fd, data) -- '-'
	return false, data
end

redcmd[58] = function(fd, data) -- ':'
	-- todo: return string later
	return true, tonumber(data)
end

-- write by Cloudwu
-- local function read_response(fd)
-- 	local result = fd:readline "\r\n"
-- 	local firstchar = byte(result)
-- 	local data = sub(result, 2)
-- 	return redcmd[firstchar](fd, data)
-- end

local function read_response(fd)
	local result = ""
	while 1 do
		local data = fd:recv(1)
		result = result .. data
		if find(result, "\r\n") then
			break
		end
	end
	local firstchar = byte(result)
	return redcmd[firstchar](fd, sub(result, 2))
end


redcmd[42] = function(fd, data)	-- '*'
	local n = tonumber(data)
	if n < 0 then
		return true, nil
	end
	local bulk = {}
	local noerr = true
	for i = 1,n do
		local ok, v = read_response(fd)
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

local function redis_login(so, auth, db)
	if auth == nil and db == nil then
		return
	end
	if auth then
		so:send(compose_message("AUTH", auth))
		read_response(so)
	end
	if db then
		so:send(compose_message("SELECT", db))
		read_response(so)
	end
end

function redis.connect(db_conf)
	local sock = tcp:new()
	if not sock then
		return nil, "Create redis socket error."
	end
	-- try connect first only once
	local ok, ip = dns.resolve(db_conf.host)
	if not ok then
		return nil, "Can't resolve redis domain"
	end
	local ok = sock:connect(ip, db_conf.port or 6379)
	if not ok then
		return nil, "Sorry, Connect redis server error."
	end

	redis_login(sock, db_conf.auth, db_conf.db)

	return true, setmetatable( { sock }, meta )
end

setmetatable(command, { __index = function(t,k)
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
	local fd = self[1]
	self[1]:send(compose_message ("EXISTS", key))
	return read_response(self[1])
end

function command:sismember(key, value)
	local fd = self[1]
	self[1]:send(compose_message ("SISMEMBER", {key, value}))
	return read_response(self[1])
end

local function compose_table(lines, msg)
	local tinsert = table.insert
	tinsert(lines, count_cache[#msg])
	for _,v in ipairs(msg) do
		v = tostring(v)
		tinsert(lines,header_cache[#v])
		tinsert(lines,v)
	end
	tinsert(lines, "\r\n")
	return lines
end

return redis
