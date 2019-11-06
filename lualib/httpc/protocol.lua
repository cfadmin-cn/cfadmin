local tcp = require "internal.TCP"

local lz = require"lz"
local uncompress = lz.uncompress
local gzuncompress = lz.gzuncompress

local new_tab = require "sys".new_tab

local json = require "json"
local json_encode = json.encode

local crypt = require "crypt"
local url_encode = crypt.urlencode
local hmac_sha256 = crypt.hmac_sha256
local base64encode = crypt.base64encode
local base64urlencode = crypt.base64urlencode

local HTTP_PARSER = require "protocol.http.parser"
local FILEMIME = require "protocol.http.mime"
local PARSER_HTTP_RESPONSE = HTTP_PARSER.PARSER_HTTP_RESPONSE
local RESPONSE_CHUNKED_PARSER = HTTP_PARSER.RESPONSE_CHUNKED_PARSER

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
	local content = new_tab(8, 0)
	local times = 0
	while 1 do
		local data, len = sock_recv(sock, SSL, 4096)
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
      local Content_Encoding = HEADER['Content-Encoding'] or HEADER['content-encoding']
      local Content_Length = toint(HEADER['Content-Length'] or HEADER['content-length'])
      local Chunked = HEADER['Transfer-Encoding'] or HEADER['transfer-encoding']
      if not Content_Length and not Chunked then
        return nil, "Unsupported response body parsing."
      end
			if Content_Length then
				if (#DATA - posB) == Content_Length then
          local res = split(DATA, posB + 1, #DATA)
          if Content_Encoding == "gzip" then
            res = gzuncompress(res)
          end
					return CODE, res
				end
        local content = new_tab(8, 0)
				content[#content+1] = split(DATA, posB + 1, #DATA)
        local Len = #content[1]
				while 1 do
					local data, len = sock_recv(sock, SSL, 65535)
					if not data then
						return nil, SSL.."[Content_Length] A peer of remote server close this connection."
					end
					insert(content, data)
          Len = Len + len
          if Len >= Content_Length then
            local res = concat(content)
            if Content_Encoding == "gzip" then
              res = gzuncompress(res)
            end
            return CODE, res
          end
				end
			end
			if Chunked and Chunked == "chunked" then
				local content = new_tab(8, 0)
				if #DATA > posB then
          local buf = split(DATA, posB + 1, #DATA)
          data, len = RESPONSE_CHUNKED_PARSER(buf)
          if len == -1 then
            return nil, SSL.." 错误的http trunked. 1"
          end
          if data then
            local Pos = find(data, CRLF..(0)..CRLF2)
            local res = split(data, 1,  Pos and Pos - #CRLF2 - 1 or -1)
            if Content_Encoding == "gzip" then
              res = gzuncompress(res)
            end
            return CODE, res
          end
          insert(content, buf)
				end
				while 1 do
					local data, len = sock_recv(sock, SSL, 65535)
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
            local res = split(data, 1,  Pos and Pos - #CRLF2 - 1 or -1)
            if Content_Encoding == "gzip" then
              res = gzuncompress(res)
            end
            return CODE, res
          end
        end
			end
		end
	end
end


local function build_get_req (opt)
  local request = new_tab(16, 0)
  insert(request, fmt("GET %s HTTP/1.1", opt.path))
  insert(request, fmt("Host: %s", (opt.port == 80 or opt.port == 443) and opt.domain or opt.domain..':'..opt.port))
  insert(request, fmt("User-Agent: %s", opt.server))
  insert(request, 'Accept: */*')
  insert(request, 'Accept-Encoding: gzip, identity')
  insert(request, 'Connection: keep-alive')
  if type(opt.args) == "table" then
    local args = new_tab(8, 0)
    for _, arg in ipairs(opt.args) do
      assert(#arg == 2, "args need key[1]->value[2] (2 values and must be string)")
      insert(args, url_encode(arg[1])..'='..url_encode(arg[2]))
    end
    request[1] = fmt("GET %s HTTP/1.1", opt.path..'?'..concat(args, "&"))
  end
  if type(opt.headers) == "table" then
    for _, header in ipairs(opt.headers) do
      assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
      insert(request, header[1]..': '..header[2])
    end
  end
  insert(request, CRLF)
  return concat(request, CRLF)
end

local function build_post_req (opt)
  local request = new_tab(16, 0)
  insert(request, fmt("POST %s HTTP/1.1\r\n", opt.path))
  insert(request, fmt("Host: %s\r\n", (opt.port == 80 or opt.port == 443) and opt.domain or opt.domain..':'..opt.port))
  insert(request, fmt("User-Agent: %s\r\n", opt.server))
  insert(request, 'Accept: */*\r\n')
  insert(request, 'Accept-Encoding: gzip, identity\r\n')
  insert(request, 'Connection: keep-alive\r\n')
  if type(opt.headers) == "table" then
    for _, header in ipairs(opt.headers) do
      assert(lower(header[1]) ~= 'content-length', "please don't give Content-Length")
      assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
      insert(request, header[1] .. ': ' .. header[2] .. CRLF)
    end
  end
  insert(request, CRLF)
  if type(opt.body) == "table" then
    local body = new_tab(8, 0)
    for _, item in ipairs(opt.body) do
      assert(#item == 2, "if BODY is TABLE, BODY need key[1]->value[2] (2 values)")
      insert(body, url_encode(item[1])..'='..url_encode(item[2]))
    end
    local Body = concat(body, "&")
    insert(request, #request, fmt('Content-Length: %s\r\n', #Body))
    insert(request, #request, 'Content-Type: application/x-www-form-urlencoded\r\n')
    insert(request, Body)
  end
  return concat(request)
end

local function build_delete_req (opt)
  local request = new_tab(16, 0)
  insert(request, fmt("DELETE %s HTTP/1.1", opt.path))
  insert(request, fmt("Host: %s", (opt.port == 80 or opt.port == 443) and opt.domain or opt.domain..':'..opt.port))
  insert(request, fmt("User-Agent: %s", opt.server))
  insert(request, 'Accept: */*')
  insert(request, 'Accept-Encoding: gzip, identity')
  insert(request, 'Connection: keep-alive')
  if type(opt.headers) == "table" then
    for _, header in ipairs(opt.headers) do
      assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
      insert(request, header[1]..': '..header[2])
    end
  end
  if type(opt.body) == "string" and opt.body ~= '' then
    insert(request, fmt("Content-Length: %s", #opt.body))
  end
  return concat(request, CRLF) .. CRLF2 .. ( type(opt.body) == "string" and opt.body or '' )
end

local function build_json_req (opt)
  local request = new_tab(16, 0)
  insert(request, fmt("POST %s HTTP/1.1", opt.path))
  insert(request, fmt("Host: %s", (opt.port == 80 or opt.port == 443) and opt.domain or opt.domain..':'..opt.port))
  insert(request, fmt("User-Agent: %s", opt.server))
  insert(request, 'Accept: */*')
  insert(request, 'Accept-Encoding: gzip, identity')
  insert(request, 'Connection: keep-alive')
	if type(opt.headers) == "table" then
    for _, header in ipairs(opt.headers) do
      assert(lower(header[1]) ~= 'content-length', "please don't give Content-Length")
      assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
      insert(request, header[1]..': '..header[2])
    end
  end
  if type(opt.json) == 'string' and opt.json ~= '' then
    insert(request, 'Content-Type: application/json')
    insert(request, fmt("Content-Length: %s", #opt.json))
  end
  return concat(request, CRLF) .. CRLF2 .. opt.json
end

local function build_file_req (opt)
  local request = new_tab(16, 0)
  insert(request, fmt("POST %s HTTP/1.1\r\n", opt.path))
  insert(request, fmt("Host: %s\r\n", (opt.port == 80 or opt.port == 443) and opt.domain or opt.domain..':'..opt.port))
  insert(request, fmt("User-Agent: %s\r\n", opt.server))
  insert(request, 'Accept: */*\r\n')
  insert(request, 'Accept-Encoding: gzip, identity\r\n')
  insert(request, 'Connection: keep-alive\r\n')
  if type(opt.headers) == "table" then
    for _, header in ipairs(opt.headers) do
      assert(lower(header[1]) ~= 'content-length', "please don't give Content-Length")
      assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
      insert(request, header[1]..': '..header[2]..'\r\n')
    end
  end

  if type(opt.files) == 'table' then
    local bd = random(1000000000, 9999999999)
    local boundary_start = fmt("------CFWebService%d", bd)
    local boundary_end   = fmt("------CFWebService%d--", bd)
    insert(request, fmt('Content-Type: multipart/form-data; boundary=----CFWebService%s\r\n', bd))
    local body = new_tab(16, 0)
    local cd = 'Content-Disposition: form-data; %s'
    local ct = 'Content-Type: %s'
    for index, file in ipairs(opt.files) do
      assert(file.file, "files index : [" .. index .. "] unknown multipart/form-data content.")
      insert(body, boundary_start)
      local name = file.name
      local filename = file.filename
      if not file.type then
        if type(name) ~= 'string' or name == '' then
          name = ''
        end
        insert(body, fmt(cd, fmt('name="%s"', name)) .. CRLF)
      else
        if type(name) ~= 'string' or name == '' then
          name = ''
        end
        if type(filename) ~= 'string' or filename == '' then
          filename = ''
        end
        insert(body, fmt(cd, fmt('name="%s"', name) .. '; ' .. fmt('filename="%s"', filename)))
        insert(body, fmt(ct, FILEMIME[file.type or ''] or 'application/octet-stream') .. CRLF)
      end
      insert(body, file.file)
    end
    insert(body, boundary_end)
    body = concat(body, CRLF)
    insert(request, fmt("Content-Length: %s\r\n\r\n", #body))
    insert(request, body)
  end
  return concat(request)
end

local function build_put_req (opt)
  local request = new_tab(16, 0)
  insert(request, fmt("PUT %s HTTP/1.1", opt.path))
  insert(request, fmt("Host: %s", (opt.port == 80 or opt.port == 443) and opt.domain or opt.domain..':'..opt.port))
  insert(request, fmt("User-Agent: %s", opt.server))
  insert(request, 'Accept: */*')
  insert(request, 'Accept-Encoding: gzip, identity')
  insert(request, 'Connection: keep-alive')
  if type(opt.headers) == "table" then
    for _, header in ipairs(opt.headers) do
      assert(lower(header[1]) ~= 'content-length', "please don't give Content-Length")
      assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
      insert(request, header[1]..': '..header[2])
    end
  end
  if type(opt.body) == "string" and opt.body ~= '' then
    insert(request, fmt("Content-Length: %s", #opt.body))
  end
  return concat(request, CRLF) .. CRLF2 .. ( type(opt.body) == "string" and opt.body or '' )
end

-- http base authorization
local function build_basic_authorization(username, password)
  return "Authorization", "Basic " .. base64encode(username .. ":" .. password)
end

-- Json Web Token
local function build_jwt(secret, payload)
  local content = new_tab(3, 0)
  -- header
  content[#content + 1] = base64urlencode(json_encode{ alg = "HS256", typ = "JWT" })
  -- payload
  content[#content + 1] = base64urlencode(payload)
  -- signature
  content[#content + 1] = hmac_sha256(secret, concat(content, "."), true)
  -- result.
  return "Authorization", "Bearer " .. concat(content, ".")
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
  build_put_req = build_put_req,
  build_delete_req = build_delete_req,
  build_jwt = build_jwt,
  build_basic_authorization = build_basic_authorization,
}
