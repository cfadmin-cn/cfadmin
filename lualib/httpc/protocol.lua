local tcp = require "internal.TCP"

local lz = require"lz"
local gzuncompress = lz.gzuncompress

local new_tab = require "sys".new_tab

local json = require "json"
local json_encode = json.encode

local xml2lua = require "xml2lua"
local toxml = xml2lua.toxml

local crypt = require "crypt"
local url_encode = crypt.urlencode
local base64encode = crypt.base64encode

local HTTP_PARSER = require "protocol.http.parser"
local FILEMIME = require "protocol.http.mime"
local PARSER_HTTP_RESPONSE = HTTP_PARSER.PARSER_HTTP_RESPONSE

local type = type
local assert = assert
local ipairs = ipairs
local tonumber = tonumber

local random = math.random
local find = string.find
local match = string.match
local lower = string.lower
local insert = table.insert
local concat = table.concat
local toint = math.tointeger
local fmt = string.format

local CRLF = '\x0d\x0a'
local CRLF2 = '\x0d\x0a\x0d\x0a'

local function sock_new ()
  return tcp:new()
end

local function sock_recv (sock, _, bytes)
  return sock:recv(bytes)
end

local function sock_send(sock, _, data)
  return sock:send(data)
end

local function sock_connect(sock, PROTOCOL, DOAMIN, PORT)
  local ok = sock:connect(DOAMIN, PORT)
  if not ok then
    return nil, 'httpc连接失败.'
  end
  if PROTOCOL == 'https' and not sock:ssl_handshake(DOAMIN) then
    return nil, 'httpc连接失败.'
  end
  return true
end

local function splite_protocol(domain)
  if type(domain) ~= 'string' then
    return nil, '1. invalide domain'
  end

  local protocol, domain_port, path = match(domain, '^(http[s]?)://([^/]+)(.*)')
  if not protocol or not domain_port or not path then
    return nil, '2. invalide url'
  end

  if not path or path == '' then
    return nil, "3. http path need '/' in end."
  end

  local domain, port
  if find(domain_port, ':') then
    local _, Bracket_Pos = find(domain_port, '[%[%]]')
    if Bracket_Pos then
      domain, port = match(domain_port, '%[(.+)%][:]?(%d*)')
    else
      domain, port = match(domain_port, '([^:]+):(%d*)')
    end
    if not domain then
      return nil, "4. invalide host or port: "..domain_port
    end
    port = toint(port)
    if not port then
      port = 80
      if protocol == 'https' then
        port = 443
      end
    end
  else
    domain, port = domain_port, protocol == 'https' and 443 or 80
  end
  return {
    protocol = protocol,
    domain = domain,
    port = port,
    path = path,
  }
end

