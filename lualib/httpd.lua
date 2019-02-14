local HTTP = require "protocol.http"
local tcp = require "internal.TCP"
local Co = require "internal.Co"
local class = require "class"
local log = require "log"

local type = type
local ipairs = ipairs

local fmt = string.format
local match = string.match
local io_open = io.open
local os_date = os.date
local os_time = os.time

-- 请求解析
local EVENT_DISPATCH = HTTP.EVENT_DISPATCH

-- 注册HTTP路由
local HTTP_ROUTE_REGISTERY = HTTP.ROUTE_REGISTERY

local httpd = class("httpd")

function httpd:ctor(opt)
    self.API = HTTP.API
    self.USE = HTTP.USE
    self.routes = {}
    self.IO = tcp:new()
end

-- 用来注册WebSocket对象
function httpd:ws(route, class)
    if route and type(class) == "table" then
        HTTP_ROUTE_REGISTERY(self.routes, route, class, HTTP.WS)
    end
end

-- 用来注册接口
function httpd:api(route, class)
    if route and (type(class) == "table" or type(class) == "function")then
        HTTP_ROUTE_REGISTERY(self.routes, route, class, HTTP.API)
    end
end

-- 用来注册普通路由
function httpd:use(route, class)
    if route and (type(class) == "table" or type(class) == "function") then
        HTTP_ROUTE_REGISTERY(self.routes, route, class, HTTP.USE)
    end
end

-- 批量路由注册
function httpd:group(target, prefix, array)
    assert((target == self.API or target == self.USE) and type(prefix) == 'string' and type(array) == 'table' , "注册路由组失败")
    for _, route in ipairs(array) do
        local r, c = route['route'], route['class']
        if target == self.USE then
            self:use(prefix..r, c)
        else
            self:api(prefix..r, c)
        end
    end
end

-- 最大URI长度
function httpd:max_path_size(path_size)
    if type(path_size) == 'number' then
        self.__max_path_size = path_size
    end
end

-- 最大Header长度
function httpd:max_header_size(header_size)
    if type(header_size) == 'number' then
        self.__max_header_size = header_size
    end
end

-- 最大Body长度
function httpd:max_body_size(body_size)
    if type(body_size) == 'number' then
        self.__max_body_size = body_size
    end
end

-- 在路由函数被执行之后执行此方法
function httpd:before(func)
    if type(func) == 'function' then
        self._before_func = func
    end
end

-- 可自定义Server Name
function httpd:server_name(server)
    if type(server) == "string" then
        self.__server = server
    end
end

function httpd:timeout(timeout)
    if type(timeout) == "number" then
        self.__timeout = timeout
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
                local FILE = io_open(path, "rb")
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

-- 记录日志到文件
function httpd:log(path)
    self.logpath = path or "cf-httpd.log"
    log.outfile = self.logpath
end

function httpd:tolog(code, path, ip, ip_list)
    if self.logpath then
        if not self.logfile then
            local err
            self.logfile, err = io_open(self.logpath, "a")
            if not self.logfile then
                return log.error(self.logpath..":"..err)
            end
        end
        local ok, err = self.logfile:write(fmt("[%s] - %s - %s - %s - %d\r\n", os_date("%Y/%m/%d %H:%M:%S"), ip, ip_list, path, code))
        if not ok then
            return log.error(self.logpath..":"..err)
        end
        self.logfile:flush()
    end
end

-- 监听请求
function httpd:listen(ip, port)
    return self.IO:listen(ip, port, function (fd, ipaddr)
        return EVENT_DISPATCH(fd, ipaddr, self)
    end)
end

-- 正确的运行方式
function httpd:run()
    return Co.wait()
end

return httpd