local log = require "log"
local json = require "json"
local crypt = require "crypt"
local co = require "internal.Co"
local tcp = require "internal.TCP"
local httpparser = require "httpparser"

local wbproto = require "protocol.websocket"
local _recv_frame = wbproto.recv_frame
local _send_frame = wbproto.send_frame

local json_encode = json.encode
local json_decode = json.decode

local sha1 = crypt.sha1
local base64 = crypt.base64encode

local co_self = co.self
local co_wait = co.wait
local co_spwan = co.spwan
local co_wakeup = co.wakeup

local REQUEST_PROTOCOL_PARSER = httpparser.parser_request_protocol
local RESPONSE_PROTOCOL_PARSER = httpparser.parser_response_protocol
local REQUEST_HEADER_PARSER = httpparser.parser_request_header
local RESPONSE_HEADER_PARSER = httpparser.parser_response_header

local type = type
local assert = assert
local setmetatable = setmetatable
local tostring = tostring
local next = next
local pcall = pcall
local ipairs = ipairs
local DATE = os.date
local time = os.time
local char = string.char
local lower = string.lower
local upper = string.upper
local match = string.match
local fmt = string.format
local toint = math.tointeger
local find = string.find
local split = string.sub
local splite = string.gmatch
local spliter = string.gsub
local insert = table.insert
local remove = table.remove
local concat = table.concat

local CRLF = '\r\n'
local CRLF2 = '\r\n\r\n'


local HTTP_CODE = {

	[100] = "HTTP/1.1 100 Continue",
	[101] = "HTTP/1.1 101 Switching Protocol",
	[102] = "HTTP/1.1 102 Processing",

	[200] = "HTTP/1.1 200 OK",
	[201] = "HTTP/1.1 201 Created",
	[202] = "HTTP/1.1 202 Accepted",
	[203] = "HTTP/1.1 203 Non-Authoritative Information",
	[204] = "HTTP/1.1 204 No Content",
	[205] = "HTTP/1.1 205 Reset Content",
	[206] = "HTTP/1.1 206 Partial Content",
	[207] = "HTTP/1.1 207 Multi-Status",
	[208] = "HTTP/1.1 208 Multi-Status",
	[226] = "HTTP/1.1 226 IM Used",

	[300] = "HTTP/1.1 300 Multiple Choice",
	[301] = "HTTP/1.1 301 Moved Permanently",
	[302] = "HTTP/1.1 302 Found",
	[303] = "HTTP/1.1 303 See Other",
	[304] = "HTTP/1.1 304 Not Modified",
	[305] = "HTTP/1.1 305 Use Proxy",
	[306] = "HTTP/1.1 306 unused",
	[307] = "HTTP/1.1 307 Temporary Redirect",
	[305] = "HTTP/1.1 308 Permanent Redirect",

	[400] = "HTTP/1.1 400 Bad Request",
	[401] = "HTTP/1.1 401 Unauthorized",
	[402] = "HTTP/1.1 402 Payment Required",
	[403] = "HTTP/1.1 403 Forbidden",
	[404] = "HTTP/1.1 404 Not Found",
	[405] = "HTTP/1.1 405 Method Not Allowed",
	[406] = "HTTP/1.1 406 Not Acceptable",
	[407] = "HTTP/1.1 407 Proxy Authentication Required",
	[408] = "HTTP/1.1 408 Request Timeout",
	[409] = "HTTP/1.1 409 Conflict",

	[410] = "HTTP/1.1 410 Gone",
	[411] = "HTTP/1.1 411 Length Required",
	[412] = "HTTP/1.1 412 Precondition Failed",
	[413] = "HTTP/1.1 413 Payload Too Large",
	[414] = "HTTP/1.1 414 URI Too Long",
	[415] = "HTTP/1.1 415 Unsupported Media Type",
	[416] = "HTTP/1.1 416 Requested Range Not Satisfiable",
	[417] = "HTTP/1.1 417 Expectation Failed",
	[418] = "HTTP/1.1 418 I'm a teapot",

	[421] = "HTTP/1.1 421 Misdirected Request",
	[422] = "HTTP/1.1 422 Unprocessable Entity (WebDAV)",
	[423] = "HTTP/1.1 423 Locked (WebDAV)",
	[424] = "HTTP/1.1 424 Failed Dependency",
	[426] = "HTTP/1.1 426 Upgrade Required",
	[428] = "HTTP/1.1 428 Precondition Required",
	[429] = "HTTP/1.1 429 Too Many Requests",
	[431] = "HTTP/1.1 431 Request Header Fields Too Large",
	[451] = "HTTP/1.1 451 Unavailable For Legal Reasons",

	[500] = "HTTP/1.1 500 Internal Server Error",
	[501] = "HTTP/1.1 501 Not Implemented",
	[502] = "HTTP/1.1 502 Bad Gateway",
	[503] = "HTTP/1.1 503 Service Unavailable",
	[504] = "HTTP/1.1 504 Gateway Timeout",
	[505] = "HTTP/1.1 505 HTTP Version Not Supported",
	[506] = "HTTP/1.1 506 Variant Also Negotiates",
	[507] = "HTTP/1.1 507 Insufficient Storage",
	[508] = "HTTP/1.1 508 Loop Detected (WebDAV)",
	[510] = "HTTP/1.1 510 Not Extended",
	[503] = "HTTP/1.1 511 Network Authentication Required",

}

