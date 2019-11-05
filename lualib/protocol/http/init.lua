local log = require "logging"
local sys = require "system"
local tcp = require "internal.TCP"
local wsserver = require "protocol.websocket.server"

local Log = log:new({ dump = true, path = 'protocol-http'})

local crypt = require "crypt"
local sha1 = crypt.sha1
local base64encode = crypt.base64encode
local now = sys.now
local DATE = require("sys").date
local new_tab = require("sys").new_tab
local insert = table.insert

local form = require "httpd.Form"
local FILE_TYPE = form.FILE
local ARGS_TYPE = form.ARGS
local form_multipart = form.multipart
local form_urlencode = form.urlencode

local Cookie = require "httpd.Cookie"
local clCookie = Cookie.clean   -- 清理
local secCookie = Cookie.setSecure -- 设置Cookie加密字段
local seCookie = Cookie.serialization -- 序列化
local deCookie = Cookie.deserialization -- 反序列化

local Router = require "httpd.Router"
local ROUTE_FIND = Router.find
local ROUTE_REGISTERY = Router.registery

local type = type
local tostring = tostring
local next = next
local pcall = pcall
local ipairs = ipairs
local time = os.time
local lower = string.lower
local upper = string.upper
local match = string.match
local fmt = string.format
local ceil = math.ceil
local toint = math.tointeger
local find = string.find
local split = string.sub
local splite = string.gmatch
local spliter = string.gsub
local remove = table.remove
local concat = table.concat

local CRLF = '\x0d\x0a'
local CRLF2 = '\x0d\x0a\x0d\x0a'
local RE_CRLF2 = '[\x0d]?\x0a[\x0d]?\x0a'
local COMMA = '\x2c'

local SERVER = 'cf web/0.1'

local HTTP_CODE = require "protocol.http.code"

local MIME = require "protocol.http.mime"

local HTTP_PARSER = require "protocol.http.parser"
local PARSER_HTTP_REQUEST = HTTP_PARSER.PARSER_HTTP_REQUEST
local PARSER_HTTP_RESPONSE = HTTP_PARSER.PARSER_HTTP_RESPONSE
local RESPONSE_CHUNKED_PARSER = HTTP_PARSER.RESPONSE_CHUNKED_PARSER

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

-- -- 路由注册
HTTP_PROTOCOL.ROUTE_REGISTERY = ROUTE_REGISTERY

-- -- 路由查找
HTTP_PROTOCOL.ROUTE_FIND = ROUTE_FIND

local function HTTP_DATE()
  return DATE("Date: %a, %d %b %Y %X GMT")
  -- return os.date("Date: %a, %d %b %Y %X GMT")
end

local function HTTP_EXPIRES(timestamp)
  return DATE("Expires: %a, %d %b %Y %X GMT", timestamp)
  -- return os.date("Date: %a, %d %b %Y %X GMT")
end

