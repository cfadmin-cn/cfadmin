require "utils"
local xpcall = xpcall
local tostring = tostring
local spliter = string.gsub
local match = string.match
local fmt = string.format
local int = math.integer
local find = string.find
local split = string.sub
local insert = table.insert
local remove = table.remove
local concat = table.concat


local CRLF = "\r\n"
local CRLF2 = "\r\n\r\n"


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
	['jpg']  = 'image/jpg',
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
}


local function safe_call(func, ...)
	local function log(e)
		return debug.traceback(0)..tostring(e)
	end
	return xpcall(func, log, ...)
end

function HTTP_PROTOCOL.RESPONSE_HEAD_PARSER(head)
	local HEADER = {}
	spliter(head, "(.-): (.-)\r\n", function (key, value)
		if key == 'Content-Length' then
			HEADER['Content-Length'] = tonumber(value)
			return
		end
		HEADER[key] = value
	end)
	return HEADER
end

function HTTP_PROTOCOL.RESPONSE_PROTOCOL_PARSER(protocol)
	local VERSION, CODE, STATUS = match(protocol, "HTTP/([%d%.]+) (%d+) (.+)\r\n")
	return tonumber(CODE)
end


local function REQUEST_STATUCODE_RESPONSE(code)
	return HTTP_CODE[code] or "attempt to Passed A Invaid Code to response message."
end

local function REQUEST_MIME_RESPONSE(mime)
	return MIME[mime] or MIME['html']
end


local function REQUEST_HEADER_PARSER(head)
	local HEADER = {}
	spliter(head, "(.-): (.-)\r\n", function (key, value)
		HEADER[key] = value
	end)
	return HEADER
end

local function REQUEST_PROTOCOL_PARSER(protocol)
	return match(protocol, "(%w+) (.+) HTTP/([%d%.]+)\r\n")
end

function HTTP_PROTOCOL.ROUTE_REGISTERY(routes, route, class, type)
	local fields = {}
	spliter(route, "/([^/?]*)", function (field)
		insert(fields, field)
	end)
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
	return
end

function HTTP_PROTOCOL.ROUTE_FIND(routes, route)
	local fields = {}
	spliter(route, "/([^/?]*)", function (field)
		insert(fields, field)
	end)
	local t, class, type
	for index, field in ipairs(fields) do
		if index == 1 then
			if not routes[field] then
				break
			end
			t = routes[field]
			if #fields == index and t.class then
				type = t.type
				class = t.class
				break
			end
		else
			if not t[field] then
				break
			end
			t = t[field]
			if #fields == index and t.class then
				type = t.type
				class = t.class
				break
			end
		end
	end
	return class, type
end


function HTTP_PROTOCOL.REQUEST_PASER(sock, http)
	local buffers = {}
	while 1 do
		local buf = sock:recv(4096)
		if not buf then
			return
		end
		insert(buffers, buf)
		local buffer = concat(buffers)
		local CRLF_START, CRLF_END = find(buffer, CRLF2)
		if CRLF_START and CRLF_END then
			local REQ = {}
			local PROTOCOL_START, PROTOCOL_END = find(buffer, CRLF)
			local METHOD, PATH, VERSION = REQUEST_PROTOCOL_PARSER(split(buffer, 1, PROTOCOL_END))
			if not METHOD or not PATH or not VERSION then
				return concat({REQUEST_STATUCODE_RESPONSE(400)}, CRLF) .. CRLF2
			end
			REQ['METHOD'], REQ["PATH"], REQ['VERSION'] = METHOD, PATH, VERSION
			REQ['HEADER'] = REQUEST_HEADER_PARSER(split(buffer, PROTOCOL_END + 1, CRLF_START + 2))
			if REQ['METHOD'] == "GET" then
				local spl_pos = find(REQ['PATH'], '?')
				if spl_pos < #REQ['PATH'] then
					REQ['ARGS'] = {}
					spliter(REQ['PATH'], '([^%?&]*)=([^%?&]*)', function (key, value)
						REQ['ARGS'][key] = value
					end)
				end
			else
				local body_len = tonumber(REQ['HEADER']['Content-Length'])
				local BODY = ''
				local RECV_BODY = true
				if #buffer > CRLF_END then
					BODY = split(buffer, CRLF_END + 1, -1)
					if #BODY == body_len then
						RECV_BODY = false
						REQ['BODY'] = BODY
					end
				end
				if RECV_BODY then
					buffers = {BODY}
					while 1 do
						local buf = sock:recv(4096)
						if not buf then
							return
						end
						insert(buffers, buf)
						local buffer = concat(buffers)
						if #buffer == body_len then
							REQ['BODY'] = buffer
							break
						end
					end
				end
				if REQ['HEADER']['Content-Type'] then
					if REQ['HEADER']['Content-Type'] == "application/x-www-form-urlencoded" then
						REQ['ARGS'] = {}
						spliter(BODY, '([^%?&]*)=([^%?&]*)', function (key, value)
							REQ['ARGS'][key] = value
						end)
					end
				end
			end
			var_dump(REQ)
			buffers = {}
			local class, typ = HTTP_PROTOCOL.ROUTE_FIND(http.routes, REQ['PATH'])
			if not class or not typ then
				return concat({REQUEST_STATUCODE_RESPONSE(404)}, CRLF) .. CRLF2
			end
			local cls = class:new()
			local ok, data = safe_call(cls, table.unpack({}))
			if not ok then
				print(data)
				return concat({REQUEST_STATUCODE_RESPONSE(500)}, CRLF)  .. CRLF2
			end
			local header = {REQUEST_STATUCODE_RESPONSE(200)}
			insert(header, fmt("server: %s", http.server or "cf/0.1"))
			insert(header, 'Accept: text/html,application/json')

			local Connection = "Connection: close"
			if tonumber(VERSION) == 'number' and tonumber(VERSION) == 1.1 then
				Connection = 'Connection: keep-alive'
			end
			insert(header, Connection)
			if typ == HTTP_PROTOCOL.API then
				insert(header, fmt('Content-Type: %s', REQUEST_MIME_RESPONSE('json')))
				insert(header, 'Cache-Control: no-cache')
			elseif typ == HTTP_PROTOCOL.USE then
				insert(header, fmt('Content-Type: %s', REQUEST_MIME_RESPONSE('html')) .. ';charset=utf-8')
				insert(header, 'Cache-Control: no-cache')
			end
			if data and type(data) == 'string' and #data > 0 then
				insert(header, fmt('Content-Length: %d', #data))
			end
			sock:send(concat(header, CRLF) .. CRLF2 .. data or '')
		end
	end
end


return HTTP_PROTOCOL