local MIME = {
	-- 文本格式
	['htm']  = 'text/html',
	['html'] = 'text/html',
	['txt']  = 'text/plain',
	['css']  = 'text/css',
	['js']   = 'application/x-javascript',
	['json'] = 'application/json',
	-- 图片格式
	['bmp']  = 'image/bmp',
	['png']  = 'image/png',
	['gif']  = 'image/gif',
	['jpeg'] = 'image/jpeg',
	['jpg']  = 'image/jpeg',
	['ico']  = 'image/x-icon',
	['tif']  = 'image/tiff',
	['tiff'] = 'image/tiff',
	-- 其他格式
	-- TODO
}

local HTTP_PROTOCOL = {
	API = 1,
	[1] = "API",
	USE = 2,
	[2] = "USE",
	STATIC = 3,
	[3] = "STATIC",
	WS = 4,
	[4] = "WS",
}

-- 以下为 HTTP Client 所需所用方法
function HTTP_PROTOCOL.RESPONSE_HEADER_PARSER(header)
	return RESPONSE_HEADER_PARSER(header)
end

function HTTP_PROTOCOL.RESPONSE_PROTOCOL_PARSER(protocol)
	local VERSION, CODE, STATUS = RESPONSE_PROTOCOL_PARSER(protocol)
	return CODE
end

-- 以下为 HTTP Server 所需所用方法
local function REQUEST_STATUCODE_RESPONSE(code)
	return HTTP_CODE[code] or "attempt to Passed A Invaid Code to response message."
end

local function REQUEST_MIME_RESPONSE(mime)
	return MIME[mime] or MIME['html']
end

function HTTP_PROTOCOL.FILEMIME(mime)
	return MIME[mime]
end

-- 路由注册
local function ROUTE_REGISTERY(routes, route, class, type)
	if route == '' then
		return log.warn('Please Do not add empty string in route registery method :)')
	end
	if find(route, '//') then
		return log.warn('Please Do not add [//] in route registery method :)')
	end
	local fields = {}
	for field in splite(route, '/([^/?]*)') do
		insert(fields, field)
	end
	local t 
	for index, field in ipairs(fields) do
		if index == 1 then
			if routes[field] then
				t = routes[field]
				if #fields == index then
					break
				end
			else
				t = {}
				routes[field] = t
				if #fields == index then
					break
				end
			end
		else
			if t[field] then
				t = t[field]
				if #fields == index then
					break
				end
			else
				t[field] = {}
				t = t[field]
				if #fields == index then
					break
				end
			end
		end
	end
	t.route = route
	t.class = class
	t.type = type
end
HTTP_PROTOCOL.ROUTE_REGISTERY = ROUTE_REGISTERY

-- 路由查找
local function ROUTE_FIND(routes, route)
	local fields = {}
	for field in splite(route, '/([^/?]*)') do
		insert(fields, field)
	end
	local t, class, typ
	for index, field in ipairs(fields) do
		if index == 1 then
			if not routes[field] then
				break
			end
			t = routes[field]
			if #fields == index and t.class then
				typ = t.type
				class = t.class
				break
			end
			if t.type == HTTP_PROTOCOL.STATIC then
				typ = t.type
				class = t.class
				break
			end
		else
			if not t[field] then
				break
			end
			t = t[field]
			if #fields == index and t.class then
				typ = t.type
				class = t.class
				break
			end
		end
	end
	return class, typ
end
HTTP_PROTOCOL.ROUTE_FIND = ROUTE_FIND

local function HTTP_DATE(timestamp)
	if not timestamp then
		return DATE("%a, %d %b %Y %X GMT")
	end
	return DATE("%a, %d %b %Y %X GMT", timestamp)
