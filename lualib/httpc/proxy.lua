local httpc = require "httpc.class"

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
local ipv4 = sys.ipv4
local ipv6 = sys.ipv6
local str2ip = sys.str2ip

local type = type
local ipairs = ipairs
local assert = assert
local tonumber = tonumber

local match = string.match
local fmt = string.format
local char = string.char
local pack = string.pack
local unpack = string.unpack
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
function Proxy.build_request(source_config, headers, auth)
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
    if not sock:ssl_handshake(proxy_config.domain) then
      return false, "httpc Proxy Connect ssl handshake failed."
    end
  end

  -- 连接成功
  return true
end

function Proxy.socks5_proxy_handshake(sock, proxy_config, source_config)

  -- socks5不支持IPv6.
  if ipv6(source_config.domain) then
    return false, "httpc socks5 Proxy Unsupported ipv6 protocol."
  end

  if not sock:connect(proxy_config.domain, proxy_config.port) then
    return false, "httpc Proxy socks5 Connect failed."
  end

  local VER, NMETHODS, METHODS = 0x05, 1, char(0x00)

  local username, password = nil, nil
  if type(proxy_config.auth) == 'table' and type(proxy_config.auth.username) == 'string' and #proxy_config.auth.username > 0 and type(proxy_config.auth.password) == 'string' and #proxy_config.auth.password > 0 then
    username = proxy_config.auth.username
    password = proxy_config.auth.password
    NMETHODS = NMETHODS + 1
    METHODS = METHODS .. char(0x02)
  end

  if not sock:send(pack(">BB", VER, NMETHODS) .. METHODS) then
    return false, "httpc socks5 Proxy closed in handshake. 1"
  end

  local data = sock:recv(2)
  -- "\x05\x00" 表示无需认证, "\x05\x02" 表示后续需要用户名密码认证.
  if data ~= '\x05\x00' and data ~= '\x05\x02' then
    if not data then
      return false, "httpc socks5 Proxy closed this session."
    end
    return false, "httpc socks5 Proxy Can't Support this protocol."
  end

  -- 如果需要进一步协商用户认证(sub-negotiation)
  if data == '\x05\x02' then
    -- 发送用户名/密码到代理服务器进行鉴权.
    local ok = sock:send(char(0x02) .. char(#username) .. username .. char(#password) .. password)
    if not ok then
      return false, "httpc socks5 Proxy closed this session when send auth info."
    end
    local data = sock:recv(2)
    if not data or #data ~= 2 then
      return false, "httpc socks5 Proxy closed this session when server response auth status."
    end
    local auth_version, auth_status = unpack(">BB", data)
    if auth_version ~= 2 or auth_status ~= 0 then
      return false, "httpc socks5 Proxy server Authentication failed, please check username and password."
    end
  end

  -- 定义版本, 命令, 预留编码
  local VER, CMD, RSV = 0x05, 0x01, 0x00
  -- 定义连接类型, 目标地址, 目标端口
  local ATYPE, DST_ADDR, DST_PORT = nil, nil, nil
  if ipv4(source_config.domain) then
    -- 如果http[s]对端使用IP地址直连, 协议需要改变类型与地址的编码方式.
    -- 需要注意的是: 如果对端使用的https并且使用domain验证, 那么代理鉴权完成之后的ssl握手可能会失败.
    ATYPE, DST_ADDR, DST_PORT = 0x01, pack(">I4", str2ip(source_config.domain)), pack(">I2", source_config.port)
  else
    ATYPE, DST_ADDR, DST_PORT = 0x03, char(#source_config.domain) .. source_config.domain, pack(">I2", source_config.port)
  end

  -- 发送连接协议
  local ok = sock:send(pack(">BBBB", VER, CMD, RSV, ATYPE) .. DST_ADDR .. DST_PORT)
  if not ok then
    return false, "httpc socks5 Proxy closed in handshake. 2"
  end

  local data = sock:recv(4)
  if not data then
    return false, "httpc socks5 Proxy closed in handshake. 3"
  end

  local ver, rep, rsv, atype = unpack(">BBBB", data)
  -- print("成功: ", ver, rep, rsv, atype)

  if ver ~= 5 and rep ~= 0 then
    return false, "httpc socks5 Proxy Server Connect source domain failed."
  end

  if atype == 1 then -- 如果atype是IPv4类型
    if not sock:recv(4) then
      return false, "httpc socks5 Proxy Close this session when read IPv4 info."
    end
    -- print("代理服务器为本次连接分配的IPv4地址为:", table.concat({unpack(">BBBB", data)}, ".", 1, 4))
  elseif atype == 3 then -- 如果atype是domain类型
    if not sock:recv(1) then
      return false, "httpc socks5 Proxy Close this session when read domain atype."
    end
    sock:recv(unpack(">B", data))
    -- print("代理服务器回应了一个域名:" .. domain)
  elseif atype == 4 then -- 如果atype是IPv6类型
    if not sock:recv(16) then
      return false, "httpc socks5 Proxy Close this session when read IPv6 atype."
    end
    -- print("代理服务器为本次连接分配的IPv6地址为:", table.concat({unpack(">HHHHHHHH", data)}, ":", 1, 8))
  end

  if not sock:recv(2) then
    return false, "httpc socks5 Proxy Server was shutdown before the connection was completed."
  end
  -- print("代理服务器为本次连接分配的端口为:", unpack(">I2", data))

  -- 到这里就可以认为代理服务器完成它的使命, 现在需要检查是否需要https握手.
  if source_config.protocol == "https" then
    if not sock:ssl_handshake(source_config.domain) then
      return false, "httpc Proxy Connect ssl handshake failed."
    end
  end

  return true
end

function Proxy.connect(sock, proxy_config, source_config, info)
  local ok1, e1 = sock_connect(sock, proxy_config.protocol, proxy_config.domain, proxy_config.port)
  if not ok1 then
    return false, "httpc Proxy Sever failed. " .. e1
  end

  -- 尝试与代理服务器进行握手
  local ok2, e2 = Proxy.http_proxy_handshake(sock, proxy_config, source_config, info)
  if not ok2 then
    return false, "httpc Proxy Sever handshake failed. " .. (e2 or "")
  end

  return true
end

---comment 通过`HTTP CONNCET`来完成认证与代理. `proxy_domain`的语法为: `http://(域名或IP):端口/`; `source_domain`的语法为: `http[s]://(域名或IP):端口/`;(`/`是必须存在的);
---comment 代理通道建立成功后将会返回一个`httpc class`对象. 失败返回`false`与`string`类型的错误信息. 在不需要使用的时候请调用它的`close`方法回收资源;
---comment `Proxy`不会做任何连接有效保证, `httpc class`断开连接的时候请调用它的`close`方法回收资源, 重新使用`tunnel_connect`方法创建`httpc`对象;
---@param opt table @`proxy_domain(代理IP)`/`opt.source_domain(目标IP)`/`opt.auth(可选的basice认证)`/`opt.headers(可选的头部信息)`/`opt.timeout(可选的连接超时时间)`
---@return table | nil, string @成功返回`httpc class`, 失败返回`false`与`string`类型的错误信息 .
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
  local info = Proxy.build_request(source_config, headers, auth)
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

---comment 通过`SOCK5 CONNCET`来完成认证与代理. `proxy_domain`的语法为: `socks5://(域名或IP):端口`; `source_domain`的语法为: `http[s]://(域名或IP):端口/`, `/`是必须存在的;
---comment 代理通道建立成功后将会返回一个`httpc class`对象. 失败返回`false`与`string`类型的错误信息. 在不需要使用的时候请调用它的`close`方法回收资源;
---comment `Proxy`不会做任何连接有效保证, `httpc class`断开连接的时候请调用它的`close`方法回收资源, 重新使用`socks5_connect`方法创建`httpc`对象;
---@param opt table @`proxy_domain(代理IP)`/`opt.source_domain(目标IP)`/`opt.auth(可选的basice认证)`/`opt.headers(可选的头部信息)`/`opt.timeout(可选的连接超时时间)`
---@return table | nil, string @成功返回`httpc class`, 失败返回`false`与`string`类型的错误信息 .
function Proxy.socks5_connect(opt)
  -- 解析代理服务器域名信息
  local domain, port = match(type(opt.proxy_domain) == 'string' and opt.proxy_domain or "" , "socks5://[%[]?([^%]%[]+)[%]]?[:](%d+)")
  if not domain or not port then
    return false, "[proxy_domain error]: Invalid Proxy ip/domain and port."
  end

  -- 解析原站服务器域名信息
  local source_config, err = splite_protocol(opt.source_domain)
  if not source_config then
    return false, "[source_domain error]: " .. err
  end

    -- 设定socket超时时间
  local sock = sock_new():timeout(tonumber(opt.timeout) and tonumber(opt.timeout) > 0 and tonumber(opt.timeout) or 15)

  local ok, err = Proxy.socks5_proxy_handshake(sock, { domain = domain, port = port , auth = opt.auth }, source_config)
  if not ok then
    sock:close()
    return false, err
  end

  return httpc:new({ domain = opt.source_domain }):set_socket(sock):disable_reconnect()
end

return Proxy