local sys = require "sys"
local now = sys.now

local cf = require "cf"
local cf_join = cf.join

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
local build_xml_req = protocol.build_xml_req
local build_put_req = protocol.build_put_req
local build_delete_req = protocol.build_delete_req
local build_basic_authorization = protocol.build_basic_authorization

local type = type
local assert = assert
local lower = string.lower
local upper = string.upper
local tunpack = table.unpack
local tinsert = table.insert

local __TIMEOUT__ = 15

local methods = { get = true, post = true, put = true, delete = true, xml = true, json = true, file = true}

local function raw( parameter )
	local opt, err = splite_protocol(parameter.domain)
	if not opt then
		return nil, err
	end

	local method = assert(type(parameter.method) == 'string' and methods[lower(parameter.method)] and upper(parameter.method), "[HTTPC ERROR]: invalide http method.")
	parameter.method = method

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

---comment HTTP[S] `GET`请求方法
---@param domain   string                                   @合法的`http[s]`域名.
---@param headers  table<integer, table<integer, string>>   @合法的请求头部, 格式:`{ {"key1", "value1"}, ... }`.
---@param args     table<integer, table<integer, string>>   @合法的请求内容, 格式:`{ {"key1", "value1"}, ... }`.
---@param timeout  number																	  @此请求最长等待时间.
---@return integer			  																	@http协议请求状态码, 如果是连接失败或等待超时则为`nil`.
---@return string 																					@服务器的响应内容.
---@return table<string, string>            								@服务器的响应头部.
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

---comment HTTP[S] `POST`请求方法
---@param domain   string                                   @合法的`http[s]`域名.
---@param headers  table<integer, table<integer, string>>   @合法的请求头部, 格式:`{ {"key1", "value1"}, ... }`.
---@param body     table<integer, table<integer, string>>   @合法的请求内容, 格式:`{ {"key1", "value1"}, ... }`.
---@param timeout  number																	  @此请求最长等待时间.
---@return integer			  																	@http协议请求状态码, 如果是连接失败或等待超时则为`nil`.
---@return string 																					@服务器的响应内容.
---@return table<string, string>            								@服务器的响应头部.
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

---comment HTTP[S] `DELETE`请求方法
---@param domain   string                                   @合法的`http[s]`域名.
---@param headers  table<integer, table<integer, string>>   @合法的请求头部, 格式:`{ {"key1", "value1"}, ... }`.
---@param body     table<integer, table<integer, string>>   @合法的请求内容, 格式:`{ {"key1", "value1"}, ... }`.
---@param timeout  number																	  @此请求最长等待时间.
---@return integer			  																	@http协议请求状态码, 如果是连接失败或等待超时则为`nil`.
---@return string 																					@服务器的响应内容.
---@return table<string, string>            								@服务器的响应头部.
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

---comment HTTP[S] `PUT`请求方法
---@param domain   string                                   @合法的`http[s]`域名.
---@param headers  table<integer, table<integer, string>>   @合法的请求头部, 格式:`{ {"key1", "value1"}, ... }`.
---@param body     table<integer, table<integer, string>>   @合法的请求内容, 格式:`{ {"key1", "value1"}, ... }`.
---@param timeout  number																	  @此请求最长等待时间.
---@return integer			  																	@http协议请求状态码, 如果是连接失败或等待超时则为`nil`.
---@return string 																					@服务器的响应内容.
---@return table<string, string>            								@服务器的响应头部.
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

---comment HTTP[S] `POST`请求方法(使用`JSON`作为请求体)
---@param domain   string                                   @合法的`http[s]`域名.
---@param headers  table<integer, table<integer, string>>   @合法的请求头部, 格式:`{ {"key1", "value1"}, ... }`.
---@param json     table | string												    @可序列化的`table`或合法的`json`字符串.
---@param timeout  number																	  @此请求最长等待时间.
---@return integer			  																	@http协议请求状态码, 如果是连接失败或等待超时则为`nil`.
---@return string 																					@服务器的响应内容.
---@return table<string, string>            								@服务器的响应头部.
local function json(domain, headers, json, timeout)

	local opt, err = splite_protocol(domain)
	if not opt then
		return nil, err
	end

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

---comment HTTP[S] `POST`请求方法(使用`XML`作为请求体)
---@param domain   string                                   @合法的`http[s]`域名.
---@param headers  table<integer, table<integer, string>>   @合法的请求头部, 格式:`{ {"key1", "value1"}, ... }`.
---@param xml     table | string												    @可序列化的`table`或合法的`json`字符串.
---@param timeout  number																	  @此请求最长等待时间.
---@return integer			  																	@http协议请求状态码, 如果是连接失败或等待超时则为`nil`.
---@return string 																					@服务器的响应内容.
---@return table<string, string>            								@服务器的响应头部.
local function xml(domain, headers, xml, timeout)

	local opt, err = splite_protocol(domain)
	if not opt then
		return nil, err
	end

	opt.xml = xml
	opt.headers = headers
	opt.server = ua.get_user_agent()

	local REQ = build_xml_req(opt)

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

---comment HTTP[S] `POST`请求方法(使用`File`作为请求体)
---@param domain   string                                   @合法的`http[s]`域名.
---@param headers  table<integer, table<integer, string>>   @合法的请求头部, 格式:`{ {"key1", "value1"}, ... }`.
---@param files    table																    @合法的文件内容: { }
---@param timeout  number																	  @此请求最长等待时间.
---@return integer			  																	@http协议请求状态码, 如果是连接失败或等待超时则为`nil`.
---@return string 																					@服务器的响应内容.
---@return table<string, string>            								@服务器的响应头部.
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

local map = { get = get, post = post, delete = delete, json = json, xml = xml, file = file, put = put }

local function multi_request (list)
	if type(list) ~= 'table' or #list < 1 then
    return false, "[HTTPC ERROR]: Invalid request parameter."
  end
	local s = now()
	local response = {}
	local array = {}
	for index, req in ipairs(list) do
		local fn = map[req.method and lower(req.method)]
		if not fn then
			response[index] = {false, '[HTTPC ERROR]: Unsupported request method.', {}, now() - s}
		else
			tinsert(array, function ()
				local code, msg, headers = fn(req.domain, req.headers, req.args or req.body or req.json or req.xml or req.files, req.timeout)
				response[index] = {code, msg, headers, now() - s}
			end)
		end
	end
	cf_join(tunpack(array))
	return true, response
end


return {
	raw = raw,
	get = get,
	post = post,
	delete = delete,
	json = json,
	xml = xml,
	file = file,
	put = put,
	multi_request = multi_request,
	basic_authorization = build_basic_authorization,
}