end

local function PASER_METHOD(http, sock, buffer, METHOD, PATH, HEADER)
	local ARGS, FILE
	if METHOD == "HEAD" or METHOD == "GET" then
		local spl_pos = find(PATH, '%?')
		if spl_pos and spl_pos < #PATH then
			for key, value in splite(PATH, '([^%?&]*)=([^%?&]*)') do
				if not ARGS then
					ARGS = {}
				end
				ARGS[key] = value
			end
		end
	elseif METHOD == "POST" then
		local body_len = toint(HEADER['Content-Length'])
		local BODY = ''
		local RECV_BODY = true
		local CRLF_START, CRLF_END = find(buffer, '\r\n\r\n')
		if #buffer > CRLF_END then
			BODY = split(buffer, CRLF_END + 1, -1)
			if #BODY == body_len then
				RECV_BODY = false
			end
		end
		if RECV_BODY then
			local buffers = {BODY}
			while 1 do
				local buf = sock:recv(8192)
				if not buf then
					return
				end
				insert(buffers, buf)
				local buffer = concat(buffers)
				if #buffer == body_len then
					BODY = buffer
					break
				end
			end
		end
		if HEADER['Content-Type'] then
			local JSON_ENCODE = 'application/json'
			local FILE_ENCODE = 'multipart/form-data'
			local URL_ENCODE = 'application/x-www-form-urlencoded'
			local format = match(HEADER['Content-Type'], '(.-/[^;]*)')
			if format == FILE_ENCODE then
				local BOUNDARY = match(HEADER['Content-Type'], '^.+=[%-]*(.+)')
				if BOUNDARY and BOUNDARY ~= '' then
					FILE = {}
					for file in splite(BODY, '\r\n\r\n(.-)\r\n[%-]*'..BOUNDARY) do
						insert(FILE, file)
					end
				end
			elseif format == JSON_ENCODE then
				local ok, args = pcall(json_decode, BODY)
				if ok then
					ARGS = args
				end
			elseif format == URL_ENCODE then
				for key, value in splite(BODY, '([^%?&]*)=([^%?&]*)') do
					if not ARGS then
						ARGS = {}
					end
					ARGS[key] = value
				end
			end
		end
	else
		-- 暂未支持其他方法
		return
	end
	return true, ARGS, FILE
end

-- 一些错误返回
local function ERROR_RESPONSE(http, code, path, ip)
	http:tolog(code, path, ip)
	return concat({
		REQUEST_STATUCODE_RESPONSE(code),
		'Date: ' .. HTTP_DATE(),
		'Allow: GET, POST, HEAD',
		'Access-Control-Allow-Origin: *',
		'Connection: close',
		'server: ' .. (http.server or 'cf/0.1'),
	}, CRLF) .. CRLF2
end

