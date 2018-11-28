local Loop = require "internal.Loop"
local tcp = require "internal.TCP"
local HTTP = require "protocol.http"

local co_new = coroutine.create
local co_start = coroutine.resume
local co_wakeup = coroutine.resume
local co_suspend = coroutine.yield
local co_self = coroutine.running

local int = math.integer
local find = string.find
local split = string.sub
local insert = table.insert
local remove = table.remove
local concat = table.concat

local REQUEST_HEADER_PARSER = HTTP.REQUEST_HEADER_PARSER
local REQUEST_PROTOCOL_PARSER = HTTP.REQUEST_PROTOCOL_PARSER
local REQUEST_ERROR_RESPONSE = HTTP.REQUEST_ERROR_RESPONSE

local class = require "class"

local httpd = class("httpd")

function httpd:ctor(opt)
	self.cos = {}
    self.api_list = {}
    self.use_list = {}
    self.IO = nil
end

-- 用来注册Rest API
function httpd:api(route, cb_or_t)
    
end

-- 用来注册普通路由
function httpd:use(route, cb_or_t)
    -- body
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
        		local co = co_new(function (fd, ipaddr)
                    local co = co_self()
                    self:registery(co, fd, ipaddr)
                    local socket = tcp:new():set_fd(fd)--:timeout(100)
                    local METHOD, PATH, VERSION, HEADER
                    local REQ = {}
                    local buffers = {}
                    while 1 do
                        local buf, len = socket:recv(2048)
                        if not buf then
                            self:unregistery(co)
                            return socket:close()
                        end
                        insert(buffers, buf)
                        local buffer = concat(buffers)
                        local PROTOCOL_START, PROTOCOL_END = find(buffer, "\r\n")
                        if PROTOCOL_START and PROTOCOL_END then
                            REQ["METHOD"], REQ["PATH"], REQ["VERSION"] = REQUEST_PROTOCOL_PARSER(split(buffer, 1, PROTOCOL_END))
                            if not REQ["METHOD"] or not REQ["PATH"] or not REQ["VERSION"] then
                                self:unregistery(co)
                                socket:send(REQUEST_ERROR_RESPONSE(400))
                                return socket:close()
                            end
                            local HEADER_START, HEADER_END = find(buffer, "\r\n\r\n")
                            if HEADER_START and HEADER_END then
                                REQ["HEADER"] = REQUEST_HEADER_PARSER(split(buffer, PROTOCOL_END, HEADER_START))
                            end
                            if REQ["HEADER"]['Content-Type'] then
                                local body_size = int(REQ["HEADER"]['Content-Type'])
                                if body_size and REQ["METHOD"] == "POST" then

                                end
                            end
                        end
                        --
                    end
                end)
        		local ok, msg = co_start(co, fd, ipaddr)
        		if not ok then
        			print(msg)
        		end
        	end
            fd, ipaddr = co_suspend()
        end
    end)
    self.IO:listen(ip, port, self.accept_co)
	return Loop.run()
end

function httpd:start(ip, port)
	return self:listen(ip, port)
end

return httpd