local function read_data(sock, bytes)
  local buffers = new_tab(128, 0)
  while 1 do
    local buf = sock:recv(bytes)
    if not buf then
      return
    end
    buffers[#buffers+1] = buf
    bytes = bytes - #buf
    if bytes == 0 then
      break
    end
  end
  return concat(buffers)
end

local function httpc_response(sock, SSL)
  if not sock then
    return nil, "Can't used this method before other httpc method.."
  end
  local body
  local buf = sock:readline(CRLF2)
  if not buf then
    return nil, SSL .. " A peer of remote server close this connection."
  end
  local VERSION, CODE, STATUS, HEADER = PARSER_HTTP_RESPONSE(buf)
  if not CODE or not HEADER or (VERSION ~= 1.0 and VERSION ~= 1.1) then
    return nil, SSL .. " can't resolvable protocol."
  end
  local Content_Encoding = HEADER['Content-Encoding'] or HEADER['content-encoding']
  local Content_Length = toint(HEADER['Content-Length'] or HEADER['content-length'])
  local Chunked = HEADER['Transfer-Encoding'] or HEADER['transfer-encoding']
  if Chunked and find(Chunked, "chunked") then
    local resp = new_tab(128, 0)
    while 1 do
      local chunked_size = sock:readline(CRLF, true)
      local csize = toint(tonumber(chunked_size, 16))
      if not csize or csize == 0 then
        if csize then
          -- 这行代码是用来去除`\r\n`的.
          read_data(sock, 2)
          break
        end
        return nil, "Invalid http trunked body."
      end
      local buffer = read_data(sock, csize)
      if not buffer then
        return nil, SSL .. " [Content_Length] A peer of remote server close this connection."
      end
      resp[#resp+1] = buffer
      -- 这行代码是用来去除`\r\n`的.
      read_data(sock, 2)
    end
    body = concat(resp)
  elseif Content_Length then
    body = ""
    if Content_Length > 0 then
      local buffer = read_data(sock, Content_Length)
      if not buffer then
        return nil, SSL .. " [Content_Length] A peer of remote server close this connection."
      end
      body = buffer
    end
  else
    return CODE, STATUS, HEADER
  end
  local RESP = body
  if Content_Encoding == "gzip" then
    RESP = gzuncompress(body)
  end
  -- 如果有重定向, 则优先返回重定向的地址; 否则返回接收到的body内容
  if CODE == 301 or CODE == 302 or CODE == 303 or CODE == 307 or CODE == 308 then
    return CODE, HEADER['Location'] or HEADER['location'] or RESP, HEADER
  end
  return CODE, RESP, HEADER
end

-- 对一些特殊请求的支持
local function build_raw_req( opt )
  local request = new_tab(16, 0)
  insert(request, fmt("%s %s HTTP/1.1", opt.method, opt.path))
  insert(request, fmt("Host: %s", (opt.port == 80 or opt.port == 443) and opt.domain or opt.domain..':'..opt.port))
  insert(request, fmt("User-Agent: %s", opt.server))
  insert(request, 'Accept: */*')
  insert(request, 'Accept-Encoding: gzip, identity')
  insert(request, 'Connection: keep-alive')

  if opt.method == 'GET' and type(opt.args) == "table" then
    local args = new_tab(8, 0)
    for _, arg in ipairs(opt.args) do
      assert(#arg == 2, "args need key[1]->value[2] (2 values and must be string)")
      insert(args, url_encode(arg[1])..'='..url_encode(arg[2]))
    end
    request[1] = fmt("GET %s HTTP/1.1", opt.path .. '?' .. concat(args, "&"))
  end

  if type(opt.headers) == "table" then
    for _, header in ipairs(opt.headers) do
      assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
      insert(request, header[1]..': '..header[2])
    end
  end

  if opt.method == 'POST' or opt.method == 'PUT' or opt.method == 'DELETE' then

    if type(opt.body) == "table" then
      local body = new_tab(8, 0)
      for _, item in ipairs(opt.body) do
        assert(#item == 2, "if BODY is TABLE, BODY need key[1]->value[2] (2 values)")
        insert(body, url_encode(item[1])..'='..url_encode(item[2]))
      end
      local Body = concat(body, "&")
      insert(request, #request, fmt('Content-Length: %s', #Body))
      insert(request, #request, 'Content-Type: application/x-www-form-urlencoded\r\n')
      insert(request, Body)
    end

    if type(opt.body) == "string" then
      insert(request, fmt('Content-Length: %s\r\n', #opt.body))
      insert(request, opt.body)
    end

  end

  return concat(request, CRLF)
end

local function build_get_req (opt)
  local request = new_tab(16, 0)
  insert(request, fmt("GET %s HTTP/1.1", opt.path))
  insert(request, fmt("Host: %s", (opt.port == 80 or opt.port == 443) and opt.domain or opt.domain..':'..opt.port))
  insert(request, fmt("User-Agent: %s", opt.server))
  insert(request, 'Accept: */*')
  insert(request, 'Accept-Encoding: gzip, identity')
  insert(request, 'Connection: keep-alive')
  if type(opt.args) == "table" then
    local args = new_tab(8, 0)
    for _, arg in ipairs(opt.args) do
      assert(#arg == 2, "args need key[1]->value[2] (2 values and must be string)")
      insert(args, url_encode(arg[1])..'='..url_encode(arg[2]))
    end
    request[1] = fmt("GET %s HTTP/1.1", opt.path..'?'..concat(args, "&"))
  end
  if type(opt.headers) == "table" then
    for _, header in ipairs(opt.headers) do
      assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
      insert(request, header[1]..': '..header[2])
    end
  end
  insert(request, CRLF)
  return concat(request, CRLF)
end

local function build_post_req (opt)
  local request = new_tab(16, 0)
  insert(request, fmt("POST %s HTTP/1.1\r\n", opt.path))
  insert(request, fmt("Host: %s\r\n", (opt.port == 80 or opt.port == 443) and opt.domain or opt.domain..':'..opt.port))
  insert(request, fmt("User-Agent: %s\r\n", opt.server))
  insert(request, 'Accept: */*\r\n')
  insert(request, 'Accept-Encoding: gzip, identity\r\n')
  insert(request, 'Connection: keep-alive\r\n')

  local ct = false
  if type(opt.headers) == "table" then
    for _, header in ipairs(opt.headers) do
      if lower(header[1]) == 'content-type' then
        ct = true
      end
      assert(lower(header[1]) ~= 'content-length', "please don't give Content-Length")
      assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
      insert(request, header[1] .. ': ' .. header[2] .. CRLF)
    end
  end

  if type(opt.body) == "table" then
    local body = new_tab(8, 0)
    for _, item in ipairs(opt.body) do
      assert(#item == 2, "if BODY is TABLE, BODY need key[1]->value[2] (2 values)")
      insert(body, url_encode(item[1])..'='..url_encode(item[2]))
    end
    local Body = concat(body, "&")
    insert(request, fmt('Content-Length: %s\r\n', #Body))
    if not ct then
      insert(request, 'Content-Type: application/x-www-form-urlencoded\r\n\r\n')
    else
      insert(request, '\r\n')
    end
    insert(request, Body)
  elseif type(opt.body) == 'string' and opt.body ~= '' then
    insert(request, fmt('Content-Length: %s\r\n', #opt.body))
    if not ct then
      insert(request, 'Content-Type: application/x-www-form-urlencoded\r\n\r\n')
    else
      insert(request, '\r\n')
    end
    insert(request, opt.body)
  else
    insert(request, "Content-Length: 0\r\n\r\n")
  end

  return concat(request)
end

local function build_delete_req (opt)
  local request = new_tab(16, 0)
  insert(request, fmt("DELETE %s HTTP/1.1", opt.path))
  insert(request, fmt("Host: %s", (opt.port == 80 or opt.port == 443) and opt.domain or opt.domain..':'..opt.port))
  insert(request, fmt("User-Agent: %s", opt.server))
  insert(request, 'Accept: */*')
  insert(request, 'Accept-Encoding: gzip, identity')
  insert(request, 'Connection: keep-alive')
  if type(opt.headers) == "table" then
    for _, header in ipairs(opt.headers) do
      assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
      insert(request, header[1]..': '..header[2])
    end
  end
  if type(opt.body) == "string" and opt.body ~= '' then
    insert(request, fmt("Content-Length: %s", #opt.body))
  end
  return concat(request, CRLF) .. CRLF2 .. ( type(opt.body) == "string" and opt.body or '' )
end

local function build_json_req (opt)
  local request = new_tab(16, 0)
  insert(request, fmt("POST %s HTTP/1.1", opt.path))
  insert(request, fmt("Host: %s", (opt.port == 80 or opt.port == 443) and opt.domain or opt.domain..':'..opt.port))
  insert(request, fmt("User-Agent: %s", opt.server))
  insert(request, 'Accept: */*')
  insert(request, 'Accept-Encoding: gzip, identity')
  insert(request, 'Connection: keep-alive')
  if type(opt.headers) == "table" then
    for _, header in ipairs(opt.headers) do
      assert(lower(header[1]) ~= 'content-length', "please don't give Content-Length")
      assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
      insert(request, header[1]..': '..header[2])
    end
  end
  if type(opt.json) == 'string' and opt.json ~= '' then
    insert(request, 'Content-Type: application/json')
    insert(request, fmt("Content-Length: %s", #opt.json))
  elseif type(opt.json) == 'table' then
    opt.json = json_encode(opt['json'])
    insert(request, 'Content-Type: application/json')
    insert(request, "Content-Length: " .. #opt.json)
  else
    opt.json = ""
    insert(request, 'Content-Type: application/json')
    insert(request, "Content-Length: 0")
  end
  return concat(request, CRLF) .. CRLF2 .. opt.json
end

local function build_xml_req(opt)
  local request = new_tab(16, 0)
  insert(request, fmt("POST %s HTTP/1.1", opt.path))
  insert(request, fmt("Host: %s", (opt.port == 80 or opt.port == 443) and opt.domain or opt.domain..':'..opt.port))
  insert(request, fmt("User-Agent: %s", opt.server))
  insert(request, 'Accept: */*')
  insert(request, 'Accept-Encoding: gzip, identity')
  insert(request, 'Connection: keep-alive')
  if type(opt.headers) == "table" then
    for _, header in ipairs(opt.headers) do
      assert(lower(header[1]) ~= 'content-length', "please don't give Content-Length")
      assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
      insert(request, header[1]..': '..header[2])
    end
  end
  if type(opt.xml) == 'string' and opt.xml ~= '' then
    insert(request, 'Content-Type: application/xml')
    insert(request, fmt("Content-Length: %s", #opt.xml))
  elseif type(opt.xml) == 'table' then
    opt.xml = toxml(opt.xml, "xml")
    insert(request, 'Content-Type: application/xml')
    insert(request, "Content-Length: " .. #opt.xml)
  else
    opt.xml = ""
    insert(request, 'Content-Type: application/xml')
    insert(request, "Content-Length: 0")
  end
  return concat(request, CRLF) .. CRLF2 .. opt.xml
end

local function build_file_req (opt)
  local request = new_tab(16, 0)
  insert(request, fmt("POST %s HTTP/1.1\r\n", opt.path))
  insert(request, fmt("Host: %s\r\n", (opt.port == 80 or opt.port == 443) and opt.domain or opt.domain..':'..opt.port))
  insert(request, fmt("User-Agent: %s\r\n", opt.server))
  insert(request, 'Accept: */*\r\n')
  insert(request, 'Accept-Encoding: gzip, identity\r\n')
  insert(request, 'Connection: keep-alive\r\n')
  if type(opt.headers) == "table" then
    for _, header in ipairs(opt.headers) do
      assert(lower(header[1]) ~= 'content-length', "please don't give Content-Length")
      assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
      insert(request, header[1]..': '..header[2]..'\r\n')
    end
  end

  if type(opt.files) == 'table' then
    local bd = random(1000000000, 9999999999)
    local boundary_start = fmt("------CFWebService%d", bd)
    local boundary_end   = fmt("------CFWebService%d--", bd)
    insert(request, fmt('Content-Type: multipart/form-data; boundary=----CFWebService%s\r\n', bd))
    local body = new_tab(16, 0)
    local cd = 'Content-Disposition: form-data; %s'
    local ct = 'Content-Type: %s'
    for index, file in ipairs(opt.files) do
      assert(file.file, "files index : [" .. index .. "] unknown multipart/form-data content.")
      insert(body, boundary_start)
      local name = file.name
      local filename = file.filename
      if not file.type then
        if type(name) ~= 'string' or name == '' then
          name = ''
        end
        insert(body, fmt(cd, fmt('name="%s"', name)) .. CRLF)
      else
        if type(name) ~= 'string' or name == '' then
          name = ''
        end
        if type(filename) ~= 'string' or filename == '' then
          filename = ''
        end
        insert(body, fmt(cd, fmt('name="%s"', name) .. '; ' .. fmt('filename="%s"', filename)))
        insert(body, fmt(ct, FILEMIME[file.type or ''] or 'application/octet-stream') .. CRLF)
      end
      insert(body, file.file)
    end
    insert(body, boundary_end)
    body = concat(body, CRLF)
    insert(request, fmt("Content-Length: %s\r\n\r\n", #body))
    insert(request, body)
  end
  return concat(request)
end

local function build_put_req (opt)
  local request = new_tab(16, 0)
  insert(request, fmt("PUT %s HTTP/1.1", opt.path))
  insert(request, fmt("Host: %s", (opt.port == 80 or opt.port == 443) and opt.domain or opt.domain..':'..opt.port))
  insert(request, fmt("User-Agent: %s", opt.server))
  insert(request, 'Accept: */*')
  insert(request, 'Accept-Encoding: gzip, identity')
  insert(request, 'Connection: keep-alive')
  if type(opt.headers) == "table" then
    for _, header in ipairs(opt.headers) do
      assert(lower(header[1]) ~= 'content-length', "please don't give Content-Length")
      assert(#header == 2, "HEADER need key[1]->value[2] (2 values)")
      insert(request, header[1]..': '..header[2])
    end
  end
  if type(opt.body) == "string" and opt.body ~= '' then
    insert(request, fmt("Content-Length: %s", #opt.body))
  end
  return concat(request, CRLF) .. CRLF2 .. ( type(opt.body) == "string" and opt.body or '' )
end

-- http base authorization
local function build_basic_authorization(username, password)
  return "Authorization", "Basic " .. base64encode(username .. ":" .. password)
end

return {
  sock_new = sock_new,
  sock_recv = sock_recv,
  sock_send = sock_send,
  sock_connect = sock_connect,
  httpc_response = httpc_response,
  splite_protocol = splite_protocol,
  build_raw_req = build_raw_req,
  build_get_req = build_get_req,
  build_post_req = build_post_req,
  build_json_req = build_json_req,
  build_file_req = build_file_req,
  build_xml_req = build_xml_req,
  build_put_req = build_put_req,
  build_delete_req = build_delete_req,
  build_basic_authorization = build_basic_authorization,
}
