local hc = require "httpc"
local hc_multi_request = hc.multi_request

local class = require "class"

local ua = require "httpc.ua"
local protocol = require "httpc.protocol"
local sock_new = protocol.sock_new
local sock_recv = protocol.sock_recv
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
local build_jwt = protocol.build_jwt
local build_basic_authorization = protocol.build_basic_authorization

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

local methods = {'get', 'post', 'json', 'file'}

local httpc = class("httpc")

function httpc:ctor (opt)
  self.server = ua.get_user_agent()
  self.timeout = opt.timeout or 15
end

function httpc:jwt(...)
  return build_jwt(...)
end

function httpc:basic_authorization( ... )
  return build_basic_authorization(...)
end

function httpc:raw( parameter )
  local opt, err = splite_protocol(parameter.domain)
  if not opt then
    return nil, err
  end

  if self.domain and self.domain ~= opt.domain then
    return nil, "1. 不同的域名不可使用httpc对象来请求"
  end

  if self.port and self.port ~= opt.port then
    return nil, "2. 不同的域名不可使用httpc对象来请求"
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

  if not self.sock then
    local sock = sock_new():timeout(self.timeout)
    local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
    if not ok then
      sock:close()
      return ok, err
    end
    self.sock = sock
  end

  local ok, err = sock_send(self.sock, opt.protocol, REQ)
  if not ok then
    self.sock:close()
    self.sock = nil
    local sock = sock_new():timeout(self.timeout)
    local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
    if not ok then
      sock:close()
      return ok, err
    end
    ok, err = sock_send(sock, opt.protocol, REQ)
    if not ok then
      sock:close()
      return nil, err
    end
    self.sock = sock
  end

  local code, msg = httpc_response(self.sock, opt.protocol)
  if not code then
    self.sock:close()
    self.sock = nil
  end
  return code, msg

end

-- get 请求
function httpc:get (domain, headers, args, timeout)
  local opt, err = splite_protocol(domain)
  if not opt then
    return nil, err
  end

  if self.domain and self.domain ~= opt.domain then
    return nil, "1. 不同的域名不可使用httpc对象来请求"
  end

  if self.port and self.port ~= opt.port then
    return nil, "2. 不同的域名不可使用httpc对象来请求"
  end

  opt.args = args
  opt.headers = headers
  opt.server = self.server

  self.domain = opt.domain
  self.port = opt.port

  local REQ = build_get_req(opt)

  if not self.sock then
    local sock = sock_new():timeout(self.timeout)
    local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
    if not ok then
      sock:close()
      return ok, err
    end
    self.sock = sock
  end

  local ok, err = sock_send(self.sock, opt.protocol, REQ)
  if not ok then
    self.sock:close()
    self.sock = nil
    local sock = sock_new():timeout(self.timeout)
    local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
    if not ok then
      sock:close()
      return ok, err
    end
    ok, err = sock_send(sock, opt.protocol, REQ)
    if not ok then
      sock:close()
      return nil, err
    end
    self.sock = sock
  end

  local code, msg = httpc_response(self.sock, opt.protocol)
  if not code then
    self.sock:close()
    self.sock = nil
  end
  return code, msg
end

-- post 请求
function httpc:post (domain, headers, body, timeout)
  local opt, err = splite_protocol(domain)
  if not opt then
    return nil, err
  end

  if self.domain and self.domain ~= opt.domain then
    return nil, "1. 不同的域名不可使用httpc对象来请求"
  end

  if self.port and self.port ~= opt.port then
    return nil, "2. 不同的域名不可使用httpc对象来请求"
  end

  opt.body = body
  opt.headers = headers
  opt.server = self.server

  self.domain = opt.domain
  self.port = opt.port

  local REQ = build_post_req(opt)

  if not self.sock then
    local sock = sock_new():timeout(self.timeout)
    local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
    if not ok then
      sock:close()
      return ok, err
    end
    self.sock = sock
  end

  local ok, err = sock_send(self.sock, opt.protocol, REQ)
  if not ok then
    self.sock:close()
    self.sock = nil
    local sock = sock_new():timeout(self.timeout)
    local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
    if not ok then
      sock:close()
      return ok, err
    end
    ok, err = sock_send(sock, opt.protocol, REQ)
    if not ok then
      sock:close()
      return nil, err
    end
    self.sock = sock
  end

  local code, msg = httpc_response(self.sock, opt.protocol)
  if not code then
    self.sock:close()
    self.sock = nil
  end
  return code, msg
end

