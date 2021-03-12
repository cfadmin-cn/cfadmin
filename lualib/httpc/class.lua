local hc = require "httpc"
local hc_multi_request = hc.multi_request

local class = require "class"

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
local tonumber = tonumber

local upper = string.upper

local httpc = class("httpc")

function httpc:ctor (opt)
  self.reconnect = true
  self.timeout = opt.timeout or 15
  self.server = ua.get_user_agent()
end

function httpc:basic_authorization( ... )
  return build_basic_authorization(...)
end

-- 设置超时时间
function httpc:set_timeout(timeout)
  if tonumber(timeout) and tonumber(timeout) > 0 then
    self.timeout = tonumber(timeout)
    return self
  end
end

-- 添加外置socket
function httpc:set_socket(sock)
  if type(sock) == 'table' then
    self.sock = sock
    return self
  end
end

-- 关闭重试
function httpc:disable_reconnect()
  self.reconnect = false
  return self
end

-- 检查域名和端口是否一致.
function httpc:check_domain(opt)
  if self.domain and self.domain ~= opt.domain then
    return false
  end
  if self.port and self.port ~= opt.port then
    return false
  end
  return true
end

function httpc:send_request(opt, data)
  if not self.sock then
    if not self.reconnect then
      return nil, "httpc class can't connect to server 1 : " .. self.domain
    end
    local sock = sock_new():timeout(self.timeout)
    local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
    if not ok then
      sock:close()
      return nil, "httpc class can't connect to server : " .. self.domain
    end
    self.sock = sock
  end

  local ok, err = sock_send(self.sock, opt.protocol, data)
  if not ok then
    self.sock:close()
    if not self.reconnect then
      return nil, "httpc class can't connect to server 2 : " .. self.domain
    end
    local ok, err
    local sock = sock_new():timeout(self.timeout)
    ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
    if not ok then
      sock:close()
      return ok, err
    end
    ok, err = sock_send(sock, opt.protocol, data)
    if not ok then
      sock:close()
      return nil, err
    end
    self.sock = sock
  end
  return true
end

function httpc:raw( parameter )
  local opt, err = splite_protocol(parameter.domain)
  if not opt then
    return nil, err
  end

  if not self:check_domain(opt) then
    return nil, "Invalid httpc domain or port."
  end

  local method = type(parameter.method) == 'string' and upper(parameter.method) or nil
  assert( method and (
      method == 'GET' or
      method == 'POST' or
      method == 'DELETE' or
      method == 'PUT'
    ),"invalide http method.")

  -- GET方法禁止传递body
  if method == "GET" then
    parameter.body = nil
  end

  -- POST/PUT方法禁止传递args
  if method == "POST" or method == "PUT" or  method == "DELETE" then
    parameter.args = nil
  end

  opt.method = method
  opt.body = parameter.body
  opt.args = parameter.args
  opt.headers = parameter.headers

 local REQ = build_raw_req(opt)

  local ok, err = self:send_request(opt, REQ)
  if not ok then
    self.sock:close()
    self.sock = nil
    return false, err
  end

  local code, msg, headers = httpc_response(self.sock, opt.protocol)
  if not code then
    self.sock:close()
    self.sock = nil
  end
  return code, msg, headers

end

-- get 请求
function httpc:get (domain, headers, args, timeout)
  local opt, err = splite_protocol(domain)
  if not opt then
    return nil, err
  end

  if not self:check_domain(opt) then
    return nil, "Invalid httpc domain or port."
  end

  if timeout then
    self.timeout = timeout
  end

  opt.args = args
  opt.headers = headers
  opt.server = self.server

  self.domain = opt.domain
  self.port = opt.port

  local REQ = build_get_req(opt)

  local ok, err = self:send_request(opt, REQ)
  if not ok then
    return false, err
  end

  local code, msg, headers = httpc_response(self.sock, opt.protocol)
  if not code then
    self.sock:close()
    self.sock = nil
  end
  return code, msg, headers
end

