local tcp = require "internal.TCP"

local url = require "url"
local url_encode = url.encode

local HTTP = require "protocol.http"
local FILEMIME = HTTP.FILEMIME
local PARSER_HTTP_RESPONSE = HTTP.PARSER_HTTP_RESPONSE
local RESPONSE_CHUNKED_PARSER = HTTP.RESPONSE_CHUNKED_PARSER

local type = type
local assert = assert
local ipairs = ipairs
local tostring = tostring

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
local fmt = string.format

local CRLF = '\x0d\x0a'
local CRLF2 = '\x0d\x0a\x0d\x0a'

local SERVER = "cf/0.1"


local function sock_new ()
  return tcp:new()
end

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

local function sock_send(sock, PROTOCOL, DATA)
	if PROTOCOL == 'https' then
		local ok = sock:ssl_send(DATA)
		if ok then
			return true
		end
	end

	if PROTOCOL == 'http' then
		local ok = sock:send(DATA)
		if ok then
			return true
		end
	end
	return nil, "httpc发送请求失败"
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
	return nil, 'httpc连接失败.'
end

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
			if protocol == 'https' then
      	port = 443
			end
    end
	else
		domain, port = domain_port, protocol == 'https' and 443 or 80
	end
	return {
		protocol = protocol,
		domain = domain,
		port = port,
		path = path,
	}
end

