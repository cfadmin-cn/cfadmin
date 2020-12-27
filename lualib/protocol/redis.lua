local log = require "logging"
local class = require "class"
local Co = require "internal.Co"
local tcp = require "internal.TCP"

local new_tab = require "sys".new_tab

local Log = log:new({ dump = true, path = 'protocol-redis' })

local co_spawn = Co.spawn

local type = type
local pcall = pcall
local ipairs = ipairs
local assert = assert
local tonumber = tonumber
local tostring = tostring

local concat = table.concat
local unpack = table.unpack

local sub = string.sub
local byte = string.byte
local toint = math.tointeger

local CRLF = '\x0d\x0a'

local redcmd = {}

local function read_response(sock)
  local result = sock:readline("\r\n")
  if not result then
    return nil, 'server close!!'
  end
  -- 断言redis 协议是否支持用于快速排错
  return assert(redcmd[byte(result)], "Invalid protocol command : " .. sub(result, 1, 1))(sock, sub(result, 2))
end

local function sock_readbytes(sock, bytes)
  local buffers = new_tab(16, 0)
  while 1 do
    local data = sock:recv(bytes)
    if not data then
      return nil, 'server close!!'
    end
    buffers[#buffers+1] = data
    if #data == bytes then
      return concat(buffers)
    end
    bytes = bytes - #data
  end
end

redcmd[36] = function(sock, data) -- '$'
	local bytes = tonumber(data)
	if bytes < 0 then
		return true, nil
	end
	local firstline = sock_readbytes(sock, bytes + 2)
	return true, sub(firstline, 1, -3)
end

redcmd[43] = function(sock, data) -- '+'
	return true, sub(data, 1, -3)
end

redcmd[45] = function(sock, data) -- '-'
	return false, sub(data, 1, -3)
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
	local bulk = new_tab(n, 0)
	local noerr = true
	for i = 1, n do
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
	local lines = new_tab(#tab, 0)
	lines[#lines+1] = "*"..#tab
	for index = 1, #tab do
		lines[#lines+1] = "$"..#tostring(tab[index])
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
	if type(auth) == 'string' and auth ~= '' then
		sock:send(CMD("AUTH", auth))
		local ok, err = read_response(sock)
		if not ok then
			return nil, err
		end
	end
	if toint(db) and toint(db) >= 0 then
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
	self.auth = opt.auth
	self.db = opt.db
end

function redis:connect()
	local sock = self.sock
	if not sock then
		return nil, "Can't Create redis Socket"
	end
	local ok, err
	ok, err = sock:connect(self.host, toint(self.port) or 6379)
	if not ok then
		return nil, "redis connect error: please check network"
	end
	ok, err = redis_login(sock, self.auth, self.db)
	if not ok then
		return nil, "redis login error:"..(err or 'close')
	end
	return true
end

function redis:set_timeout(timeout)
  self.sock._timeout = timeout
end

-- 订阅
function redis:psubscribe(pattern, func)
	local sock = self.sock
	sock:send(CMD("PSUBSCRIBE", pattern))
	local ok, msg = read_response(sock)
	if not ok or not msg[2] then
		return nil, "PSUBSCRIBE error: 订阅"..tostring(pattern).."失败."
	end
	co_spawn(function ()
		while 1 do
			local ok, msg = read_response(sock)
			if not ok or not msg or not self.sock then
				local ok, err = pcall(func, nil)
				if not ok then
					Log:ERROR(err)
				end
				return
			end
			local data = {type = msg[1], source = msg[2], pattern = pattern, payload = msg[3]}
			if #msg > 3 then
				data = {type = msg[1], source = msg[3], pattern = pattern, payload = msg[4]}
			end
			local ok, err = pcall(func, data)
			if not ok then
				return Log:ERROR(err)
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

-- 管道命令
function redis:pipeline(opt)
	local cmds = {}
	if opt and #opt > 0 then
		for _, cmd in ipairs(opt) do
			cmds[#cmds+1] = CMD(unpack(cmd))
		end
	end
	local max_read_times = #cmds
	if max_read_times > 0 then
		local sock = self.sock
		sock:send(concat(cmds))
		local rets = new_tab(max_read_times, 0)
		for index = 1, max_read_times do
			rets[index] = {read_response(sock)}
		end
		return true, rets
	end
	return nil
end

function redis:close()
	if self.sock then
		self.sock:close()
		self.sock = nil
	end
end

return redis
