local system = require "system"
local now = system.now
local is_array_member = system.is_array_member

local cf = require "cf"
local cf_self = cf.self
local cf_fork = cf.fork
local cf_wait = cf.wait
local cf_wakeup = cf.wakeup

local ua = require "httpc.ua"
local protocol = require "httpc.protocol"
local sock_new = protocol.sock_new
local sock_send = protocol.sock_send
local sock_connect = protocol.sock_connect
local httpc_response = protocol.httpc_response
local splite_protocol = protocol.splite_protocol
local build_raw_req = protocol.build_raw_req
local build_get_req = protocol.build_get_req
local build_post_req = protocol.build_post_req
local build_json_req = protocol.build_json_req
local build_file_req = protocol.build_file_req
local build_put_req = protocol.build_put_req
local build_delete_req = protocol.build_delete_req
local build_basic_authorization = protocol.build_basic_authorization

local type = type
local assert = assert
local upper = string.upper

local __TIMEOUT__ = 15

local methods = {'get', 'post', 'json', 'file'}

local function raw( parameter )
	local opt, err = splite_protocol(parameter.domain)
	if not opt then
		return nil, err
	end

	local method = type(parameter.method) == 'string' and upper(parameter.method) or nil
	assert( method and (
			method == 'GET' or
			method == 'POST' or
			method == 'OPTIONS' or
			method == 'DELETE' or
			method == 'PUT'
		),"invalide http method.")

	-- GET方法禁止传递body
	if parameter.method == "GET" then
		parameter.body = nil
	end

	-- POST/PUT方法禁止传递args
	if parameter.method == "POST" or parameter.method == "PUT" or  parameter.method == "DELETE" then
		parameter.args = nil
	end

	opt.method = method
	opt.body = parameter.body
	opt.args = parameter.args
	opt.headers = parameter.headers

	local REQ = build_raw_req(opt)

	local sock = sock_new():timeout(parameter.timeout or __TIMEOUT__)
	if parameter.cert_path and parameter.key_path then
		sock:ssl_set_privatekey(parameter.key_path)
		sock:ssl_set_certificate(parameter.cert_path)
		if not sock:ssl_set_verify() then
			sock:close()
			return nil, "SSL privatekey and certfile verify failed."
		end
	end
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
	local code, msg, headers = httpc_response(sock, opt.protocol)
	sock:close()
	return code, msg, headers
end

-- HTTP GET
local function get(domain, headers, args, timeout)
	local opt, err = splite_protocol(domain)
	if not opt then
		return nil, err
	end

	opt.args = args
	opt.headers = headers
	opt.server = ua.get_user_agent()

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
	local code, msg, headers = httpc_response(sock, opt.protocol)
	sock:close()
	return code, msg, headers
end

-- HTTP POST
local function post(domain, headers, body, timeout)
	local opt, err = splite_protocol(domain)
	if not opt then
		return nil, err
	end

	opt.body = body
	opt.headers = headers
	opt.server = ua.get_user_agent()

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
	local code, msg, headers = httpc_response(sock, opt.protocol)
	sock:close()
	return code, msg, headers
end

-- HTTP DELETE
local function delete(domain, headers, body, timeout)

	local opt, err = splite_protocol(domain)
	if not opt then
		return nil, err
	end

	opt.body = body
	opt.headers = headers
	opt.server = ua.get_user_agent()

	local REQ = build_delete_req(opt)

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
	local code, msg, headers = httpc_response(sock, opt.protocol)
	sock:close()
	return code, msg, headers
end

-- HTTP PUT
local function put(domain, headers, body, timeout)

	local opt, err = splite_protocol(domain)
	if not opt then
		return nil, err
	end

	opt.body = body
	opt.headers = headers
	opt.server = ua.get_user_agent()

	local REQ = build_put_req(opt)

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
	local code, msg, headers = httpc_response(sock, opt.protocol)
	sock:close()
	return code, msg, headers
end

local function json(domain, headers, json, timeout)

	local opt, err = splite_protocol(domain)
	if not opt then
		return nil, err
	end

	assert(type(json) == "string" or type(json) == "table", "attempted passed a invalide json string or table.")

	opt.json = json
	opt.headers = headers
	opt.server = ua.get_user_agent()

	local REQ = build_json_req(opt)

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
	local code, msg, headers = httpc_response(sock, opt.protocol)
	sock:close()
	return code, msg, headers
end

local function file(domain, headers, files, timeout)

	local opt, err = splite_protocol(domain)
	if not opt then
		return nil, err
	end

	opt.files = files
	opt.headers = headers
	opt.server = ua.get_user_agent()

	local REQ = build_file_req(opt)

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
	local code, msg, headers = httpc_response(sock, opt.protocol)
	sock:close()
	return code, msg, headers
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
	raw = raw,
	get = get,
	post = post,
	delete = delete,
	json = json,
	file = file,
	put = put,
	multi_request = multi_request,
	basic_authorization = build_basic_authorization,
}