local function httpc_response(sock, SSL)
	if not sock then
		return nil, "Can't used this method before other httpc method.."
	end
	local VERSION, CODE, STATUS, HEADER, BODY
	local Content_Length
	local content = {}
	local times = 0
	while 1 do
		local data, len = sock_recv(sock, SSL, 2048)
		if not data then
			return nil, SSL.." A peer of remote server close this connection."
		end
		insert(content, data)
		local DATA = concat(content)
		local posA, posB = find(DATA, CRLF2)
		if posB then
      VERSION, CODE, STATUS, HEADER = PARSER_HTTP_RESPONSE(DATA)
			if not CODE or not HEADER then
				return nil, SSL.." can't resolvable protocol."
			end
			local Content_Length = toint(HEADER['Content-Length'] or HEADER['Content-length'] or HEADER['content-length'])
			local chunked = HEADER['Transfer-Encoding'] or HEADER['Transfer-encoding'] or HEADER['transfer-encoding']
			if not chunked and not Content_Length then
				return nil, "不支持的请求体解析方式:"..(
        (HEADER['Content-Length'] or HEADER['Content-length'] or HEADER['content-length']) or
        (HEADER['Transfer-Encoding'] or HEADER['Transfer-encoding'] or HEADER['transfer-encoding']) or
        "未知的解析方式")
			end
			if Content_Length then
				if (#DATA - posB) == Content_Length then
					return CODE, split(DATA, posB + 1, #DATA)
				end
				local content = {split(DATA, posB + 1, #DATA)}
        local Len = #content[1]
				while 1 do
					local data, len = sock_recv(sock, SSL, 2048)
					if not data then
						return nil, SSL.."[Content_Length] A peer of remote server close this connection."
					end
					insert(content, data)
          Len = Len + len
          if Len >= Content_Length then
            return CODE, concat(content)
          end
				end
			end
			if chunked and chunked == "chunked" then
				local content = {}
				if #DATA > posB then
          local buf = split(DATA, posB + 1, #DATA)
          data, len = RESPONSE_CHUNKED_PARSER(buf)
          if len == -1 then
            return nil, SSL.." 错误的http trunked. 1"
          end
          if data then
            local Pos = find(data, CRLF..(0)..CRLF2)
            return CODE, split(data, 1,  Pos and Pos - #CRLF2 - 1 or -1)
          end
          insert(content, buf)
				end
				while 1 do
					local data, len = sock_recv(sock, SSL, 2048)
					if not data then
						return CODE, SSL.."[chunked] A peer of remote server close this connection A."
					end
					insert(content, data)
          local data, len = RESPONSE_CHUNKED_PARSER(concat(content))
          if len == -1 then
            return nil, SSL.." 错误的http trunked. 2"
          end
          if data then
            local Pos = find(data, CRLF..(0)..CRLF2)
            return CODE, split(data, 1,  Pos and Pos - #CRLF2 - 1 or -1)
          end
				end
			end
		end
	end
end


local function build_get_req (opt)
  local request = {
    fmt("GET %s HTTP/1.1", opt.path),
    fmt("Host: %s", opt.domain..':'..opt.port),
    'Accept: */*',
    'Accept-encoding: identity',
    fmt("Connection: keep-alive"),
    fmt("User-agent: %s", opt.server),
  }
  if type(opt.args) == "table" then
    local args = {}
    for _, arg in ipairs(opt.args) do
      assert(#arg == 2, "args need key[1]->value[2] (2 values and must be string)")
      insert(args, url_encode(arg[1])..'='..url_encode(arg[2]))
    end
    request[1] = fmt("GET %s HTTP/1.1", opt.path..'?'..concat(args, "&"))
  end
  if type(opt.headers) == "table" then
    for _, header in ipairs(opt.headers) do
      assert(lower(header[1]) ~= 'content-length', "please don't give Content-Length")
      assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
      insert(request, header[1]..': '..header[2])
    end
  end
  insert(request, CRLF)
  return concat(request, CRLF)
end

local function build_post_req (opt)
  local request = {
		fmt("POST %s HTTP/1.1\r\n", opt.path),
		fmt("Host: %s\r\n", opt.domain..':'..opt.port),
		'Accept: */*\r\n',
		'Accept-encoding: identity\r\n',
		'Connection: keep-alive\r\n',
		fmt("User-agent: %s\r\n", opt.server),
		'Content-Type: application/x-www-form-urlencoded\r\n',
	}
	if type(opt.headers) == "table" then
		for _, header in ipairs(opt.headers) do
			assert(lower(header[1]) ~= 'content-length', "please don't give Content-Length")
			assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
			insert(request, header[1]..': '..header[2]..CRLF)
		end
	end
	insert(request, CRLF)
	if type(opt.body) == "table" then
		local body = {}
		for _, b in ipairs(opt.body) do
			assert(#b == 2, "if BODY is TABLE, BODY need key[1]->value[2] (2 values)")
			insert(body, url_encode(b[1])..'='..url_encode(b[2]))
		end
		insert(request, concat(body, "&"))
		insert(request, #request - 2, fmt("Content-length: %s\r\n", #request[#request]))
	end
	if type(opt.body) == "string" then
		insert(request, #request, fmt("Content-length: %s\r\n", #opt.body))
		insert(request, opt.body)
	end
  return concat(request)
end

local function build_json_req (opt)
  local request = {
		fmt("POST %s HTTP/1.1", opt.path),
		fmt("Host: %s", opt.domain..':'..opt.port),
		'Accept: */*',
		'Accept-encoding: identity',
		"Connection: keep-alive",
		fmt("User-agent: %s", opt.server),
		fmt("Content-length: %s", #opt.json),
		'Content-Type: application/json',
	}
	if type(opt.headers) == "table" then
		for _, header in ipairs(opt.headers) do
			assert(lower(header[1]) ~= 'content-length', "please don't give Content-Length")
			assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
			insert(request, header[1]..': '..header[2])
		end
	end
	insert(request, CRLF)
  return concat(request, CRLF)..opt.json
end

local function build_file_req (opt)
  local request = {
    fmt("POST %s HTTP/1.1\r\n", opt.path),
    fmt("Host: %s\r\n", opt.domain..':'..opt.port),
    'Accept: */*\r\n',
    'Accept-Encoding: identity\r\n',
    fmt("Connection: keep-alive\r\n"),
    fmt("User-Agent: %s\r\n", opt.server),
  }

  if type(opt.headers) == "table" then
    for _, header in ipairs(opt.headers) do
      assert(lower(header[1]) ~= 'content-length', "please don't give Content-Length")
      assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
      insert(request, header[1]..': '..header[2]..'\r\n')
    end
  end

  if opt.files then
    local bd = random(1000000000, 9999999999)
    local boundary_start = fmt("------CFWebService%d", bd)
    local boundary_end   = fmt("------CFWebService%d--", bd)
    insert(request, fmt('Content-Type: multipart/form-data; boundary=----CFWebService%s\r\n', bd))
    local body = {}
    local header = ""
    for _, file in ipairs(opt.files) do
      insert(body, boundary_start)
      if file.name and file.filename then
        header = fmt(' name="%s"; filename="%s"', file.name, file.filename)
      end
      insert(body, fmt('Content-Disposition: form-data;%s', header))
      insert(body, fmt('Content-Type: %s\r\n', FILEMIME(file.type or '') or 'application/octet-stream'))
      insert(body, file.file)
    end
    body = concat(body, CRLF)
    insert(request, fmt("Content-length: %s\r\n", #body + 2 + #boundary_end))
    insert(request, CRLF)
    insert(request, body)
    insert(request, CRLF)
    insert(request, boundary_end)
  end
  return concat(request)
end

return {
  sock_new = sock_new,
  sock_recv = sock_recv,
  sock_send = sock_send,
  sock_connect = sock_connect,
  httpc_response = httpc_response,
  splite_protocol = splite_protocol,
  build_get_req = build_get_req,
  build_post_req = build_post_req,
  build_json_req = build_json_req,
  build_file_req = build_file_req,
}