-- WebSocket
local function Switch_Protocol(http, cls, sock, header, method, version, path, ip)
	if version ~= 1.1 then
		sock:send(ERROR_RESPONSE(http, 505, path, ip))
		sock:close()
		return
	end
	if method ~= 'GET' then
		sock:send(ERROR_RESPONSE(http, 405, path, ip))
		sock:close()
		return
	end
	if header['Connection'] ~= 'Upgrade' then
		sock:send(ERROR_RESPONSE(http, 406, path, ip))
		sock:close()
		return
	end
	if not header['Upgrade'] or lower(header['Upgrade']) ~= 'websocket' then
		sock:send(ERROR_RESPONSE(http, 406, path, ip))
		sock:close()
		return
	end
	if header['Sec-WebSocket-Version'] ~= '13' then
		sock:send(ERROR_RESPONSE(http, 505, path, ip))
		sock:close()
		return
	end
	local sec_key = header['Sec-WebSocket-Key']
	if not sec_key or sec_key == '' then
		sock:send(ERROR_RESPONSE(http, 505, path, ip))
		sock:close()
		return
	end
	local ok = sock:send(concat({
			REQUEST_STATUCODE_RESPONSE(101),
			'Connection: Upgrade',
			'Server: '..(http.server or 'cf/0.1'),
			'Upgrade: WebSocket',
			'Sec-WebSocket-Accept: '..base64(sha1(sec_key..'258EAFA5-E914-47DA-95CA-C5AB0DC85B11')),
			CRLF
	}, CRLF))
	if not ok then
		return sock:close() 
	end
	local ok, c = pcall(cls.new, cls)
	if not ok then
		sock:send(ERROR_RESPONSE(http, 500, path, ip))
		sock:close()
		return
	end
	sock._timeout = c.timeout
	local send_masked = c.sen_masked
	local max_payload_len = c.max_payload_len or 65535
	local on_open = assert(type(c.on_open) == 'function' and c.on_open, "Can't find websocket on_open method")
	local on_message = assert(type(c.on_message) == 'function' and c.on_message, "Can't find websocket on_message method")
	local on_error = assert(type(c.on_error) == 'function' and c.on_error, "Can't find websocket on_error method")
	local on_close = assert(type(c.on_close) == 'function' and c.on_close, "Can't find websocket on_close method")
	local on_ping = c.on_ping
	local on_pong = c.on_pong

	local current_co = co_self()
	local write_co
	local Continue = true

	local write_list = {}
	local websocket = setmetatable({}, { __name = "WebSocket", __index = function (t, key)
		return function(data, binary)
			if not Continue then return end -- 如果已经发送了close则不允许再发送任何协议
			if key == 'ping' then
				write_list[#write_list + 1] = function() _send_frame(sock, true, 0x9, data, max_payload_len, send_masked) end
			elseif key == "pong" then
				write_list[#write_list + 1] = function() _send_frame(sock, true, 0xa, data, max_payload_len, send_masked) end
			elseif key == 'send' then
				if data and type(data) == 'string' then
					local code = 0x1
					if binary then
						code = 0x2
					end
					write_list[#write_list + 1] = function () _send_frame(sock, true, code, data, max_payload_len, send_masked) end
				end
			elseif key == "close" then
				Continue = nil
				write_list[#write_list + 1] = function() _send_frame(sock, true, 0x8, char(((1000 >> 8) & 0xff), (1000 & 0xff))..(data or ""), max_payload_len, send_masked) end
			end
			if write_co then
				co_wakeup(write_co)
			end
		end
	end})
	local ok, err = pcall(on_open, c, websocket)
	if not ok then
		log.error(err)
		return sock:close()
	end
	co_spwan(function (...)
		local sock = sock
		write_co = co_self()
		while 1 do
			for index, f in ipairs(write_list) do
				local ok, err = pcall(f)
				if not ok then
					log.error(err)
				end
			end
			write_list = {}
			if not Continue then
				write_co = nil
				write_list = nil
				return sock:close()
			end
			co_wait()
		end
	end)

	while 1 do
		local data, typ, err =_recv_frame(sock, max_payload_len, true)
		if (not data and not typ) or typ == 'close' then
			if err and err ~= 'read timeout' then
				local ok, err = pcall(on_error, c, websocket, err)
				if not ok then
					log.error(err)
				end
			end
			local ok, err = pcall(on_close, c, websocket, data)
			if not ok then
				log.error(err)
			end
			if write_co then
				Continue = nil
				co_wakeup(write_co)
			end
			return
		end
		if typ == 'ping' then
			if not on_ping then 
				write_list[#write_list + 1] = {f = websocket.pong(data)} 
			else
				co_spwan(on_ping, c, websocket, data, typ == 'binary')
			end
		elseif typ == 'pong' then
			if on_open then
				co_spwan(on_pong, c, websocket, data, typ == 'binary')
			end
		elseif typ == 'text' or typ == 'binary' then
			co_spwan(on_message, c, websocket, data, typ == 'binary')
		else -- 其他情况与不支持的协议什么都不做.
		end
	end
end

function HTTP_PROTOCOL.EVENT_DISPATCH(fd, ipaddr, http)
	local buffers = {}
	local timeout = http.timeout
	local routes = http.routes
	local server = http.server
	local host = http.host
	local ttl = http.ttl
	local sock = tcp:new():set_fd(fd):timeout(timeout or 15)
	while 1 do
		local buf = sock:recv(8192)
		if not buf then
			return sock:close()
		end
		insert(buffers, buf)
		local buffer = concat(buffers)
		local CRLF_START, CRLF_END = find(buffer, CRLF2)
		if CRLF_START and CRLF_END then
			local PROTOCOL_START, PROTOCOL_END = find(buffer, CRLF)
			local METHOD, PATH, VERSION = REQUEST_PROTOCOL_PARSER(buffer)
			-- 协议有问题返回400
			if not METHOD or not PATH or not VERSION then
				sock:send(ERROR_RESPONSE(http, 400, PATH, ipaddr))
				sock:close()
				return 
			end
			-- 没有HEADER返回400
			local HEADER = REQUEST_HEADER_PARSER(buffer)
			if not HEADER then
				sock:send(ERROR_RESPONSE(http, 400, PATH, ipaddr))
				sock:close()
				return 
			end
			-- 这里根据PATH先查找路由, 如果没有直接返回404.
			local cls, typ = ROUTE_FIND(routes, PATH)
			if not cls or not typ then
				sock:send(ERROR_RESPONSE(http, 404, PATH, HEADER['X-Real-IP'] or ipaddr))
				sock:close()
				return 
			end
			-- 根据请求方法进行解析, 解析失败返回501
			local ok, ARGS, FILE = PASER_METHOD(http, sock, buffer, METHOD, PATH, HEADER)
			if not ok then
				sock:send(ERROR_RESPONSE(http, 501, PATH, HEADER['X-Real-IP'] or ipaddr))
				sock:close()
				return 
			end
			local header = { }

			local ok, data, static, statucode

			if typ == HTTP_PROTOCOL.API or typ == HTTP_PROTOCOL.USE then
				local c = cls:new({args = ARGS, file = FILE, method = METHOD, path = PATH, header = HEADER})
				ok, data = pcall(c[c.__name], c)
				if not ok then
					log.error(data)
					statucode = 500
					sock:send(ERROR_RESPONSE(http, statucode, PATH, HEADER['X-Real-IP'] or ipaddr))
					sock:close()
					return 
				end
				statucode = 200
				insert(header, REQUEST_STATUCODE_RESPONSE(statucode))
			elseif typ == HTTP_PROTOCOL.WS then
				return Switch_Protocol(http, cls, sock, HEADER, METHOD, VERSION, PATH, HEADER['X-Real-IP'] or ipaddr)
			else
				local file_type
				local path = PATH
				local pos, _ = find(PATH, '%?')
				if pos then
					path = split(path, 1, pos - 1)
				end
				ok, data, file_type = pcall(cls, './'..path)
				if not ok then
					log.error(data)
					statucode = 500
					sock:send(ERROR_RESPONSE(http, statucode, PATH, HEADER['X-Real-IP'] or ipaddr))
					sock:close()
					return
				end
				if not data then
					statucode = 404
					sock:send(ERROR_RESPONSE(http, statucode, PATH, HEADER['X-Real-IP'] or ipaddr))
					sock:close()
					return
				else
					statucode = 200
					insert(header, REQUEST_STATUCODE_RESPONSE(statucode))
					static = fmt('Content-Type: %s', REQUEST_MIME_RESPONSE(lower(file_type or '')))
				end
			end

			insert(header, 'Date: ' .. HTTP_DATE())
			insert(header, 'Accept-Ranges: none')
			insert(header, 'Allow: GET, POST, HEAD')
			insert(header, fmt('Access-Control-Allow-Origin: %s', host or "*"))
			insert(header, 'Access-Control-Allow-Methods: GET, POST, HEAD')
			insert(header, 'server: ' .. (server or 'cf/0.1'))

			local Connection = 'Connection: keep-alive'
			if not HEADER['Connection'] or lower(HEADER['Connection']) == 'close' then
				Connection = 'Connection: close'
			end
			insert(header, Connection)
			if typ == HTTP_PROTOCOL.API then
				insert(header, 'Content-Type: '..REQUEST_MIME_RESPONSE('json'))
				insert(header, 'Cache-Control: no-cache, no-store, must-revalidate')
				insert(header, 'Cache-Control: no-cache')
			elseif typ == HTTP_PROTOCOL.USE and METHOD == "GET" then
				insert(header, 'Content-Type: '..REQUEST_MIME_RESPONSE('html')..';charset=utf-8')
				insert(header, 'Cache-Control: no-cache, no-store, must-revalidate')
				insert(header, 'Cache-Control: no-cache')
			else
				if ttl then
					cache = fmt('Expires: %s', HTTP_DATE(time() + ttl))
				end
				insert(header, static)
			end
			if not data and type(data) ~= 'string' then
				statucode = 500
				sock:send(ERROR_RESPONSE(http, statucode, PATH, HEADER['X-Real-IP'] or ipaddr))
				sock:close()
				return
			end
			insert(header, 'Transfer-Encoding: identity')
			insert(header, fmt('Content-Length: %d', #data))
			http:tolog(statucode, PATH, HEADER['X-Real-IP'] or ipaddr)
			sock:send(concat(header, CRLF) .. CRLF2 .. (data or ''))
			if statucode ~= 200 or Connection ~= 'Connection: keep-alive' then
				return sock:close()
			end
			buffers = {}
		end
	end
end

return HTTP_PROTOCOL