-- post 请求
function httpc:post (domain, headers, body, timeout)
  local opt, err = splite_protocol(domain)
  if not opt then
    return nil, err
  end

  if not self:check_domain(opt) then
    return nil, "Invalid httpc domain or port."
  end

  if timeout then
    self.timeout = timeout
  end

  opt.body = body
  opt.headers = headers
  opt.server = self.server

  self.domain = opt.domain
  self.port = opt.port

  local REQ = build_post_req(opt)

  local ok, err = self:send_request(opt, REQ)
  if not ok then
    return false, err
  end

  local code, msg, headers = httpc_response(self.sock, opt.protocol)
  if not code then
    self.sock:close()
    self.sock = nil
  end
  return code, msg, headers
end

-- delete 请求
function httpc:delete (domain, headers, body, timeout)
  local opt, err = splite_protocol(domain)
  if not opt then
    return nil, err
  end

  if not self:check_domain(opt) then
    return nil, "Invalid httpc domain or port."
  end

  if timeout then
    self.timeout = timeout
  end

  opt.body = body
  opt.headers = headers
  opt.server = self.server

  self.domain = opt.domain
  self.port = opt.port

  local REQ = build_delete_req(opt)

  local ok, err = self:send_request(opt, REQ)
  if not ok then
    return false, err
  end

  local code, msg, headers = httpc_response(self.sock, opt.protocol)
  if not code then
    self.sock:close()
    self.sock = nil
  end
  return code, msg, headers
end

-- put 请求
function httpc:put (domain, headers, body, timeout)
  local opt, err = splite_protocol(domain)
  if not opt then
    return nil, err
  end

  if not self:check_domain(opt) then
    return nil, "Invalid httpc domain or port."
  end

  if timeout then
    self.timeout = timeout
  end

  opt.body = body
  opt.headers = headers
  opt.server = self.server

  self.domain = opt.domain
  self.port = opt.port

  local REQ = build_put_req(opt)

  local ok, err = self:send_request(opt, REQ)
  if not ok then
    return false, err
  end

  local code, msg, headers = httpc_response(self.sock, opt.protocol)
  if not code then
    self.sock:close()
    self.sock = nil
  end
  return code, msg, headers
end

-- json 请求
function httpc:json (domain, headers, json, timeout)

  local opt, err = splite_protocol(domain)
  if not opt then
    return nil, err
  end

  if not self:check_domain(opt) then
    return nil, "Invalid httpc domain or port."
  end

  if timeout then
    self.timeout = timeout
  end

  assert(type(json) == "string" or type(json) == "table", "attempted passed a invalide json string or table.")

  opt.json = json
  opt.headers = headers
  opt.server = self.server

  self.domain = opt.domain
  self.port = opt.port

  local REQ = build_json_req(opt)

  local ok, err = self:send_request(opt, REQ)
  if not ok then
    return false, err
  end

  local code, msg, headers = httpc_response(self.sock, opt.protocol)
  if not code then
    self.sock:close()
    self.sock = nil
  end
  return code, msg, headers
end

-- file 请求
function httpc:file (domain, headers, files, timeout)
  local opt, err = splite_protocol(domain)
  if not opt then
    return nil, err
  end

  if not self:check_domain(opt) then
    return nil, "Invalid httpc domain or port."
  end

  if timeout then
    self.timeout = timeout
  end

  opt.files = files
  opt.headers = headers
  opt.server = self.server

  self.domain = opt.domain
  self.port = opt.port

  local REQ = build_file_req(opt)

  local ok, err = self:send_request(opt, REQ)
  if not ok then
    return false, err
  end

  local code, msg, headers = httpc_response(self.sock, opt.protocol)
  if not code then
    self.sock:close()
    self.sock = nil
  end
  return code, msg, headers
end

-- 异步请求
function httpc:multi_request (opt)
  return hc_multi_request(opt)
end

-- 关闭连接
function httpc:close ()
  if self.sock then
    self.sock:close()
    self.sock = nil
  end
end

return httpc
