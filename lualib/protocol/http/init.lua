local log = require "logging"
local tcp = require "internal.TCP"
local wsserver = require "protocol.websocket.server"

local Log = log:new({ dump = true, path = 'protocol-http'})

local crypt = require "crypt"
local sha1 = crypt.sha1
local base64encode = crypt.base64encode

local sys = require "sys"
local now = sys.now
local new_tab = sys.new_tab

local lz = require "lz"
local decompress = lz.compress
local gzcompress = lz.gzcompress

-- 如果有安装lua-br, 可以优先使用支持的Brotli算法.
local brcompress
local ok, br = pcall(require, "lbr")
if ok and type(br) == "table" and type(br.compress) == "function" then
  brcompress = br.compress
end

local form = require "httpd.Form"
local FILE_TYPE = form.FILE
local ARGS_TYPE = form.ARGS
local form_multipart = form.multipart
local form_urlencode = form.urlencode
local form_argsencode = form.get_args

local Cookie = require "httpd.Cookie"
local clCookie = Cookie.clean   -- 清理
local secCookie = Cookie.setSecure -- 设置Cookie加密字段
local seCookie = Cookie.serialization -- 序列化
local deCookie = Cookie.deserialization -- 反序列化

local null = null
local type = type
local tostring = tostring
local next = next
local xpcall = xpcall
local pairs = pairs
local ipairs = ipairs
local lower = string.lower
local match = string.match
local fmt = string.format
local toint = math.tointeger
local find = string.find
local split = string.sub

local DATE = os.date
local time = os.time

local concat = table.concat
local insert = table.insert

local CRLF = '\x0d\x0a'
local CRLF2 = '\x0d\x0a\x0d\x0a'
local RE_CRLF2 = '[\x0d]?\x0a[\x0d]?\x0a'
local COMMA = '\x2c'

local SERVER = 'cf web/0.1'

local HTTP_CODE = require "protocol.http.code"
local PAGES = require "protocol.http.pages"
local MIME = require "protocol.http.mime"

local HTTP_PARSER = require "protocol.http.parser"
local PARSER_HTTP_REQUEST = HTTP_PARSER.PARSER_HTTP_REQUEST
local PARSER_HTTP_RESPONSE = HTTP_PARSER.PARSER_HTTP_RESPONSE
local RESPONSE_CHUNKED_PARSER = HTTP_PARSER.RESPONSE_CHUNKED_PARSER

-- OPCODE
local OPCODE_RESP = -128
local OPCODE_THROW = -256
local OPCODE_REDIRECT = -65536

local HTTP_PROTOCOL = {
  API = 1,
  [1] = "API",
  USE = 2,
  [2] = "USE",
  STATIC = 3,
  [3] = "STATIC",
  WS = 4,
  [4] = "WS",
  PARSER_HTTP_REQUEST = PARSER_HTTP_REQUEST,
  PARSER_HTTP_RESPONSE = PARSER_HTTP_RESPONSE,
  RESPONSE_CHUNKED_PARSER = RESPONSE_CHUNKED_PARSER,
}

-- 以下为 HTTP Server 所需所用方法
local function REQUEST_STATUCODE_RESPONSE(code)
  return HTTP_CODE[code] or "attempt to passed a invalid code to response message."
end

local function REQUEST_MIME_RESPONSE(mime)
  return MIME[mime]
end

function HTTP_PROTOCOL.FILEMIME(mime)
  return MIME[mime]
end

local function HTTP_DATE()
  return DATE("Date: %a, %d %b %Y %X GMT")
  -- return os.date("Date: %a, %d %b %Y %X GMT")
end

local function HTTP_EXPIRES(timestamp)
  return DATE("Expires: %a, %d %b %Y %X GMT", timestamp)
  -- return os.date("Date: %a, %d %b %Y %X GMT")
end

local function req_time(ts)
  return now() - (ts or now())
end

local tab_copy
tab_copy = function (src)
  local dst = new_tab(0, 32)
  for k, v in pairs(src) do
    dst[k] = type(v) == 'table' and tab_copy(v) or v
  end
  return dst
