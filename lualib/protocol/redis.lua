local log = require "log"
local Co = require "internal.Co"
local tcp = require "internal.TCP"

local co_spwan = Co.spwan

local table = table
local concat = table.concat
local unpack = table.unpack

local sub = string.sub
local string = string
local match = string.match
local fmt = string.format
local find = string.find
local byte = string.byte
local upper = string.upper

local CRLF = '\x0d\x0a'

local redcmd = {}

local function read_response(sock)
	local result = ""
	while 1 do
		local data = sock:recv(1)
		if not data then
			return nil, "server close"
		end
		result = result .. data
		if find(result, CRLF) then
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
	return true, match(data, '(.+)'..CRLF)
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

-- msg could be any type of value

local function make_cache(f)
	return setmetatable({}, {
		__mode = "kv",
		__index = f,
	})
end

local header_cache = make_cache(function(t, k)
		local s = "\r\n$" .. k .. CRLF
		t[k] = s
		return s
	end)

local command_cache = make_cache(function(t, cmd)
		local s = "\r\n$"..#cmd..CRLF..cmd:upper()
		t[cmd] = s
		return s
	end)

local count_cache = make_cache(function(t, k)
		local s = "*" .. k
		t[k] = s
		return s
	end)

local function compose_message(cmd, msg)
	local lines = {}
	if type(msg) == "table" then
		lines[1] = count_cache[#msg+1]
		lines[2] = command_cache[cmd]
		local idx = 3
		for _,v in ipairs(msg) do
			v = tostring(v)
			lines[idx] = header_cache[#v]
			lines[idx+1] = v
			idx = idx + 2
		end
		lines[idx] = CRLF
	else
		msg = tostring(msg)
		lines[1] = "*2"
		lines[2] = command_cache[cmd]
		lines[3] = header_cache[#msg]
		lines[4] = msg
		lines[5] = CRLF
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

-- redis
local command = setmetatable({ __name = "Redis"}, {__index = function(t, k)
	if k == 'auth' or k == 'db' then
		return
	end
	local cmd = upper(k)
	local f = function (self, v, ...)
		local sock = self.sock
		if type(v) == "table" then
			sock:send(compose_message(cmd, v))
			return read_response(sock)
		else
			sock:send(compose_message(cmd, {v, ...}))
			return read_response(sock)
		end
	end
	t[k] = f
	return f
end})

function command:connect()
	local sock = self.sock
	if not sock then
		return nil, "Can't Create redis Socket"
	end
	local ok, err = sock:connect(self.host, self.port or 6379)
	if not ok then
		return nil, "redis connect error: please check network"
	end
	local ok, err = redis_login(sock, self.auth, self.db)
	if not ok then
		return nil, "redis login error:"..(err or 'close')
	end
	self.state = true
	return true
end

local function read_boolean(sock)
	local ok, result = read_response(sock)
	if ok then
		return ok, result ~= 0 or result == "OK"
	end
	return ok, result
end

local function read_kv(sock)
	local ok, array = read_response(sock)
	if ok and #array & 0x1 == 0 then
		local t = {}
		for i=1, #array, 2 do
			t[array[i]] = array[i+1]
		end
		return ok, t
	end
	return ok, array
end

function command:hgetall(map)
	local sock = self.sock
	sock:send(compose_message ("HGETALL", map))
	return read_kv(sock)
end

function command:hmget(map, ...)
	local sock = self.sock
	sock:send(compose_message ("HMGET", {map, ...}))
	return read_response(sock)
end

function command:hset(map, key, value)
	local sock = self.sock
	sock:send(compose_message ("HSET", {map, key, value}))
	return read_boolean(sock) -- HSET 永远返回(true, false)
end

function command:hmset(map, ...)
	local sock = self.sock
	sock:send(compose_message ("HMSET", {map, ...}))
	return read_boolean(sock) -- HSET 永远返回(true, false)
end

function command:set(key, value)
	local sock = self.sock
	sock:send(compose_message ("SET", {key, value}))
	return read_boolean(sock)
end

-- 查询键是否存在
function command:exists(key)
	local sock = self.sock
	sock:send(compose_message ("EXISTS", key))
	return read_boolean(sock)
end

-- 查询键
function command:sismember(key, value)
	local sock = self.sock
	sock:send(compose_message ("SISMEMBER", {key, value}))
	return read_response(sock)
end

-- 执行指定普通脚本
function command:eval(script, numbers, ...)
	local sock = self.sock
	local t = {'EVAL', '"'..script..'"', numbers, ...}
	sock:send(concat(t, " ")..CRLF)
	return read_response(sock)
end

-- 执行指定sha1脚本
function command:evalsha(sha, numbers, ...)
	local sock = self.sock
	local t = {'EVALSHA', sha, numbers, ...}
	sock:send(concat(t, " ")..CRLF)
	return read_response(sock)
end

-- 批量注册事务脚本到redis
function command:loadscripts(scripts)
	local Cache = {}
	local sock = self.sock
	for index, script in ipairs(scripts) do
		local t = {'SCRIPT', 'LOAD', '"'..script..'"', CRLF}
		sock:send(concat(t, " "))
		local ok, result = read_response(sock)
		if not ok then
			return nil, fmt("complite index:%d script error: %", index, errresult)
		end
		Cache[index] = result
	end
	return true, Cache
end

function command:get_config(key)
	local t = {"CONFIG", "GET"}
	if key then
		t[#t+1] = key
	else
		t[#t+1] = '*'
	end
	local sock = self.sock
	sock:send(concat(t, " ")..CRLF)
	return read_response(sock)
end

function command:set_config(key, value)
	local t = {"CONFIG", "SET", key, value, CRLF}
	local sock = self.sock
	sock:send(concat(t, " "))
	return read_response(sock)
end

-- 订阅
function command:psubscribe(pattern, func)
	local sock = self.sock
	sock:send(compose_message("PSUBSCRIBE", pattern))
	local ok, msg = read_response(sock)
	if not ok or not msg[2] then
		return nil, "PSUBSCRIBE error: 订阅"..tostring(pattern).."失败."
	end
	co_spwan(function ( ... )
		while 1 do
			local ok, msg = read_response(sock)
			if not ok or not msg or not self.sock then
				local ok, err = pcall(func, nil)
				if not ok then
					log.error(err)
				end
				return
			end
			local data = {type = msg[1], source = msg[2], pattern = pattern, payload = msg[3]}
			if #msg > 3 then
				data = {type = msg[1], source = msg[3], pattern = pattern, payload = msg[4]}
			end
			local ok, err = pcall(func, data)
			if not ok then
				return log.error(err)
			end
		end
	end)
	return ok, msg
end

-- 订阅
function command:subscribe(pattern, func)
	return self:psubscribe(pattern, func)
end

-- 发布
function command:publish(pattern, data)
	local sock = self.sock
	sock:send(compose_message("PUBLISH", {pattern, data}))
	return read_response(sock)
end

-- 关闭连接
function command:close()
	if self.sock then
		self.sock:close()
		self.sock = nil
	end
	setmetatable(self, nil)
end

-- new_tab -> command -> __index
return {
	new = function (self, opt)
		return setmetatable({
			sock = tcp:new(),
			host = opt.host,
			port = opt.port,
			db = opt.db,
			auth = opt.auth,
			}, {__index = command})
	end,
}