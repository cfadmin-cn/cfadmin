local class = require "class"
local tcp = require "internal.TCP"
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

local CRLF = '\x0d\x0a'
local CRLF2 = '\x0d\x0a\x0d\x0a'

local fmt = string.format

local SERVER = "cf/0.1"

local __TIMEOUT__ = 15

local httpc = {}

local function sock_recv (sock, PROTOCOL, byte)
	if PROTOCOL == 'https' then
		local data, len = sock:ssl_recv(byte)
		if data then
			return data, len
		end
	end
	if PROTOCOL == 'http' then
		local data, len = sock:recv(byte)
		if data then
			return data, len
		end
	end
	return nil, '服务端断开了连接'
end

local function sock_connect(sock, PROTOCOL, DOAMIN, PORT)
	if PROTOCOL == 'https' then
		local ok, err = sock:ssl_connect(DOAMIN, PORT)
		if ok then
			return true
		end
	end
	if PROTOCOL == 'http' then
		local ok, err = sock:connect(DOAMIN, PORT)
		if ok then
			return true
		end
	end
	sock:close()
	return nil, 'httpc连接失败.'
end

local function sock_send(sock, PROTOCOL, DATA)
	if PROTOCOL == 'http' then
		local ok = sock:send(DATA)
		if ok then
			return true
		end
	end

	if PROTOCOL == 'https' then
		local ok = sock:send(DATA)
		if ok then
			return true
		end
	end
	sock:close()
	return nil, "httpc发送请求失败"
end


