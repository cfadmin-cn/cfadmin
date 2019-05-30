local class = require "httpc.class"

local protocol = require "httpc.protocol"
local sock_new = protocol.sock_new
local sock_recv = protocol.sock_recv
local sock_send = protocol.sock_send
local sock_connect = protocol.sock_connect
local httpc_response = protocol.httpc_response
local splite_protocol = protocol.splite_protocol
local build_get_req = protocol.build_get_req
local build_post_req = protocol.build_post_req
local build_json_req = protocol.build_json_req
local build_file_req = protocol.build_file_req

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

local SERVER = "cf/0.1"

local CRLF = '\x0d\x0a'
local CRLF2 = '\x0d\x0a\x0d\x0a'

local __TIMEOUT__ = 15

local httpc = {}

-- HTTP GET
function httpc.get(domain, headers, args, timeout)
	local opt, err = splite_protocol(domain)
	if not opt then
		return nil, err
	end

	opt.args = args
	opt.headers = headers
	opt.server = SERVER

	local REQ = build_get_req(opt)

	local sock = sock_new():timeout(timeout or __TIMEOUT__)
	local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
	if not ok then
		sock:close()
		return ok, err
	end
	local ok, err = sock_send(sock, opt.protocol, REQ)
	if not ok then
		sock:close()
		return ok, err
	end
	local code, msg = httpc_response(sock, opt.protocol)
	sock:close()
	return code, msg
end

-- HTTP POST
function httpc.post(domain, headers, body, timeout)
	local opt, err = splite_protocol(domain)
	if not opt then
		return nil, err
	end

	opt.body = body
	opt.headers = headers
	opt.server = SERVER

	local REQ = build_post_req(opt)

	local sock = sock_new():timeout(timeout or __TIMEOUT__)
	local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
	if not ok then
		sock:close()
		return ok, err
	end
	local ok, err = sock_send(sock, opt.protocol, REQ)
	if not ok then
		sock:close()
		return ok, err
	end
	local code, msg = httpc_response(sock, opt.protocol)
	sock:close()
	return code, msg
end

function httpc.json(domain, headers, json, timeout)

	local opt, err = splite_protocol(domain)
	if not opt then
		return nil, err
	end

	assert(type(json) == "string", "Please passed A vaild json string.")

	opt.json = json
	opt.headers = headers
	opt.server = SERVER

	local REQ = build_post_req(opt)

	local sock = sock_new():timeout(timeout or __TIMEOUT__)
	local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
	if not ok then
		sock:close()
		return ok, err
	end
	local ok, err = sock_send(sock, opt.protocol, REQ)
	if not ok then
		sock:close()
		return ok, err
	end
	local code, msg = httpc_response(sock, opt.protocol)
	sock:close()
	return code, msg
end

function httpc.file(domain, headers, files, times)

	local opt, err = splite_protocol(domain)
	if not opt then
		return nil, err
	end

	opt.files = files
	opt.headers = headers
	opt.server = SERVER

	local REQ = build_file_req(opt)

	local sock = sock_new():timeout(TIMEOUT or __TIMEOUT__)
	local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
	if not ok then
		sock:close()
		return ok, err
	end
	local ok, err = sock_send(sock, opt.protocol, REQ)
	if not ok then
		sock:close()
		return ok, err
	end
	local code, msg = httpc_response(sock, opt.protocol)
	sock:close()
	return code, msg
end

function httpc:new (...)
	return class:new(...)
end

return httpc