local function PASER_METHOD(http, sock, max_body_size, buffer, METHOD, PATH, HEADER)
  local content = new_tab(0, 8)
  if METHOD == "GET" then
    local spl_pos = find(PATH, '%?')
    if spl_pos and spl_pos < #PATH then
      content['args'] = form_urlencode(PATH)
    end
  elseif METHOD == "POST" or METHOD == "PUT" then
    local body_len = toint(HEADER['Content-Length']) or toint(HEADER['Content-length'])
    if body_len and body_len > 0 then
      local BODY = ''
      local RECV_BODY = true
      local CRLF_START, CRLF_END = find(buffer, CRLF2)
      if #buffer > CRLF_END then
        BODY = split(buffer, CRLF_END + 1, -1)
        if #BODY == body_len then
          RECV_BODY = false
        end
      end
      if RECV_BODY then
        local buf_len = #BODY
        local buffers = body_len > 65535 and new_tab(ceil(body_len / 65535), 0) or {}
        while 1 do
          local buf, len = sock:recv(65535)
          if not buf then
            return
          end
          buf_len = buf_len + len
          if buf_len >= (max_body_size or 1024 * 1024) then
            return nil, 413
          end
          buffers[#buffers + 1] = buf
          if buf_len == body_len then
            BODY = concat(buffers)
            break
          end
        end
      end
      local FILE_ENCODE = 'multipart/form-data'
      local XML_ENCODE_1  = 'text/xml'
      local XML_ENCODE_2  = 'application/xml'
      local JSON_ENCODE = 'application/json'
      local URL_ENCODE  = 'application/x-www-form-urlencoded'
      local format = match(HEADER['Content-type'] or HEADER['Content-Type'] or '', '(.-/[^;]*)')
      if format == FILE_ENCODE then
        local BOUNDARY = match(HEADER['Content-Type'], '^.+=[%-]*(.+)')
        if BOUNDARY and BOUNDARY ~= '' then
          local typ, body = form_multipart(BODY, BOUNDARY)
          if typ == FILE_TYPE then
            content['files'] = body
          elseif typ == ARGS_TYPE then
            content['args'] = {}
            for _, args in ipairs(body) do
              content['args'][args[1]] = args[2]
            end
          end
        end
      elseif format == JSON_ENCODE then
        content['json'] = true
        content['body'] = BODY
      elseif format == XML_ENCODE_1 or format == XML_ENCODE_2 then
        content['xml'] = true
        content['body'] = BODY
      elseif format == URL_ENCODE then
        content['args'] = form_urlencode(BODY)
      else
        content['body'] = BODY
      end
    end
  elseif METHOD == "HEAD" or METHOD == "OPTIONS" then
    return true, nil
  else
    -- 暂未支持其他方法
    return
  end
  return true, content
end

local function X_Forwarded_FORMAT(ip_list)
  if find(ip_list, ',') then
    return ip_list:gsub(COMMA, "->")
  end
  return ip_list
end
-- 一些错误返回
local function ERROR_RESPONSE(http, code, path, ip, forword, method, speed)
  http:tolog(code, path, ip, X_Forwarded_FORMAT(forword) or ip, method, speed)
  return concat({concat({
    REQUEST_STATUCODE_RESPONSE(code),
    HTTP_DATE(),
    'Origin: *',
    'Allow: GET, POST, PUT, HEAD, OPTIONS',
    'Connection: close',
    'Content-length: 0',
    'Server: ' .. (http.__server or SERVER),
  }, CRLF), CRLF2})
end

-- WebSocket
local function Switch_Protocol(http, cls, sock, header, method, version, path, ip, start_time)
  if method ~= 'GET' then
    return sock:send(ERROR_RESPONSE(http, 400, path, ip, header['X-Forwarded-For'] or ip, method, now() - start_time))
  end
  if version ~= 1.1 then
    return sock:send(ERROR_RESPONSE(http, 400, path, ip, header['X-Forwarded-For'] or ip, method, now() - start_time))
  end
  if not header['Upgrade'] or lower(header['Upgrade']) ~= 'websocket' then
    return sock:send(ERROR_RESPONSE(http, 401, path, ip, header['X-Forwarded-For'] or ip, method, now() - start_time))
  end
  if header['Sec-WebSocket-Version'] ~= '13' then
    return sock:send(ERROR_RESPONSE(http, 403, path, ip, header['X-Forwarded-For'] or ip, method, now() - start_time))
  end
  local sec_key = header['Sec-WebSocket-Key']
  if not sec_key or sec_key == '' then
    return sock:send(ERROR_RESPONSE(http, 505, path, ip, header['X-Forwarded-For'] or ip, method, now() - start_time))
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
  http:tolog(101, path, header['X-Real-IP'] or ip, X_Forwarded_FORMAT(header['X-Forwarded-For'] or ip), method, now() - start_time)
  local ok = sock:send(concat(response, CRLF)..CRLF2)
  if not ok then
    return
  end
  return wsserver:new({cls = cls, sock = sock}):start()
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

function HTTP_PROTOCOL.EVENT_DISPATCH(fd, ipaddr, http)
  local buffers = {}
  local ttl = http.ttl
  local server = http.__server
  local timeout = http.__timeout or 0
  local cookie = http.__cookie
  local cookie_secure = http.__cookie_secure
  local before_func = http._before_func
  local max_path_size = http.__max_path_size
  local max_header_size = http.__max_header_size
  local max_body_size = http.__max_body_size
  secCookie(cookie_secure) -- 如果需要
  local sock = tcp:new():set_fd(fd):timeout(timeout)
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
        sock:send(ERROR_RESPONSE(http, 400, PATH, HEADER and HEADER['X-Real-IP'] or ipaddr, HEADER and HEADER['X-Forwarded-For'] or ipaddr, METHOD or "GET", now() - start))
        return sock:close()
      end
      -- 超过自定义最大PATH长度限制
      if PATH and #PATH > (max_path_size or 1024) then
        sock:send(ERROR_RESPONSE(http, 414, PATH, HEADER and HEADER['X-Real-IP'] or ipaddr, HEADER and HEADER['X-Forwarded-For'] or ipaddr, METHOD, now() - start))
        return sock:close()
      end
      -- 没有HEADER返回400
      if not HEADER or not next(HEADER) then
        sock:send(ERROR_RESPONSE(http, 400, PATH, HEADER and HEADER['X-Real-IP'] or ipaddr, HEADER and HEADER['X-Forwarded-For'] or ipaddr, METHOD, now() - start))
        return sock:close()
      end
      -- 超过自定义最大HEADER长度限制
      if #buffer - CRLF_START > (max_header_size or 65535) then
        sock:send(ERROR_RESPONSE(http, 431, PATH, HEADER and HEADER['X-Real-IP'] or ipaddr, HEADER and HEADER['X-Forwarded-For'] or ipaddr, METHOD, now() - start))
        return sock:close()
      end
      -- 这里根据PATH先查找路由, 如果没有直接返回404.
      local cls, typ = ROUTE_FIND(METHOD, PATH)
      if not cls or not typ then
        sock:send(ERROR_RESPONSE(http, 404, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, now() - start))
        return sock:close()
      end
      -- 根据请求方法进行解析, 解析失败返回501
      local ok, content = PASER_METHOD(http, sock, max_body_size, buffer, METHOD, PATH, HEADER)
      if not ok then
        if content == 413 then
          sock:send(ERROR_RESPONSE(http, 413, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, now() - start))
          return sock:close()
        end
        sock:send(ERROR_RESPONSE(http, 501, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, now() - start))
        return sock:close()
      end
      if not content then -- 没有 Content则返回200;
        http:tolog(200, PATH, HEADER['X-Real-IP'] or ipaddr, X_Forwarded_FORMAT(HEADER['X-Forwarded-For'] or ipaddr), METHOD, now() - start)
        sock:send(concat({REQUEST_STATUCODE_RESPONSE(200), HTTP_DATE(),
          'Origin: *',
          'Allow: GET, POST, PUT, HEAD, OPTIONS',
          'Access-Control-Allow-Origin: *',
          'Access-Control-Allow-Headers: *',
          'Access-Control-Allow-Methods: GET, POST, PUT, HEAD, OPTIONS',
          'Access-Control-Allow-Credentials: true',
          'Access-Control-Max-Age: 86400',
          'Connection: keep-alive',
          'Server: ' .. (server or SERVER),
        }, CRLF)..CRLF2)
        return sock:close()
      end
      content['ROUTE'] = HTTP_PROTOCOL[typ]
      content['method'], content['path'], content['headers'] = METHOD, PATH, HEADER
      -- before 函数只影响接口与view
      if before_func and (typ == HTTP_PROTOCOL.API or typ == HTTP_PROTOCOL.USE) then
        local ok, code, data = pcall(before_func, content)
        if not ok then -- before 函数执行出错
          Log:ERROR(code)
          sock:send(ERROR_RESPONSE(http, 500, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, now() - start))
          return sock:close()
        end
        if code then
          if type(code) == "number" then
            if code < 200 or code > 500 then
              Log:ERROR("before function: Illegal return value")
              sock:send(ERROR_RESPONSE(http, 500, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, now() - start))
              return sock:close()
            elseif code == 301 or code == 302 then
              http:tolog(code, PATH, HEADER['X-Real-IP'] or ipaddr, X_Forwarded_FORMAT(HEADER['X-Forwarded-For'] or ipaddr), METHOD, now() - start)
              sock:send(concat({
                REQUEST_STATUCODE_RESPONSE(code), HTTP_DATE(),
                'Connection: close',
                'Server: ' .. (server or SERVER),
                'Location: ' .. (data or "https://github.com/CandyMi/core_framework"),
              }, CRLF)..CRLF2)
              return sock:close()
            elseif code ~= 200 then
              if data then
                if type(data) == 'string' and data ~= '' then
                  http:tolog(code, PATH, HEADER['X-Real-IP'] or ipaddr, X_Forwarded_FORMAT(HEADER['X-Forwarded-For'] or ipaddr), METHOD, now() - start)
                  sock:send(concat({concat({
                    REQUEST_STATUCODE_RESPONSE(code), HTTP_DATE(),
                    'Origin: *',
                    'Allow: GET, POST, PUT, HEAD, OPTIONS',
                    'Server: ' .. (server or SERVER),
                    'Connection: close',
                    'Content-Type: ' .. REQUEST_MIME_RESPONSE('html'),
                    'Content-Length: '..tostring(#data),
                  }, CRLF), CRLF2, data}))
                  return sock:close()
                end
              end
              sock:send(ERROR_RESPONSE(http, code, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, now() - start))
              return sock:close()
            end
          else
            sock:send(ERROR_RESPONSE(http, 401, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, now() - start))
            return sock:close()
          end
        else
          sock:send(ERROR_RESPONSE(http, 401, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, now() - start))
          return sock:close()
        end
      end

      local header = new_tab(16, 0)
      local ok, body, body_len, filepath, static, statucode

      if typ == HTTP_PROTOCOL.API or typ == HTTP_PROTOCOL.USE then
        -- 如果httpd开启了记录Cookie字段, 则每次尝试是否deCookie
        if cookie and typ == HTTP_PROTOCOL.USE then
          deCookie(content['headers']["Cookie"])
        end
        if type(cls) == "table" then
          local method = cls[lower(METHOD)]
          if not method or type(method) ~= 'function' then -- 注册的路由未实现这个方法
            sock:send(ERROR_RESPONSE(http, 405, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, now() - start))
            return sock:close()
          end
          local c = cls:new(content)
          ok, body = pcall(method, c)
        else
          ok, body = pcall(cls, content)
        end
        -- 如果httpd开启了记录Cookie字段, 则每次尝试是否需要seCookie
        if cookie and typ == HTTP_PROTOCOL.USE then
          local Cookies = seCookie()
          for _, Cookie in ipairs(Cookies) do
            header[#header+1] = Cookie
          end
          clCookie()
        end
        if not ok then
          Log:ERROR(body or "empty response.")
          sock:send(ERROR_RESPONSE(http, 500, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, now() - start))
          return sock:close()
        end
        statucode = 200
        insert(header, 1, REQUEST_STATUCODE_RESPONSE(statucode))
      elseif typ == HTTP_PROTOCOL.WS then
        local ok, msg = pcall(Switch_Protocol, http, cls, sock, HEADER, METHOD, VERSION, PATH, HEADER['X-Real-IP'] or ipaddr, start)
        if not ok then
          Log:ERROR(msg)
        end
        return sock:close()
      else
        local file_type
        local path = PATH
        local pos, _ = find(PATH, '%?')
        if pos then
          path = split(PATH, 1, pos - 1)
        end
        body_len, filepath, file_type = cls(path)
        if not body_len then
          statucode = 404
          sock:send(ERROR_RESPONSE(http, statucode, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, now() - start))
          return sock:close()
        end
        statucode = 200
        header[#header+1] = REQUEST_STATUCODE_RESPONSE(statucode)
        local conten_type = REQUEST_MIME_RESPONSE(lower(file_type or ''))
        if not conten_type then
          header[#header+1] = 'Content-Disposition: attachment' -- 确保浏览器提示需要下载
          static = fmt('Content-Type: %s', 'application/octet-stream')
        else
          static = fmt('Content-Type: %s', conten_type..'; charset=utf-8')
        end
        -- 如果是静态文件, 增加默认跨域访问支持
        header[#header+1] = "Access-Control-Allow-Origin: *"
      end
      header[#header+1] = HTTP_DATE()
      header[#header+1] = 'Origin: *'
      header[#header+1] = 'Allow: GET, POST, PUT, HEAD, OPTIONS'
      header[#header+1] = 'Server: ' .. (server or SERVER)
      local Connection = 'Connection: keep-alive'
      if not HEADER['Connection'] or lower(HEADER['Connection']) == 'close' then
        Connection = 'Connection: close'
      end
      header[#header+1] = Connection
      if Connection == 'Connection: keep-alive' then
        header[#header+1] = "Keep-Alive: timeout="..(timeout <= 0 and 86400 or timeout)..', max='..(1 << 12)
      end
      if typ == HTTP_PROTOCOL.API or typ == HTTP_PROTOCOL.USE then
        if typ == HTTP_PROTOCOL.API then
          header[#header+1] = 'Content-Type: ' .. REQUEST_MIME_RESPONSE('json') .. "; charset=utf-8"
        else
          header[#header+1] = 'Content-Type: ' .. REQUEST_MIME_RESPONSE('html') .. "; charset=utf-8"
        end
        if type(body) ~= 'string' or body == '' then
          Log:ERROR("Response Error ["..(split(PATH , 1, (find(PATH, '?') or 0 ) - 1)).."]: response must be a string and not empty.")
          sock:send(ERROR_RESPONSE(http, 500, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, now() - start))
          return sock:close()
        end
        header[#header+1] = 'Content-Length: '.. #body
        header[#header+1] = 'Cache-Control: no-cache, no-store, must-revalidate'
        header[#header+1] = 'Cache-Control: no-cache'
      else
        if ttl then
          header[#header+1] = HTTP_EXPIRES(time() + ttl)
        end
        if body_len then
          header[#header+1] = 'Content-Length: '.. body_len
        end
        header[#header+1] = static
      end
      -- 不计算数据传输时间, 仅计算实际回调处理所用时间.
      http:tolog(statucode, PATH, HEADER['X-Real-IP'] or ipaddr, X_Forwarded_FORMAT(HEADER['X-Forwarded-For'] or ipaddr), METHOD, now() - start)
      -- 根据实际情况分块发送
      local ok = send_header(sock, header) and send_body(sock, body, filepath) or false
      if not ok then
        return sock:close()
      end
      if statucode ~= 200 or Connection ~= 'Connection: keep-alive' then
        return sock:close()
      end
      buffers = {}
    end
    if #buffers ~= 0 and #buffer > (max_header_size or 65535) then
      sock:send(ERROR_RESPONSE(http, 431, PATH, HEADER['X-Real-IP'] or ipaddr, HEADER['X-Forwarded-For'] or ipaddr, METHOD, now() - start))
      return sock:close()
    end
  end
end

return HTTP_PROTOCOL
