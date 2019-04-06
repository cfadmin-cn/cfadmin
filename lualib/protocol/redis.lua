local log = require "log"
local class = require "class"
local Co = require "internal.Co"
local tcp = require "internal.TCP"
local table = table
local concat = table.concat

local co_spwan = Co.spwan

local sub = string.sub
local string = string
local match = string.match
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
			return nil, 'server close!!'
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

-- 格式化命令为redis protocol
local function CMD(...)
	local tab = {...}
	local lines = { "*"..#tab}
	for index = 1, #tab do
		lines[#lines+1] = "$"..#tab[index]
		lines[#lines+1] = tab[index]
		if index == #tab then
			lines[#lines+1] = ""
		end
	end
	return concat(lines, CRLF)
end

local function read_boolean(sock)
	local ok, result = read_response(sock)
	if ok then
		return ok, result ~= 0 or result == "OK"
	end
	return ok, result
end

local function redis_login(sock, auth, db)
	if auth then
		sock:send(CMD("AUTH", auth))
		local ok, err = read_response(sock)
		if not ok then
			return nil, err
		end
	end
	if db then
		sock:send(CMD("SELECT", db))
		local ok, err = read_response(sock)
		if not ok then
			return nil, err
		end
	end
	return true
end

local redis = class("redis")

function redis:ctor(opt)
	self.sock = tcp:new()
	self.host = opt.host
	self.port = opt.port
	self.db = opt.db
	self.auth = opt.auth
end

function redis:connect()
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
	return true
end

-- 订阅
function redis:psubscribe(pattern, func)
	local sock = self.sock
	sock:send(CMD("PSUBSCRIBE", pattern))
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
function redis:subscribe(pattern, func)
	return self:psubscribe(pattern, func)
end

-- 发布
function redis:publish(pattern, data)
	local sock = self.sock
	sock:send(CMD("PUBLISH", pattern, data))
	return read_response(sock)
end

-- 查询键是否存在
function redis:exists(key)
	local sock = self.sock
	sock:send(CMD("EXISTS", key))
	return read_boolean(sock)
end

-- 查询元素是否集合成员
function redis:sismember(key, value)
	local sock = self.sock
	sock:send(CMD("SISMEMBER", key, value))
	return read_boolean(sock)
end

-- 执行命令
function redis:cmd(...)
	local sock = self.sock
	sock:send(CMD(...))
	return read_response(sock)
end

function redis:close()
	if self.sock then
		self.sock:close()
	end
end

return redis