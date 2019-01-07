local class = require "class"
local tcp = require "internal.TCP"
local dns = require "protocol.dns"
local HTTP = require "protocol.http"

local RESPONSE_PROTOCOL_PARSER = HTTP.RESPONSE_PROTOCOL_PARSER
local RESPONSE_HEADER_PARSER = HTTP.RESPONSE_HEADER_PARSER

local find = string.find
local split = string.sub
local spliter = string.gsub

local insert = table.insert
local concat = table.concat

local fmt = string.format

local SERVER = "cf/0.1"

local TIMEOUT = 15

local function httpc_response(IO, SSL)
	if not IO then
		return nil, "Can't used this method before other httpc method.."
	end
	local CODE, HEADER, BODY
	local Content_Length
	local content = {}
	local times = 0
	while 1 do
		local data, len
		if SSL == "http" then
			data, len = IO:recv(4096)
		else
			data, len = IO:ssl_recv(4096)
		end
		if not data then
			IO:close()
			return nil, "A peer of remote close this connection."
		end
		insert(content, data)
		local DATA = concat(content)
		local _, posB = find(DATA, '\r\n\r\n')
		if posB then
			CODE = RESPONSE_PROTOCOL_PARSER(split(DATA, 1, posB))
			HEADER = RESPONSE_HEADER_PARSER(split(DATA, 1, posB))
			if not CODE or not HEADER then
				IO:close()
				return nil, "can't resolvable protocol."
			end
			local Content_Length = tonumber(HEADER['Content-Length'])
			if Content_Length then
				if (#DATA - posB) == Content_Length then
					BODY = split(DATA, posB+1, #DATA)
					break
				end
				content = {split(DATA, posB+1, #DATA)}
				while 1 do
					local data, len
					if SSL == "http" then
						data, len = IO:recv(4096)
					else
						data, len = IO:ssl_recv(4096)
					end
					if not data then
						IO:close()
						return nil, "A peer of remote close this connection."
					end
					insert(content, data)
					local DATA = concat(content)
					if Content_Length == #DATA then
						IO:close()
						return CODE, DATA
					end
				end
			end
		end
	end
	IO:close()
	return CODE, BODY
end

local function IO_CONNECT(IO, PROTOCOL, IP, PORT)
	if PROTOCOL == "http" then
		if not tonumber(PORT) or PORT == '' then
			PORT = 80
		end
		local ok = IO:connect(IP, tonumber(PORT))
		if not ok then
			IO:close()
			return nil, "Can't connect to this IP and Port."
		end
		return true
	end
	if PROTOCOL == "https" then
		if tonumber(PORT) or PORT == '' then
			PORT = 443
		end
		local ok = IO:ssl_connect(IP, tonumber(PORT))
		if not ok then
			IO:close()
			return nil, "Can't ssl connect to this IP and Port."
		end
		return true
	end
	IO:close()
	return nil, "IO_CONNECT error! unknow PROTOCOL: "..tostring(PROTOCOL)
end

local function IO_SEND(IO, PROTOCOL, DATA)
	if PROTOCOL == "http" then
		local ok = IO:send(DATA)
		if not ok then
			IO:close()
			return nil, "httpc request get method error"
		end
		return true
	end
	if PROTOCOL == "https" then
		local ok = IO:ssl_send(DATA)
		if not ok then
			IO:close()
			return nil, "httpc ssl request get method error"
		end
		return true
	end
	IO:close()
	return nil, "IO_SEND error! unknow PROTOCOL: "..tostring(PROTOCOL)
end

local httpc = {}

-- 设置请求超时时间
function httpc.set_timeout(Invaild)
	if Invaild > 0 then
		TIMEOUT = Invaild
	end
end

-- HTTP GET
function httpc.get(domain, HEADER)

	local PROTOCOL, DOMAIN, PATH, PORT

	spliter(domain, '(http[s]?)://([^/":]+)[:]?([%d]*)([/]?.*)', function (protocol, domain, port, path)
		PROTOCOL = protocol
		DOMAIN = domain
		PATH = path
		PORT = port
	end)

	if not PROTOCOL or PROTOCOL == '' or not DOMAIN  or DOMAIN == '' then
		return nil, "Invaild protocol from http get ."
	end

	local ok, IP = dns.resolve(DOMAIN)
	if not ok then
		return nil, "Can't resolve domain"
	end

	if not PATH or PATH == '' then
		PATH = '/'
	end

	local request = {
		fmt("GET %s HTTP/1.1", PATH),
		fmt("Host: %s", DOMAIN),
		fmt("Connection: Keep-Alive"),
		fmt("User-Agent: %s", SERVER),
	}
	if HEADER and type(HEADER) == "table" then
		for _, header in ipairs(HEADER) do
			assert(string.lower(header[1]) ~= 'content-length', "please don't give Content-Length")
			assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
			insert(request, header[1]..': '..header[2]..'\r\n')
		end
	end
	insert(request, '\r\n')
	local REQ = concat(request, '\r\n')

	local IO = tcp:new():timeout(TIMEOUT)
	local ok, err = IO_CONNECT(IO, PROTOCOL, IP, PORT)
	if not ok then
		return ok, err
	end
	local ok, err = IO_SEND(IO, PROTOCOL, REQ)
	if not ok then
		return ok, err
	end
	return httpc_response(IO, PROTOCOL)
end

-- HTTP POST
function httpc.post(domain, HEADER, BODY)

	local PROTOCOL, DOMAIN, PATH, PORT

	spliter(domain, '(http[s]?)://([^/":]+)[:]?([%d]*)([/]?.*)', function (protocol, domain, port, path)
		PROTOCOL = protocol
		DOMAIN = domain
		PATH = path
		PORT = port
	end)

	if not PROTOCOL or PROTOCOL == '' or not DOMAIN  or DOMAIN == '' then
		return nil, "Invaild protocol from http get ."
	end

	local ok, IP = dns.resolve(DOMAIN)
	if not ok then
		return nil, "Can't resolve domain"
	end

	if not PATH or PATH == '' then
		PATH = '/'
	end

	local request = {
		fmt("POST %s HTTP/1.1\r\n", PATH),
		fmt("Host: %s\r\n", DOMAIN),
		fmt("Connection: keep-alive\r\n"),
		fmt("User-Agent: %s\r\n", SERVER),
		'Content-Type: application/x-www-form-urlencoded\r\n',
	}
	if HEADER and type(HEADER) == "table" then
		for _, header in ipairs(HEADER) do
			assert(string.lower(header[1]) ~= 'content-length', "please don't give Content-Length")
			assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
			insert(request, header[1]..': '..header[2]..'\r\n')
		end
	end
	insert(request, '\r\n')

	if BODY and type(BODY) == "table" then
		local body = {}
		for _, b in ipairs(BODY) do
			assert(#b == 2, "if BODY is TABLE, BODY need key[1]->value[2] (2 values)")
			insert(body, fmt("%s=%s", b[1], b[2]))
		end
		insert(request, concat(body, "&"))
		insert(request, #request - 2, fmt("Content-Length: %s\r\n", #request[#request]))
	end
	if BODY and type(BODY) == "string" then
		insert(request, #request, fmt("Content-Length: %s\r\n", #BODY))
		insert(request, BODY)
	end

	local REQ = concat(request)

	local IO = tcp:new():timeout(TIMEOUT)
	local ok, err = IO_CONNECT(IO, PROTOCOL, IP, PORT)
	if not ok then
		return ok, err
	end
	local ok, err = IO_SEND(IO, PROTOCOL, REQ)
	if not ok then
		return ok, err
	end
	print(REQ)
	return httpc_response(IO, PROTOCOL)
end

return httpc
