local class = require "class"
local tcp = require "internal.TCP"
local dns = require "protocol.dns"
local HTTP = require "protocol.http"

local FILEMIME = HTTP.FILEMIME
local RESPONSE_PROTOCOL_PARSER = HTTP.RESPONSE_PROTOCOL_PARSER
local RESPONSE_HEADER_PARSER = HTTP.RESPONSE_HEADER_PARSER

local random = math.random
local find = string.find
local match = string.match
local split = string.sub
local splite = string.gmatch
local spliter = string.gsub
local lower = string.lower
local insert = table.insert
local concat = table.concat
local toint = math.tointeger
local type = type
local assert = assert
local ipairs = ipairs
local tostring = tostring

local fmt = string.format

local SERVER = "cf/0.1"

local __TIMEOUT__ = 15

local httpc = {}

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
			data, len = IO:recv(1024)
		else
			data, len = IO:ssl_recv(1024)
		end
		if not data then
			IO:close()
			return nil, "A peer of remote server close this connection."
		end
		insert(content, data)
		local DATA = concat(content)
		local posA, posB = find(DATA, '\r\n\r\n')
		if posB then
			CODE = RESPONSE_PROTOCOL_PARSER(split(DATA, 1, posB))
			HEADER = RESPONSE_HEADER_PARSER(split(DATA, 1, posB))
			if not CODE or not HEADER then
				IO:close()
				return nil, "can't resolvable protocol."
			end
			local Content_Length = toint(HEADER['Content-Length'])
			local chunked = HEADER['Transfer-Encoding']
			if Content_Length then
				if (#DATA - posB) == Content_Length then
					IO:close()
					return CODE, split(DATA, posB+1, #DATA)
				end
				local content = {split(DATA, posB+1, #DATA)}
				while 1 do
					local data, len
					if SSL == "http" then
						data, len = IO:recv(1024)
					else
						data, len = IO:ssl_recv(1024)
					end
					if not data then
						IO:close()
						return nil, "A peer of remote server close this connection."
					end
					insert(content, data)
					local DATA = concat(content)
					if Content_Length == #DATA then
						IO:close()
						return CODE, DATA
					end
				end
			end
			if chunked and chunked == "chunked" then
				local content = {}
				if #DATA > posB then
					local DATA = split(DATA, posB+1, #DATA)
					if find(DATA, '\r\n\r\n') then
						local body = {}
						for hex, block in splite(DATA, "([%a%d]*)\r\n(.-)\r\n") do
							local len = toint(fmt("0x%s", hex))
							if len and len == #block then
								if len == 0 and block == '' then
									IO:close()
									return CODE, concat(body)
								end
								insert(body, block)
							end
						end
					end
					insert(content, DATA)
				end
				while 1 do
					local data, len
					if SSL == "http" then
						data, len = IO:recv(1024)
					else
						data, len = IO:ssl_recv(1024)
					end
					if not data then
						IO:close()
						return nil, "A peer of remote server close this connection."
					end
					insert(content, data)
					local DATA = concat(content)
					if find(DATA, '\r\n\r\n') then
						local body = {}
						for hex, block in splite(DATA, "([%a%d]*)\r\n(.-)\r\n") do
							local len = toint(fmt("0x%s", hex))
							if len and len == #block then
								if len == 0 and block == '' then
									IO:close()
									return CODE, concat(body)
								end
								insert(body, block)
							end
						end
					end
				end
			end
		end
	end
end

local function IO_CONNECT(IO, PROTOCOL, IP, PORT)
	if PROTOCOL == "http" then
		if not toint(PORT) or PORT == '' then
			PORT = 80
		end
		local ok = IO:connect(IP, toint(PORT))
		if not ok then
			IO:close()
			return nil, "Can't connect to this IP and Port."
		end
		return true
	end
	if PROTOCOL == "https" then
		if toint(PORT) or PORT == '' then
			PORT = 443
		end
		local ok = IO:ssl_connect(IP, toint(PORT))
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

-- HTTP GET
function httpc.get(domain, HEADER, ARGS, TIMEOUT)

	local PROTOCOL, DOMAIN, PORT, PATH = match(domain, '(http[s]?)://([^/":]+)[:]?([%d]*)([/]?.*)')

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
		'Accept-Encoding: identity',
		fmt("Connection: keep-alive"),
		fmt("User-Agent: %s", SERVER),
	}
	if ARGS and type(ARGS) == "table" then
		local args = {}
		for _, arg in ipairs(ARGS) do
			assert(#arg == 2, "args need key[1]->value[2] (2 values)")
			insert(args, arg[1]..'='..arg[2])
		end
		request[1] = fmt("GET %s HTTP/1.1", PATH..'?'..concat(args, "&"))
	end
	if HEADER and type(HEADER) == "table" then
		for _, header in ipairs(HEADER) do
			assert(lower(header[1]) ~= 'content-length', "please don't give Content-Length")
			assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
			insert(request, header[1]..': '..header[2])
		end
	end
	insert(request, '\r\n')
	local REQ = concat(request, '\r\n')

	local IO = tcp:new():timeout(TIMEOUT or __TIMEOUT__)
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
function httpc.post(domain, HEADER, BODY, TIMEOUT)

	local PROTOCOL, DOMAIN, PORT, PATH = match(domain, '(http[s]?)://([^/":]+)[:]?([%d]*)([/]?.*)')

	if not PROTOCOL or PROTOCOL == '' or not DOMAIN  or DOMAIN == '' then
		return nil, "Invaild protocol from http post ."
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
		'Accept-Encoding: identity',
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

	local IO = tcp:new():timeout(TIMEOUT or __TIMEOUT__)
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

function httpc.json(domain, HEADER, JSON, TIMEOUT)

	local PROTOCOL, DOMAIN, PORT, PATH = match(domain, '(http[s]?)://([^/":]+)[:]?([%d]*)([/]?.*)')

	if not PROTOCOL or PROTOCOL == '' or not DOMAIN  or DOMAIN == '' then
		return nil, "Invaild protocol from http json ."
	end

	local ok, IP = dns.resolve(DOMAIN)
	if not ok then
		return nil, "Can't resolve domain"
	end

	if not PATH or PATH == '' then
		PATH = '/'
	end

	assert(type(JSON) == "string", "Please passed A vaild json string.")

	local request = {
		fmt("POST %s HTTP/1.1\r\n", PATH),
		fmt("Host: %s\r\n", DOMAIN),
		'Accept-Encoding: identity',
		fmt("Connection: keep-alive\r\n"),
		fmt("User-Agent: %s\r\n", SERVER),
		fmt("Content-Length: %s\r\n", #JSON),
		'Content-Type: application/json\r\n',
	}
	if HEADER and type(HEADER) == "table" then
		for _, header in ipairs(HEADER) do
			assert(lower(header[1]) ~= 'content-length', "please don't give Content-Length")
			assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
			insert(request, header[1]..': '..header[2]..'\r\n')
		end
	end

	insert(request, '\r\n')
	insert(request, JSON)

	local REQ = concat(request)

	local IO = tcp:new():timeout(TIMEOUT or __TIMEOUT__)
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

function httpc.file(domain, HEADER, FILES, TIMEOUT)

	local PROTOCOL, DOMAIN, PORT, PATH = match(domain, '(http[s]?)://([^/":]+)[:]?([%d]*)([/]?.*)')

	if not PROTOCOL or PROTOCOL == '' or not DOMAIN  or DOMAIN == '' then
		return nil, "Invaild protocol from http file ."
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
		'Accept-Encoding: identity',
		fmt("Connection: keep-alive\r\n"),
		fmt("User-Agent: %s\r\n", SERVER),
	}

	if HEADER and type(HEADER) == "table" then
		for _, header in ipairs(HEADER) do
			assert(lower(header[1]) ~= 'content-length', "please don't give Content-Length")
			assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
			insert(request, header[1]..': '..header[2]..'\r\n')
		end
	end

	if FILES then
		local bd = random(1000000000, 9999999999)
		local boundary_start = fmt("------CFWebService%d", bd)
		local boundary_end   = fmt("------CFWebService%d--", bd)
		insert(request, fmt('Content-Type: multipart/form-data; boundary=----CFWebService%s\r\n', bd))
		local body = {}
		for _, file in ipairs(FILES) do
			insert(body, boundary_start)
			local header = ""
			if file.name and file.filename then
				header = fmt(' name="%s"; filename="%s"', file.name, file.filename)
			end
			insert(body, fmt('Content-Disposition: form-data;%s', header))
			insert(body, fmt('Content-Type: %s\r\n', FILEMIME(file.type or '') or 'application/octet-stream'))
			insert(body, file.file)
		end
		body = concat(body, '\r\n')
		insert(request, fmt("Content-Length: %s\r\n", #body + 2 + #boundary_end))
		insert(request, '\r\n')
		insert(request, body)
		insert(request, '\r\n')
		insert(request, boundary_end)
	end

	local REQ = concat(request)

	local IO = tcp:new():timeout(TIMEOUT or __TIMEOUT__)
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

return httpc