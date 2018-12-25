local class = require "class"
local tcp = require "internal.TCP"
local dns = require "protocol.dns"
local HTTP = require "protocol.http"
-- require "utils"

local PARSER_PROTOCOL = HTTP.RESPONSE_PROTOCOL_PARSER
local PARSER_HEAD = HTTP.RESPONSE_HEAD_PARSER
local PARSER_BODY = HTTP.RESPONSE_BODY_PARSER

local find = string.find
local split = string.sub
local spliter = string.gsub

local insert = table.insert
local concat = table.concat

local fmt = string.format

local SERVER = "cf/0.1"

local TIMEOUT = 15

local httpc = {}

-- 设置请求超时时间
function httpc.set_timeout(Invaild)
	if Invaild > 0 then
		TIMEOUT = Invaild
	end
end


function httpc.get(domain, HEADER)

	local PROTOCOL, DOMAIN, PATH, PORT

	spliter(domain, '(http[s]?)://([^/":]+)[:]?([%d]*)([/]?.*)', function (protocol, domain, port, path)
		PROTOCOL = protocol
		DOMAIN = domain
		PATH = path
		PORT = port
	end)

	if not PROTOCOL or not DOMAIN or not PORT or not PATH then
		return nil, "Invaild protocol from http get 1."
	end

	if not PROTOCOL or not DOMAIN or not PORT or not PATH then
		return nil, "Invaild protocol from http get 2."
	end

	local ok, ip = dns.resolve(DOMAIN)
	if not ok then
		return nil, "Can't resolve domain"
	end

	local IO = tcp:new():timeout(TIMEOUT)
	if PROTOCOL == "http" then
		if tonumber(PORT) or PORT == '' then
			PORT = 80
		end
		local ok = IO:connect(ip, PORT)
		if not ok then
			IO:close()
			return nil, "Can't connect to this IP and Port."
		end
	else
		if tonumber(PORT) or PORT == '' then
			PORT = 443
		end
		local ok = IO:ssl_connect(ip, PORT)
		if not ok then
			IO:close()
			return nil, "Can't ssl connect to this IP and Port."
		end
	end

	local request = {
		fmt("GET %s HTTP/1.1", PATH),
		fmt("Host: %s", DOMAIN),
		fmt("Connect: Keep-Alive"),
		fmt("User-Agent: %s", SERVER),
		'\r\n'
	}
	if PROTOCOL == "http" then
		IO:send(concat(request, '\r\n'))
	else
		IO:ssl_send(concat(request, '\r\n'))
	end
	return httpc.response(IO, PROTOCOL)
end

function httpc.post(domain, HEADER, BODY)

	local PROTOCOL, DOMAIN, PATH, PORT

	spliter(domain, '(http[s]?)://([^/":]+)[:]?([%d]*)([/]?.*)', function (protocol, domain, port, path)
		PROTOCOL = protocol
		DOMAIN = domain
		PATH = path
		PORT = port
	end)

	if not PROTOCOL or not DOMAIN or not PORT or not PATH then
		return nil, "Invaild protocol from http get 1."
	end

	if not PROTOCOL or not DOMAIN or not PORT or not PATH then
		return nil, "Invaild protocol from http get 2."
	end

	local ok, ip = dns.resolve(DOMAIN)
	if not ok then
		return nil, "Can't resolve domain"
	end

	local IO = tcp:new():timeout(TIMEOUT)
	if PROTOCOL == "http" then
		if tonumber(PORT) or PORT == '' then
			PORT = 80
		end
		local ok = IO:connect(ip, PORT)
		if not ok then
			IO:close()
			return nil, "Can't connect to this IP and Port."
		end
	else
		if tonumber(PORT) or PORT == '' then
			PORT = 443
		end
		local ok = IO:ssl_connect(ip, PORT)
		if not ok then
			IO:close()
			return nil, "Can't ssl connect to this IP and Port."
		end
	end

	if not BODY then
		BODY = ""
	end

	local request = {
		fmt("POST %s HTTP/1.1\r\n", PATH),
		fmt("Host: %s\r\n", DOMAIN),
		fmt("Connect: keep-alive\r\n"),
		fmt("User-Agent: %s\r\n", SERVER),
		fmt("Content-Length: %s\r\n", #BODY),
		'\r\n\r\n',
		BODY,
	}

	if PROTOCOL == "http" then
		IO:send(concat(request))
	else
		IO:ssl_send(concat(request))
	end

	return httpc.response(IO, PROTOCOL)
end

function httpc.response(IO, SSL)
	if not IO then
		return nil, "Can't used this method before other httpc method.."
	end
	local CODE, HEAD, BODY
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
		if times == 0 then
			local DATA = concat(content)
			local posA, posB = find(DATA, '\r\n\r\n')
			if posA and posB then
				if #DATA > posB then
					content = {}
					insert(content, split(DATA, posB + 1, -1))
				end
				local protocol_start, protocol_end = find(DATA, '\r\n')
				if not protocol_start or not protocol_end then
					IO:close()
					return nil, "can't resolvable protocol."
				end
				CODE = PARSER_PROTOCOL(split(DATA, 1, protocol_end))
				HEAD = PARSER_HEAD(split(DATA, protocol_end + 1, posA + 1))
				-- var_dump(HEAD)
				if not HEAD['Content-Length'] then
					BODY = ""
					break
				end
				Content_Length = HEAD['Content-Length']
				times = times + 1
			end
		end
		if times > 0 then
			BODY = concat(content)
			if #BODY >= Content_Length then
				break
			end
		end
	end
	IO:close()
	return CODE, BODY
end

return httpc