local function httpc_response(sock, SSL)
	if not sock then
		return nil, "Can't used this method before other httpc method.."
	end
	local CODE, HEADER, BODY
	local Content_Length
	local content = {}
	local times = 0
	while 1 do
		local data, len = sock_recv(sock, SSL, 1024)
		if not data then
			sock:close()
			return nil, "A peer of remote server close this connection."
		end
		insert(content, data)
		local DATA = concat(content)
		local posA, posB = find(DATA, CRLF2)
		if posB then
			CODE = RESPONSE_PROTOCOL_PARSER(split(DATA, 1, posB))
			HEADER = RESPONSE_HEADER_PARSER(split(DATA, 1, posB))
			if not CODE or not HEADER then
				sock:close()
				return nil, "can't resolvable protocol."
			end
			local Content_Length = toint(HEADER['Content-Length'] or HEADER['content-length'])
			local chunked = HEADER['Transfer-Encoding']
			if not chunked and not Content_Length then
				Content_Length = 0
			end
			if Content_Length then
				if (#DATA - posB) == Content_Length then
					sock:close()
					return CODE, split(DATA, posB+1, #DATA)
				end
				local content = {split(DATA, posB+1, #DATA)}
				while 1 do
					local data, len = sock_recv(sock, SSL, 1024)
					if not data then
						sock:close()
						return CODE, SSL.."[Content_Length] A peer of remote server close this connection."
					end
					insert(content, data)
					local DATA = concat(content)
					if Content_Length == #DATA then
						sock:close()
						return CODE, DATA
					end
				end
			end
			if chunked and chunked == "chunked" then
				local content = {}
				if #DATA > posB then
					local DATA = split(DATA, posB+1, #DATA)
					if find(DATA, CRLF2) then
						local body = {}
						for hex, block in splite(DATA, "([%w]*)\r\n(.-)\r\n") do
							local len = toint(fmt("0x%s", hex))
							if len and len == #block then
								if len == 0 and block == '' then
									sock:close()
									return CODE, concat(body)
								end
								insert(body, block)
							end
						end
					end
					insert(content, DATA)
				end
				while 1 do
					local data, len = sock_recv(sock, SSL, 1024)
					if not data then
						sock:close()
						return CODE, SSL.."[chunked] A peer of remote server close this connection A."
					end
					insert(content, data)
					local DATA = concat(content)
					if find(DATA, CRLF2) then
						local body = {}
						for hex, block in splite(DATA, "([%a%d]*)\r\n(.-)\r\n") do
							local len = toint(fmt("0x%s", hex))
							if len and len == #block then
								if len == 0 and block == '' then
									sock:close()
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

-- 分割httpc domain
local function splite_protocol(domain)
	if type(domain) ~= 'string' then
		return nil, '1. 非法的域名'
	end

	local protocol, domain_port, path = match(domain, '^(http[s]?)://([^/]+)(.*)')
	if not protocol or not domain_port or not path then
		return nil, '2. 错误的url'
	end

	if not path or path == '' then
		return nil, "3. http无path需要以'/'结尾."
	end

	local domain, port
	if find(domain_port, ':') then
		local _, Bracket_Pos = find(domain_port, '[%[%]]')
    if Bracket_Pos then
      domain, port = match(domain_port, '%[(.+)%][:]?(%d*)')
    else
      domain, port = match(domain_port, '([^:]+):(%d*)')
    end
    if not domain then
      return nil, "4. 无效或者非法的主机名: "..domain_port
    end
    port = toint(port)
    if not port then
      port = 80
    end
	else
		domain, port = domain_port, 80
	end
	return {
		protocol = protocol,
		domain = domain,
		port = port,
		path = path,
	}
end


-- HTTP GET
function httpc.get(domain, HEADER, ARGS, TIMEOUT)

	local opt, err = splite_protocol(domain)
	if not opt then
		return nil, err
	end

	local request = {
		fmt("GET %s HTTP/1.1", opt.path),
		fmt("Host: %s", opt.domain..':'..opt.port),
		'Accept: */*',
		'Accept-Encoding: identity',
		fmt("Connection: keep-alive"),
		fmt("User-Agent: %s", SERVER),
	}
	if type(ARGS) == "table" then
		local args = {}
		for _, arg in ipairs(ARGS) do
			assert(#arg == 2, "args need key[1]->value[2] (2 values)")
			insert(args, arg[1]..'='..arg[2])
		end
		request[1] = fmt("GET %s HTTP/1.1", opt.path..'?'..concat(args, "&"))
	end
	if HEADER and type(HEADER) == "table" then
		for _, header in ipairs(HEADER) do
			assert(lower(header[1]) ~= 'content-length', "please don't give Content-Length")
			assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
			insert(request, header[1]..': '..header[2])
		end
	end
	insert(request, CRLF)
	local REQ = concat(request, CRLF)

	local sock = tcp:new():timeout(TIMEOUT or __TIMEOUT__)
	local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
	if not ok then
		return ok, err
	end
	local ok, err = sock_send(sock, opt.protocol, REQ)
	if not ok then
		return ok, err
	end
	return httpc_response(sock, opt.protocol)
end

-- HTTP POST
function httpc.post(domain, HEADER, BODY, TIMEOUT)

	local opt, err = splite_protocol(domain)
	if not opt then
		return nil, err
	end

	local request = {
		fmt("POST %s HTTP/1.1\r\n", opt.path),
		fmt("Host: %s\r\n", opt.domain..':'..opt.port),
		'Accept: */*\r\n',
		'Accept-Encoding: identity\r\n',
		fmt("Connection: keep-alive\r\n"),
		fmt("User-Agent: %s\r\n", SERVER),
		'Content-Type: application/x-www-form-urlencoded\r\n',
	}
	if type(HEADER) == "table" then
		for _, header in ipairs(HEADER) do
			assert(string.lower(header[1]) ~= 'content-length', "please don't give Content-Length")
			assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
			insert(request, header[1]..': '..header[2]..CRLF)
		end
	end
	insert(request, CRLF)

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

	local sock = tcp:new():timeout(TIMEOUT or __TIMEOUT__)
	local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
	if not ok then
		return ok, err
	end
	local ok, err = sock_send(sock, opt.protocol, REQ)
	if not ok then
		return ok, err
	end
	return httpc_response(sock, opt.protocol)
end

function httpc.json(domain, HEADER, JSON, TIMEOUT)

	local opt, err = splite_protocol(domain)
	if not opt then
		return nil, err
	end

	assert(type(JSON) == "string", "Please passed A vaild json string.")

	local request = {
		fmt("POST %s HTTP/1.1\r\n", opt.path),
		fmt("Host: %s\r\n", opt.domain..':'..opt.port),
		'Accept: */*\r\n',
		'Accept-Encoding: identity\r\n',
		fmt("Connection: keep-alive\r\n"),
		fmt("User-Agent: %s\r\n", SERVER),
		fmt("Content-Length: %s\r\n", #JSON),
		'Content-Type: application/json\r\n',
	}
	if HEADER and type(HEADER) == "table" then
		for _, header in ipairs(HEADER) do
			assert(lower(header[1]) ~= 'content-length', "please don't give Content-Length")
			assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
			insert(request, header[1]..': '..header[2]..CRLF)
		end
	end

	insert(request, CRLF)
	insert(request, JSON)

	local REQ = concat(request)

	local sock = tcp:new():timeout(TIMEOUT or __TIMEOUT__)
	local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
	if not ok then
		return ok, err
	end
	local ok, err = sock_send(sock, opt.protocol, REQ)
	if not ok then
		return ok, err
	end
	return httpc_response(sock, opt.protocol)
end

function httpc.file(domain, HEADER, FILES, TIMEOUT)

	local opt, err = splite_protocol(domain)
	if not opt then
		return nil, err
	end

	local request = {
		fmt("POST %s HTTP/1.1\r\n", opt.path),
		fmt("Host: %s\r\n", opt.domain..':'..opt.port),
		'Accept: */*\r\n',
		'Accept-Encoding: identity\r\n',
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
		body = concat(body, CRLF)
		insert(request, fmt("Content-Length: %s\r\n", #body + 2 + #boundary_end))
		insert(request, CRLF)
		insert(request, body)
		insert(request, CRLF)
		insert(request, boundary_end)
	end

	local REQ = concat(request)

	local sock = tcp:new():timeout(TIMEOUT or __TIMEOUT__)
	local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
	if not ok then
		return ok, err
	end
	local ok, err = sock_send(sock, opt.protocol, REQ)
	if not ok then
		return ok, err
	end
	return httpc_response(sock, opt.protocol)
end

return httpc
