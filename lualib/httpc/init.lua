local system = require "system"
local now = system.now
local is_array_member = system.is_array_member

local cf = require "cf"
local cf_self = cf.self
local cf_fork = cf.fork
local cf_wait = cf.wait
local cf_wakeup = cf.wakeup

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

local methods = {'get', 'post', 'json', 'file'}

-- HTTP GET
local function get(domain, headers, args, timeout)
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
local function post(domain, headers, body, timeout)
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

local function json(domain, headers, json, timeout)

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

local function file(domain, headers, files, times)

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

local function multi_request (opt)
	if type(opt) ~= 'table' then
    return nil, "1. 错误的参数类型"
  end
  local len = #opt
  if len > 0 then
    local co = cf_self()
    local response = {}
    local wakeuped = false
    for index = 1, len do
      cf_fork(function ()
				local t = now()
        local req = opt[index]
        -- 确认method
        local method = req.method and req.method:lower()
        if type(method) ~= 'string' or not is_array_member(methods, method) then
          response[index] = {nil, '不被支持的请求方法.', now() - t}
          if #response >= len and not wakeuped then
            wakeuped = true
            cf_wakeup(co, nil, response)
          end
          return
        end

				local code, msg
        if method == 'get' then
					code, msg = get(req.domain, req.headers, req.args, req.timeout)
        elseif method == 'post' then
          code, msg = post(req.domain, req.headers, req.body, req.timeout)
        elseif method == 'json' then
          code, msg = json(req.domain, req.headers, req.json, req.timeout)
        elseif method == 'file' then
          code, msg = file(req.domain, req.headers, req.files, req.timeout)
        end
				response[index] = {code, msg, now() - t}
				if #response >= len and not wakeuped then
					wakeuped = true
					cf_wakeup(co, true, response)
				end
				return
      end)
    end
    return cf_wait()
  end
  return nil, "2. 错误的参数"
end


return {
	get = get,
	post = post,
	json = json,
	file = file,
	multi_request = multi_request,
}