-- delete 请求
function httpc:delete (domain, headers, body, timeout)
  local opt, err = splite_protocol(domain)
  if not opt then
    return nil, err
  end

  if self.domain and self.domain ~= opt.domain then
    return nil, "1. 不同的域名不可使用httpc对象来请求"
  end

  if self.port and self.port ~= opt.port then
    return nil, "2. 不同的域名不可使用httpc对象来请求"
  end

  opt.body = body
  opt.headers = headers
  opt.server = self.server

  self.domain = opt.domain
  self.port = opt.port

  local REQ = build_delete_req(opt)

  if not self.sock then
    local sock = sock_new():timeout(self.timeout)
    local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
    if not ok then
      sock:close()
      return ok, err
    end
    self.sock = sock
  end

  local ok, err = sock_send(self.sock, opt.protocol, REQ)
  if not ok then
    self.sock:close()
    self.sock = nil
    local sock = sock_new():timeout(self.timeout)
    local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
    if not ok then
      sock:close()
      return ok, err
    end
    ok, err = sock_send(sock, opt.protocol, REQ)
    if not ok then
      sock:close()
      return nil, err
    end
    self.sock = sock
  end

  local code, msg = httpc_response(self.sock, opt.protocol)
  if not code then
    self.sock:close()
    self.sock = nil
  end
  return code, msg
end

-- put 请求
function httpc:put (domain, headers, body, timeout)
  local opt, err = splite_protocol(domain)
  if not opt then
    return nil, err
  end

  if self.domain and self.domain ~= opt.domain then
    return nil, "1. 不同的域名不可使用httpc对象来请求"
  end

  if self.port and self.port ~= opt.port then
    return nil, "2. 不同的域名不可使用httpc对象来请求"
  end

  opt.body = body
  opt.headers = headers
  opt.server = self.server

  self.domain = opt.domain
  self.port = opt.port

  local REQ = build_put_req(opt)

  if not self.sock then
    local sock = sock_new():timeout(self.timeout)
    local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
    if not ok then
      sock:close()
      return ok, err
    end
    self.sock = sock
  end

  local ok, err = sock_send(self.sock, opt.protocol, REQ)
  if not ok then
    self.sock:close()
    self.sock = nil
    local sock = sock_new():timeout(self.timeout)
    local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
    if not ok then
      sock:close()
      return ok, err
    end
    ok, err = sock_send(sock, opt.protocol, REQ)
    if not ok then
      sock:close()
      return nil, err
    end
    self.sock = sock
  end

  local code, msg = httpc_response(self.sock, opt.protocol)
  if not code then
    self.sock:close()
    self.sock = nil
  end
  return code, msg
end

-- json 请求
function httpc:json (domain, headers, json, timeout)

  local opt, err = splite_protocol(domain)
  if not opt then
    return nil, err
  end

  if self.domain and self.domain ~= opt.domain then
    return nil, "1. 不同的域名不可使用httpc对象来请求"
  end

  if self.port and self.port ~= opt.port then
    return nil, "2. 不同的域名不可使用httpc对象来请求"
  end

  assert(type(json) == "string" or type(json) == "table", "attempted passed a invalide json string or table.")

  opt.json = json
  opt.headers = headers
  opt.server = self.server

  self.domain = opt.domain
  self.port = opt.port

  local REQ = build_json_req(opt)

  if not self.sock then
    local sock = sock_new():timeout(self.timeout)
    local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
    if not ok then
      sock:close()
      return ok, err
    end
    self.sock = sock
  end

  local ok, err = sock_send(self.sock, opt.protocol, REQ)
  if not ok then
    self.sock:close()
    self.sock = nil
    local sock = sock_new():timeout(self.timeout)
    local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
    if not ok then
      sock:close()
      return ok, err
    end
    ok, err = sock_send(sock, opt.protocol, REQ)
    if not ok then
      sock:close()
      return nil, err
    end
    self.sock = sock
  end

  local code, msg = httpc_response(self.sock, opt.protocol)
  if not code then
    self.sock:close()
    self.sock = nil
  end
  return code, msg
end

-- file 请求
function httpc:file (domain, headers, files, timeout)
  local opt, err = splite_protocol(domain)
  if not opt then
    return nil, err
  end

  if self.domain and self.domain ~= opt.domain then
    return nil, "1. 不同的域名不可使用httpc对象来请求"
  end

  if self.port and self.port ~= opt.port then
    return nil, "2. 不同的域名不可使用httpc对象来请求"
  end

  opt.files = files
  opt.headers = headers
  opt.server = self.server

  self.domain = opt.domain
  self.port = opt.port

  local REQ = build_file_req(opt)

  if not self.sock then
    local sock = sock_new():timeout(self.timeout)
    local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
    if not ok then
      sock:close()
      return ok, err
    end
    self.sock = sock
  end

  local ok, err = sock_send(self.sock, opt.protocol, REQ)
  if not ok then
    self.sock:close()
    self.sock = nil
    local sock = sock_new():timeout(self.timeout)
    local ok, err = sock_connect(sock, opt.protocol, opt.domain, opt.port)
    if not ok then
      sock:close()
      return ok, err
    end
    ok, err = sock_send(sock, opt.protocol, REQ)
    if not ok then
      sock:close()
      return nil, err
    end
    self.sock = sock
  end

  local code, msg = httpc_response(self.sock, opt.protocol)
  if not code then
    self.sock:close()
    self.sock = nil
  end
  return code, msg
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
