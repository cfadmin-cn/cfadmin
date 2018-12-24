local HTTP = require "protocol.http"
local tcp = require "internal.TCP"
local log = require "log"

-- 请求解析
local EVENT_DISPATCH = HTTP.EVENT_DISPATCH

-- 注册HTTP路由
local HTTP_ROUTE_REGISTERY = HTTP.ROUTE_REGISTERY

local class = require "class"

local httpd = class("httpd")

function httpd:ctor(opt)
    self.routes = {}
    self.IO = tcp:new()
end

-- 用来注册接口
function httpd:api(route, class)
    if route and type(class) == "table" then
        HTTP_ROUTE_REGISTERY(self.routes, route, class, HTTP.API)
    end
end

-- 用来注册普通路由
function httpd:use(route, class)
    if route and type(class) == "table" then
        HTTP_ROUTE_REGISTERY(self.routes, route, class, HTTP.USE)
    end
end

-- 注册静态文件读取路径, foldor是一个目录, ttl是静态文件缓存周期
function httpd:static(foldor, ttl)
    if foldor and type(foldor) == 'string' and #foldor > 0 then
        ttl = math.tointeger(ttl)
        if ttl and ttl > 0 then
            self.ttl = ttl
        end
        local match = string.match
        HTTP_ROUTE_REGISTERY(self.routes, './'..foldor, function (path)
            if path then
                local FILE = io.open(path, "rb")
                if not FILE then
                    return
                end
                local file = FILE:read('*a')
                FILE:close()
                return file, match(path, '.+%.([%a]+)')
            end
        end, HTTP.STATIC)
    end
end

-- 最大http request body长度
function httpd:set_max_body_size(body_size)
    if body_size and int(body_size) and int(body_size) > 0 then
        self._max_body_size = body_size
    end
end

-- 最大http request header长度
function httpd:set_max_header_size(header_size)
    if header_size and int(header_size) and int(header_size) > 0 then
        self._max_header_size = header_size
    end
end

-- 记录日志到文件
function httpd:log(path)
    self.logpath = path or "cf-httpd.log"
    log.outfile = self.logpath
end

-- 监听请求
function httpd:listen (ip, port)
    return self.IO:listen(ip, port, function (fd, ipaddr)
        return EVENT_DISPATCH(fd, ipaddr, self)
    end)
end

-- 正确的运行方式
function httpd:run()
    while 1 do coroutine.yield() end
end

return httpd
