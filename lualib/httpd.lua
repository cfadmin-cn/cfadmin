local tcp = require "internal.TCP"
local HTTP = require "protocol.http"
local log = require "log"

local tostring = tostring
local co_new = coroutine.create
local co_start = coroutine.resume
local co_wakeup = coroutine.resume
local co_suspend = coroutine.yield
local co_self = coroutine.running


-- 请求解析
local EVENT_DISPATCH = HTTP.EVENT_DISPATCH

-- 注册HTTP路由
local HTTP_ROUTE_REGISTERY = HTTP.ROUTE_REGISTERY

local class = require "class"

local httpd = class("httpd")

function httpd:ctor(opt)
	self.cos = {}
    self.routes = {}
    self.IO = nil
end

-- 用来注册Rest API
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
        HTTP_ROUTE_REGISTERY(self.routes, './'..foldor, function (path)
            if path then
                local FILE = io.open(path, "rb")
                if not FILE then
                    return
                end
                local file = FILE:read('*a')
                FILE:close()
                return file, string.match(path, '.+%.([%a]+)')
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

function httpd:log(path)
    self.logpath = path or "cf-httpd.log"
end

function httpd:registery(co, fd, ipaddr)
	if type(co) == "thread" then
		self.cos[co] = {fd = fd, ipaddr = ipaddr}
	end
end

function httpd:unregistery(co)
	if type(co) == "thread" then
		self.cos[co] = nil
	end
end

function httpd:listen (ip, port)
	self.IO = tcp:new()
    self.accept_co = co_new(function (fd, ipaddr)
        while 1 do
        	if fd and ipaddr then
        		local ok, msg = co_start(co_new(function (fd, ipaddr)
                    -- 注册协程
                    self:registery(co_self(), fd, ipaddr)
                    -- HTTP 生命周期
                    EVENT_DISPATCH(fd, ipaddr, self)
                    -- 清除协程
                    self:unregistery(co_self())
                end), fd, ipaddr)
        		if not ok then
        			log.error(msg)
        		end
        	end
            fd, ipaddr = co_suspend()
        end
    end)
    log.outfile = self.logpath or "cf-httpd.log"
    return self.IO:listen(ip, port, self.accept_co)
end

function httpd:start(ip, port)
	return self:listen(ip, port)
end

return httpd
