local httpc = require "httpc.class"

local HTTP_PARSER = require "protocol.http.parser"
local PARSER_HTTP_RESPONSE = HTTP_PARSER.PARSER_HTTP_RESPONSE

local ua = require "httpc.ua"
local protocol = require "httpc.protocol"
local sock_new = protocol.sock_new
local sock_recv = protocol.sock_recv
local sock_send = protocol.sock_send
local sock_connect = protocol.sock_connect
local build_basic_authorization = protocol.build_basic_authorization
local splite_protocol = protocol.splite_protocol
local httpc_response = protocol.httpc_response

local sys = require "sys"
local new_tab = sys.new_tab

local type = type
local assert = assert
local tonumber = tonumber

local find = string.find
local fmt = string.format
local concat = table.concat

local CRLF = '\x0d\x0a'
local CRLF2 = '\x0d\x0a\x0d\x0a'

local Proxy = {}

-- 构建代理认证信息
function Proxy.auth(Auth)
  if type(Auth.username) == 'string' and Auth.username ~= '' and type(Auth.password) == 'string' and Auth.password ~= '' then
    local _, base_info = build_basic_authorization(Auth.username, Auth.password)
    return base_info
  end
end

-- 构建请求内容
function Proxy.build_request(proxy_config, source_config, headers, auth)
  local domain_and_port = source_config.domain .. ":" .. source_config.port

  -- 初始化请求基本信息
  local req = new_tab(24, 0)
  req[#req+1] = fmt("CONNECT %s HTTP/1.1", domain_and_port)
  req[#req+1] = fmt("Host: %s", domain_and_port)
  req[#req+1] = fmt("User-Agent: %s", ua.get_user_agent())

  -- 检查是否需要额外信息
  if type(headers) == 'table' then
    for index, header in ipairs(headers) do
      assert(type(header) == 'table' and #header == 2, fmt("httpc Proxy headers index [%d] Parameter failed.", index))
      req[#req+1] = header[1] .. ": " .. header[2]
    end
  end

  -- 检查是否需要添加认证信息
  if type(auth) == 'string' then
    req[#req+1] = fmt("Proxy-Authorization: " .. auth)
  end

  req[#req+1] = "Proxy-Connection: keep-alive"
  req[#req+1] = "Connection: keep-alive"
  req[#req+1] = "Content-Length: 0"

  return concat(req, CRLF) .. CRLF2
end

function Proxy.http_proxy_handshake(sock, proxy_config, source_config, info)

  -- 开始与代理服务器进行握手
  local ok, err = sock_send(sock, proxy_config.protocol, info)
  if not ok then
    return false, err
  end

  -- 检查代理服务器验证情况
  local code, response = httpc_response(sock, proxy_config.protocol)
  if code ~= 200 then
    return false, response
  end

  -- 检查代理的通道是否需要SSL握手
  if source_config.protocol == "https" then
    local ok = sock:ssl_handshake()
    if not ok then
      return false, "httpc Proxy Connect ssl handshake failed."
    end
  end

  -- 连接成功
  return true
end

function Proxy.connect(sock, proxy_config, source_config, info)
  local ok, err = sock_connect(sock, proxy_config.protocol, proxy_config.domain, proxy_config.port)
  if not ok then
    return false, "httpc Proxy Sever failed. " .. err
  end

  -- 尝试与代理服务器进行握手
  local ok, err = Proxy.http_proxy_handshake(sock, proxy_config, source_config, info)
  if not ok then
    return false, "httpc Proxy Sever handshake failed. " .. (err or "")
  end

  return true
end

--[[
通过CONNCET TUNNEL来完成认证与代理

  opt.proxy_domain  参数表示代理服务器的域名/IP加上端口, 需要用http表示法并且要加上[/]结尾. 例如: http://proxy.com/, http://proxy.com:8080/;

  opt.source_domain 参数表示需要访问的服务器的域名/IP加上端口, 需要用http表示法并且要加上[/]结尾. 例如: http://proxy.com/, http://proxy.com:8080/, https://www.baidu.com/;

  opt.auth          参数表示需要使用basic 进行认证. opt.auth是一个table, 使用者需要为它的内部添加username与password字符串来标识代理账户与密码, Proxy内部会自动为其进行编码;

  opt.headers       参数表示需要为通道握手添加额外的头部信息, 这在一些特殊的代理服务器中可能会用到. 这个参数是一个table, 并且内部表示法为: {{header_key1, header_value1}, {header_key2, header_value2}, {header_key3, header_value3}};

返回值:

  此方法在代理通道建立成功后将会返回一个httpc class对象, 用户可以使用此对象来访问服务器的. 否则将会返回false与错误描述. 当您不想时候httpc的时候, 请主动调用它的close方法;

  请注意: Proxy并不能保证代理、源站不会主动断开连接, httpc class断开连接的时候进行重连也无法恢复代理连接. 所以请重新使用tunnel_connect方法创建httpc对象;
--]]
function Proxy.tunnel_connect(opt)

  -- 解析代理服务器域名信息
  local proxy_config, err = splite_protocol(opt.proxy_domain)
  if not proxy_config then
    return false, "[proxy_domain error]: " .. err
  end
  -- require"logging":DEBUG(proxy_config)

  -- 解析原站服务器域名信息
  local source_config, err = splite_protocol(opt.source_domain)
  if not source_config then
    return false, "[source_domain error]: " .. err
  end
  -- require"logging":DEBUG(source_config)

  -- 检查是否需要构建认证
  local auth = nil
  if type(opt.auth) == 'table' then
    auth = Proxy.auth(opt.auth)
  end

  local headers = nil
  if type(opt.headers) == 'table' and #opt.headers > 0 then
    headers = opt.headers
  end

  -- 构建代理通道所需的握手信息
  local info = Proxy.build_request(proxy_config, source_config, headers, auth)
  -- print(info)

  -- 设定socket超时时间
  local sock = sock_new():timeout(tonumber(opt.timeout) and tonumber(opt.timeout) > 0 and tonumber(opt.timeout) or 15)

  -- 尝试连接到代理服务器
  local ok, err = Proxy.connect(sock, proxy_config, source_config, info)
  if not ok then
    sock:close()
    return false, err
  end

  return httpc:new({ domain = opt.source_domain }):set_socket(sock):disable_reconnect()
end


return Proxy