end

-- 追踪调用栈信息
local function trace (msg)
  return debug.traceback(coroutine.running(), msg, 2)
end

-- 安全运行回调函数
local function safe_call (f, ...)
  local ok, r1, r2, r3, r4, t5 = xpcall(f, trace, ...)
  return ok, r1, r2, r3, r4, t5
end

local function readall(sock, bsize, buffers)
  local sock_recv = sock.recv
  while 1 do
    local buffer = sock_recv(sock, bsize)
    if not buffer then
      return
    end
    bsize = bsize - #buffer
    insert(buffers, buffer)
    if bsize == 0 then
      break
    end
  end
  return true
end

local function cros_append(header, timeout)
  insert(header, 'Access-Control-Allow-Origin: *')
  insert(header, 'Access-Control-Allow-Headers: *')
  insert(header, 'Access-Control-Allow-Methods: GET, POST, PUT, HEAD, OPTIONS')
  insert(header, 'Access-Control-Allow-Credentials: true')
  insert(header, 'Access-Control-Max-Age: ' .. (timeout or 86400))
end

local function PASER_METHOD(http, sock, max_body_size, buffer, METHOD, PATH, HEADER)
  local content = new_tab(0, 16)
  local body_len = toint(HEADER['Content-Length']) or toint(HEADER['Content-length']) or toint(HEADER['content-length'])
  local BODY
  if body_len and body_len > 0 then
    if body_len >= (max_body_size or (1024 * 1024)) then
      return nil, 413
    end
    local buffers = new_tab(16, 0)
    local bsize = body_len
    local _, CRLF_END = find(buffer, RE_CRLF2)
    if #buffer > CRLF_END then
      bsize = bsize - (#buffer - CRLF_END)
      buffers[#buffers+1] = split(buffer, CRLF_END + 1)
    end
    if bsize > 0 and not readall(sock, bsize, buffers) then
      return nil, null
    end
    BODY = concat(buffers)
  end

  local FILE_ENCODE = 'multipart/form-data'
  local XML_ENCODE_1  = 'text/xml'
  local XML_ENCODE_2  = 'application/xml'
  local JSON_ENCODE = 'application/json'
  local URL_ENCODE  = 'application/x-www-form-urlencoded'
  local format = match(HEADER['Content-Type'] or HEADER['content-type'] or '', '(.-/[^;]*)')

  if format == JSON_ENCODE then
    content['json'] = true
  elseif format == XML_ENCODE_1 or format == XML_ENCODE_2 then
    content['xml'] = true
  elseif format == FILE_ENCODE then
    if format == FILE_ENCODE then
      local BOUNDARY = match(HEADER['Content-Type'] or HEADER['content-type'] or '', '^.+=[%-]*(.+)')
      if BOUNDARY and BOUNDARY ~= '' then
        local files, formargs = form_multipart(BODY, BOUNDARY)
        if files then
          content['files'] = files
        end
        if formargs then
          content['formargs'] = {}
          for _, args in ipairs(formargs) do
            content['formargs'][args[1]] = args[2]
          end
        end
      end
    end
  end

  local spl_pos = find(PATH, '%?')
  local queryParams = form_argsencode(PATH)
  if spl_pos and spl_pos < #PATH then
    content['query'] = queryParams
  end
  if METHOD == "GET" or METHOD == "DELETE" then
    content['args'] = queryParams
  elseif METHOD == "POST" then
    if format == FILE_ENCODE then
      content['args'] = content['formargs']
    elseif format == URL_ENCODE then
      content['args'] = form_urlencode(BODY)
    end
  end
  content['body'] = BODY
  return true, content
end

local function X_Forwarded_FORMAT(ip_list)
  if find(ip_list, COMMA) then
    return ip_list:gsub(COMMA, " ->")
  end
  return ip_list
end
-- 一些错误返回
local function ERROR_RESPONSE(http, code, path, ip, forword, method, speed)
  http:tolog(code, path, ip, X_Forwarded_FORMAT(forword) or ip, method, speed)
  local response = {
      REQUEST_STATUCODE_RESPONSE(code),
      HTTP_DATE(),
      'Connection: keep-alive',
      'Server: ' .. (http.__server or SERVER),
    }
  local error_page = PAGES[code]
  if error_page and http.__enable_error_pages then
    insert(response, 'Content-Length: ' .. #error_page)
    return concat({concat(response, CRLF), error_page}, CRLF2)
  else
    insert(response, 'Content-Length: 0')
    return concat({concat(response, CRLF), CRLF2})
  end
end

-- WebSocket
local function Switch_Protocol(http, cls, sock, header, method, version, path, ip, start_time)
  if method ~= 'GET' then
    return sock:send(ERROR_RESPONSE(http, 400, path, ip, header['X-Forwarded-For'] or ip, method, req_time(start_time)))
  end
  if version ~= 1.1 then
    return sock:send(ERROR_RESPONSE(http, 400, path, ip, header['X-Forwarded-For'] or ip, method, req_time(start_time)))
  end
  if not header['Upgrade'] or lower(header['Upgrade']) ~= 'websocket' then
    return sock:send(ERROR_RESPONSE(http, 401, path, ip, header['X-Forwarded-For'] or ip, method, req_time(start_time)))
  end
  if header['Sec-WebSocket-Version'] ~= '13' then
    return sock:send(ERROR_RESPONSE(http, 403, path, ip, header['X-Forwarded-For'] or ip, method, req_time(start_time)))
  end
  local sec_key = header['Sec-WebSocket-Key']
  if not sec_key or sec_key == '' then
    return sock:send(ERROR_RESPONSE(http, 505, path, ip, header['X-Forwarded-For'] or ip, method, req_time(start_time)))
  end
  local response = {
    REQUEST_STATUCODE_RESPONSE(101),
    HTTP_DATE(),
    'Server: '..(http.__server or SERVER),
    'Upgrade: WebSocket',
    'Connection: Upgrade',
    'Sec-WebSocket-Accept: '..base64encode(sha1(sec_key..'258EAFA5-E914-47DA-95CA-C5AB0DC85B11'))
  }
  local protocol = header['Sec-Websocket-Protocol']
  if protocol then -- 仅支持协议回传
    response[#response+1] = "Sec-Websocket-Protocol: "..tostring(protocol)
  end
  local ext = nil
  local extension = header['Sec-WebSocket-Extensions']
  if type(extension) == 'string' and extension ~= '' then
    if find(extension, "permessage%-deflate") then
      response[#response+1] = "Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits=15; server_no_context_takeover; client_no_context_takeover"
      ext = "deflate"
    elseif find(extension, "x%-webkit%-deflate%-frame") then
      response[#response+1] = "Sec-WebSocket-Extensions: x-webkit-deflate-frame; no_context_takeover"
      ext = "deflate"
    end
  end
  -- require "utils"
  -- var_dump(header)
  if not sock:send(concat(response, CRLF)..CRLF2) then
    return
  end
  http:tolog(101, path, header['X-Real-IP'] or ip, X_Forwarded_FORMAT(header['X-Forwarded-For'] or ip), method, req_time(start_time))
  return wsserver.start(sock, cls, form_argsencode(path), header, ext)
end

local function send_header (sock, header)
  header[#header+1] = CRLF
  return sock:send(concat(header, CRLF))
end

local function send_body (sock, body, filepath)
  if not body then
    return sock:sendfile(filepath, 65535)
  end
  return sock:send(body)
end

function HTTP_PROTOCOL.DISPATCH(sock, opt, http)
  local buffers = {}
  local ttl = http.ttl
  local server = http.__server or SERVER
  local enable_cookie = http.__enable_cookie
  local enable_gzip = http.__enable_gzip
  local compress_bytes = http.__compress_bytes
  local enable_cros_timeout = http.__enable_cros_timeout
  local cookie_secure = http.__cookie_secure
  local before_func = http.__before_func
  local max_path_size = http.__max_path_size
  local max_header_size = http.__max_header_size
  local max_body_size = http.__max_body_size
  local http_router = http.router
  local route_find = http_router.find
  local tolog = http.tolog
  local ipaddr = opt.ipaddr
  local port = opt.port
  secCookie(cookie_secure) -- 如果需要
  while 1 do
    local buf = sock:recv(8192)
    if not buf then
      return sock:close()
    end
    buffers[#buffers+1] = buf
    local buffer = concat(buffers)
    local CRLF_START, CRLF_END = find(buffer, RE_CRLF2)
    if CRLF_START and CRLF_END then
      local start = now()
      -- 协议有问题返回400
      local METHOD, PATH, VERSION, HEADER = PARSER_HTTP_REQUEST(buffer)
      if not METHOD or not PATH or not VERSION then
        sock:send(ERROR_RESPONSE(http, 400, PATH, HEADER and HEADER['X-Real-IP'] or ipaddr, HEADER and HEADER['X-Forwarded-For'] or ipaddr, METHOD or "GET", req_time(start)))
        return sock:close()
      end
      -- 超过自定义最大PATH长度限制
      if PATH and #PATH > (max_path_size or 1024) then
        sock:send(ERROR_RESPONSE(http, 414, PATH, HEADER and HEADER['X-Real-IP'] or ipaddr, HEADER and HEADER['X-Forwarded-For'] or ipaddr, METHOD, req_time(start)))
        return sock:close()
      end
      -- 没有HEADER返回400
      if not HEADER or not next(HEADER) then
        sock:send(ERROR_RESPONSE(http, 400, PATH, HEADER and HEADER['X-Real-IP'] or ipaddr, HEADER and HEADER['X-Forwarded-For'] or ipaddr, METHOD, req_time(start)))
        return sock:close()
      end
      -- 超过自定义最大HEADER长度限制
      if #buffer - CRLF_START > (max_header_size or 65535) then
        sock:send(ERROR_RESPONSE(http, 431, PATH, HEADER and HEADER['X-Real-IP'] or ipaddr, HEADER and HEADER['X-Forwarded-For'] or ipaddr, METHOD, req_time(start)))
        return sock:close()
      end
      -- 这里根据PATH先查找路由, 如果没有直接返回404.
      -- local cls, typ, rest_args = http_router:find(METHOD, PATH)
      local cls, typ, rest_args = route_find(http_router, METHOD, PATH)
      if not cls or not typ then
        sock:send(ERROR_RESPONSE(http, 404, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, req_time(start)))
        return sock:close()
      end
      -- 根据请求方法进行解析, 解析失败返回501
      local content
      ok, content = PASER_METHOD(http, sock, max_body_size, buffer, METHOD, PATH, HEADER)
      if not ok then
        if content == 413 then
          sock:send(ERROR_RESPONSE(http, 413, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, req_time(start)))
        elseif content ~= null then
          sock:send(ERROR_RESPONSE(http, 501, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, req_time(start)))
        else -- 断开连接
          return sock:close()
        end
        goto CONTINUE
      end
      -- 如果请求使用了 HEAD 与 OPTIONS 方法, 这里会根据配置检查是否需要返回跨域标识. (除非您手动设置请求头部, 否则一般不会遇到此处逻辑.)
      -- 值得一提的是: 由于框架不支持范围请求(Accept-Ranges), 所以目前的处理方式将HEAD与OPTIONS都将返回0. 这样可以有助于快速完成检查请求.
      if not content then
        tolog(http, 200, PATH, HEADER['X-Real-IP'] or ipaddr, X_Forwarded_FORMAT(HEADER['X-Forwarded-For'] or ipaddr), METHOD, req_time(start))
        local res = new_tab(16, 0)
        res[#res+1] = REQUEST_STATUCODE_RESPONSE(200)
        res[#res+1] = HTTP_DATE()
        if enable_cros_timeout then
          cros_append(res, enable_cros_timeout)
        end
        res[#res+1] = 'Server: ' .. server
        res[#res+1] = 'Connection: keep-alive'
        res[#res+1] = 'Content-Length: 0'
        sock:send(concat(res, CRLF)..CRLF2)
        goto CONTINUE
      end
      content['ROUTE'] = HTTP_PROTOCOL[typ]
      content['method'], content['path'], content['headers'], content['client_ip'], content['client_port'] = METHOD, PATH, HEADER, ipaddr, port
      -- before 函数只影响接口与view
      if before_func and (typ == HTTP_PROTOCOL.API or typ == HTTP_PROTOCOL.USE) then
        local code, data
        ok, code, data = safe_call(before_func, tab_copy(content))
        if not ok then -- before 函数执行出错
          Log:ERROR(code)
          sock:send(ERROR_RESPONSE(http, 500, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, req_time(start)))
          goto CONTINUE
        end
        if type(code) == "number" then
          if code == 301 or code == 302 or code == 303 or code == 307 or code == 308 then
            tolog(http, code, PATH, HEADER['X-Real-IP'] or ipaddr, X_Forwarded_FORMAT(HEADER['X-Forwarded-For'] or ipaddr), METHOD, req_time(start))
            sock:send(concat({
              REQUEST_STATUCODE_RESPONSE(code), HTTP_DATE(),
              'Connection: keep-alive',
              'Server: ' .. server,
              'Content-Length: 0',
              'Location: ' .. (data or "https://cfadmin.cn/"),
              CRLF
            }, CRLF))
            goto CONTINUE
          elseif code >= 400 and code < 600 then
            if type(data) == 'string' and data ~= '' then
              tolog(http, code, PATH, HEADER['X-Real-IP'] or ipaddr, X_Forwarded_FORMAT(HEADER['X-Forwarded-For'] or ipaddr), METHOD, req_time(start))
              sock:send(concat({concat({
                REQUEST_STATUCODE_RESPONSE(code), HTTP_DATE(),
                'Server: ' .. server,
                'Connection: keep-alive',
                'Content-Type: ' .. (typ == HTTP_PROTOCOL.API and REQUEST_MIME_RESPONSE('json') or REQUEST_MIME_RESPONSE('html')),
                'Content-Length: ' .. tostring(#data),
              }, CRLF), CRLF2, data}))
              goto CONTINUE
            end
            sock:send(ERROR_RESPONSE(http, code, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, req_time(start)))
            goto CONTINUE
          elseif code ~= 200 then
            Log:ERROR("before function: Illegal return value")
            sock:send(ERROR_RESPONSE(http, 500, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, req_time(start)))
            goto CONTINUE
          end
        else
          sock:send(ERROR_RESPONSE(http, 401, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, req_time(start)))
          goto CONTINUE
        end
      end

      local header = new_tab(16, 0)
      local body, body_len, filepath, static, statucode

      if typ == HTTP_PROTOCOL.API or typ == HTTP_PROTOCOL.USE then
        -- 如果httpd开启了记录Cookie字段, 则每次尝试是否deCookie
        if enable_cookie then
          deCookie(HEADER["Cookie"] or HEADER["cookie"])
        end
        if http_router.enable_rest then
          if content['query'] then
            -- 原则上说，不应该出现 /rest/{id}?id=1 这种设计
            content['query'] = table.rmerge(content['query'], rest_args)
          else
            content['query'] = rest_args
          end
        end
        if type(cls) == "table" then
          local method = cls[lower(METHOD)]
          if not method or type(method) ~= 'function' then -- 注册的路由未实现这个方法
            sock:send(ERROR_RESPONSE(http, 405, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, req_time(start)))
            goto CONTINUE
          end
          local c = cls:new(tab_copy(content))
          ok, body = safe_call(method, c)
        else
          ok, body = safe_call(cls, tab_copy(content))
        end
        -- 如果httpd开启了记录Cookie字段, 则每次尝试是否需要seCookie
        if enable_cookie then
          local Cookies = seCookie()
          for _, Cookie in ipairs(Cookies) do
            header[#header+1] = Cookie
          end
          clCookie()
        end
        if not ok then
          Log:ERROR(body or "empty response.")
          sock:send(ERROR_RESPONSE(http, 500, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, req_time(start)))
          goto CONTINUE
        end
        statucode = 200
        -- 开发者主动`抛出异常`与`重定向`的时候需要特殊处理.
        if type(body) == "table" and body.__OPCODE__ then
          statucode = body.__CODE__
          local opcode = body.__OPCODE__
          if opcode == OPCODE_THROW then -- `异常`构造器
            tolog(http, statucode, PATH, HEADER['X-Real-IP'] or ipaddr, X_Forwarded_FORMAT(HEADER['X-Forwarded-For'] or ipaddr), METHOD, req_time(start))
            if not send_header(sock, { REQUEST_STATUCODE_RESPONSE(statucode), HTTP_DATE(), 'Server: ' .. server, 'Connection: keep-alive', 'Content-Length: ' .. toint(#body.__MSG__), 'Content-Type: ' .. (typ == HTTP_PROTOCOL.API and REQUEST_MIME_RESPONSE('json') or REQUEST_MIME_RESPONSE('html'))}) or not send_body(sock, body.__MSG__) then
              return sock:close()
            end
            -- goto CONTINUE
          elseif opcode == OPCODE_RESP then -- `响应`构造器
            local resp = new_tab(16, 0)
            insert(resp, REQUEST_STATUCODE_RESPONSE(statucode))
            insert(resp, HTTP_DATE())
            insert(resp, 'Server: ' .. server)
            insert(resp, 'Connection: keep-alive')
            insert(resp, 'Content-Length: ' .. (toint(body.__FILESIZE__) or toint(#body.__MSG__)))
            insert(resp, 'Content-Type: ' .. (body.__TYPE__ or body.__FILETYPE__ or "application/octet-stream"))
            if body.__FILETYPE__ then
              insert(resp, fmt('Content-Disposition: %s; filename="%s"', body.__FILEINLINE__ and "inline" or "attachment", body.__FILENAME__:match("[/]?([^/]+)$")))
            end
            tolog(http, statucode, PATH, HEADER['X-Real-IP'] or ipaddr, X_Forwarded_FORMAT(HEADER['X-Forwarded-For'] or ipaddr), METHOD, req_time(start))
            if not send_header(sock, resp) or not send_body(sock, body.__MSG__, body.__FILENAME__) then
              return sock:close()
            end
            -- goto CONTINUE
          elseif opcode == OPCODE_REDIRECT then -- `跳转`构造器
            tolog(http, statucode, PATH, HEADER['X-Real-IP'] or ipaddr, X_Forwarded_FORMAT(HEADER['X-Forwarded-For'] or ipaddr), METHOD, req_time(start))
            send_header(sock, { REQUEST_STATUCODE_RESPONSE(statucode), HTTP_DATE(), 'Server: ' .. server, 'Connection: keep-alive', 'Content-Length: 0', 'Location: ' .. body.__MSG__})
          end
          return sock:close()
        end
        insert(header, 1, REQUEST_STATUCODE_RESPONSE(statucode))
      elseif typ == HTTP_PROTOCOL.WS then
        local ok, msg = safe_call(Switch_Protocol, http, cls, sock, tab_copy(HEADER), METHOD, VERSION, PATH, HEADER['X-Real-IP'] or ipaddr, start)
        if not ok then
          Log:ERROR(msg)
        end
        return sock:close()
      else
        local filetype
        local path = PATH
        local pos, _ = find(PATH, '%?')
        if pos then
          path = split(PATH, 1, pos - 1)
        end
        body_len, filepath, filetype = cls(path)
        if not body_len then
          statucode = 404
          sock:send(ERROR_RESPONSE(http, statucode, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, req_time(start)))
          return sock:close()
        end
        statucode = 200
        header[#header+1] = REQUEST_STATUCODE_RESPONSE(statucode)
        local conten_type = REQUEST_MIME_RESPONSE(lower(filetype or ''))
        if type(conten_type) ~= 'string' then
          -- 确保浏览器提示需要下载
          local s, e = find(filepath, "/[^/]+$")
          header[#header+1] = fmt('Content-Disposition: attachment; filename="%s"', filepath:sub(s + 1, e))
          static = fmt('Content-Type: %s', type(conten_type) ~= "table" and "application/octet-stream" or conten_type.type)
        else
          -- 确保内容展示在浏览器内
          header[#header+1] = 'Content-Disposition: inline'
          static = fmt('Content-Type: %s; charset=utf-8', conten_type)
        end
      end
      header[#header+1] = HTTP_DATE()
      header[#header+1] = 'Accept-Ranges: none'
      header[#header+1] = 'Server: ' .. server
      local Connection = 'Connection: keep-alive'
      local keepalive = HEADER['Connection'] or HEADER['connection']
      if not keepalive or lower(keepalive) == 'close' then
        Connection = 'Connection: close'
      end
      header[#header+1] = Connection
      if typ == HTTP_PROTOCOL.API or typ == HTTP_PROTOCOL.USE then
        if typ == HTTP_PROTOCOL.API then
          header[#header+1] = "Content-Type: application/json; charset=utf-8"
        else
          header[#header+1] = "Content-Type: text/html; charset=utf-8"
        end
        if type(body) ~= 'string' or body == '' then
          Log:ERROR("Response Error ["..(split(PATH , 1, (find(PATH, '?') or 0 ) - 1)).."]: response must be a string and not empty.")
          sock:send(ERROR_RESPONSE(http, 500, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, req_time(start)))
          goto CONTINUE
        end
        local accept_encoding = HEADER['Accept-Encoding'] or HEADER['accept-encoding']
        if type(accept_encoding) == 'string' and enable_gzip and #body >= (toint(compress_bytes) or 128) then
          local ac = lower(accept_encoding)
          -- 压缩选择优先br,其次使用gzip, 最后使用deflate, 如果都没有则使用原始字符串.
          if brcompress and find(ac, "br") then
            local compress_body = brcompress(body)
            if compress_body then
              header[#header+1] = 'Content-Encoding: br'
              body = compress_body
            end
          elseif find(ac, "gzip") then
            local compress_body = gzcompress(body)
            if compress_body then
              header[#header+1] = 'Content-Encoding: gzip'
              body = compress_body
            end
          elseif find(ac, "deflate") then
            local compress_body = decompress(body)
            if compress_body then
              header[#header+1] = 'Content-Encoding: deflate'
              body = compress_body
            end
          end
        end
        header[#header+1] = 'Content-Length: ' .. #body
        header[#header+1] = 'Cache-Control: no-cache, no-store, must-revalidate'
      else
        if ttl then
          header[#header+1] = HTTP_EXPIRES(time() + ttl)
        end
        if body_len then
          header[#header+1] = 'Content-Length: '.. toint(body_len)
        end
        header[#header+1] = static
      end
      -- 如果启用了跨域, 则开启头部支持.
      if enable_cros_timeout then
        cros_append(header, enable_cros_timeout)
      end
      -- 不计算数据传输时间, 仅计算实际回调处理所用时间.
      tolog(http, statucode, PATH, HEADER['X-Real-IP'] or ipaddr, X_Forwarded_FORMAT(HEADER['X-Forwarded-For'] or ipaddr), METHOD, req_time(start))
      -- 根据实际情况分块发送
      if not send_header(sock, header) or not send_body(sock, body, filepath) then
        return sock:close()
      end
      if statucode ~= 200 or Connection ~= 'Connection: keep-alive' then
        return sock:close()
      end
      buffers = {}
    end
    if #buffers ~= 0 and #buffer > (max_header_size or 65535) then
      -- sock:send(ERROR_RESPONSE(http, 431, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, req_time(start)))
      return sock:close()
    end
    -- 大部分情况下不需要主动关闭TCP连接, 这样有利于减少负载均衡器对连接池频繁销毁与建立.
    :: CONTINUE ::
  end
end

function HTTP_PROTOCOL.RAW_DISPATCH(s, opt, http)
  if type(s) == 'table' then
    return HTTP_PROTOCOL.DISPATCH(s, opt, http)
  end
  return HTTP_PROTOCOL.DISPATCH(tcp:new():set_fd(s):timeout(http.__timeout), opt, http)
end

return HTTP_PROTOCOL