local tcp = require "internal.TCP"
local HTTP = require "protocol.http"
local class = require "class"
-- local dns = require "protocol.dns"

local PARSER_PROTOCOL = HTTP.RESPONSE_PROTOCOL_PARSER
local PARSER_HEAD = HTTP.RESPONSE_HEAD_PARSER
local PARSER_BODY = HTTP.RESPONSE_BODY_PARSER

local find = string.find
local split = string.sub
local spliter = string.gsub

local insert = table.insert
local concat = table.concat

local fmt = string.format

local HTTPC = "cf/0.1"

local httpc = class("httpc")

function httpc:ctor(opt)
	self.socket = nil
	self.version = 1.1
	self.SSL = nil
	self.Invaild = nil
end

function check_ip(ip, version)
	if version == 4 then
	    if #ip > 15 or #ip < 7 then
	        return false
	    end
	    local num_list = {nil, nil, nil, nil}
	    string.gsub(ip, '(%d+)', function (num)
	    	insert(num_list, tonumber(num))
	    end)
	    if #num_list ~= 4 then
			return false
	    end
	    for _, num in ipairs(num_list) do
	    	if num < 0 or num > 255 then
	    		return false
	    	end
	    end
	    return true
	end
end

-- 设置请求超时时间
function httpc:set_timeout(Invaild)
	if Invaild > 0 then
		self.Invaild = Invaild
	end
end

-- 处理接口重定向
function httpc:redirect( ... )
	-- body
end

function httpc:get(domain, port)
	-- if self.domain or self.port then
	-- 	return 
	-- end
	self.method = "GET"
	self.domain = domain
	self.port = port or 80
	local PROTOCOL, IP, PATH
	spliter(domain, '(http[s]*)://([%w%.%-]+)(.*)', function (protocol, domain, path)
		if protocol then
			if protocol == "https" then
				PROTOCOL = protocol
				self.SSL = true
			end
			if protocol == "http" then
				PROTOCOL = protocol
			end
		end
		self.ip = domain
		self.path = path
	end)
	if not PROTOCOL then
		return nil, "Invaild protocol."
	end
	if not self.domain then
		return nil, "Invaild domain or ip address."
	end
	-- if not check_ip(self.ip, 4) then
	-- 	self.ip = dns.resolve(self.domain)
	-- 	if not self.ip then
	-- 		return nil, "Can't resolve this domain."
	-- 	end
	-- end
	if not self.tcp then
		self.tcp = tcp:new()
	end
	local ok = self.tcp:connect(self.ip, self.port)
	if not ok then
		self.tcp:close()
		return nil, "Can't connect to this IP and Port."
	end
	local request = {
		fmt("GET %s HTTP/1.1", self.path or '/'),
		fmt("Host: %s", 'www.qq.com' or self.domain),
		fmt("Connect: Keep-Alive"),
		fmt("User-Agent: %s", self['User-Agent'] or HTTPC),
		'\r\n'
	}
	local ok = self.tcp:send(concat(request, '\r\n'))
	if not ok then
		self.tcp:close()
		return nil, "Can't connect to this IP and Port."
	end
	return self:response()
end



function httpc:response()
	if not self.tcp then
		return nil, "Can't used this method before other httpc method.."
	end
	local RESPONSE = ''
	local response = {
		Header = { },
	}
	local tcp = self.tcp
	local CODE, HEAD, BODY
	local Content_Length
	local content = {}
	local times = 0
	while 1 do
		local data = tcp:recvall()
		if not data then
			return nil, "A peer of remote close this connection."
		end
		insert(content, data)
		if times == 0 then
			local DATA = concat(content)
			local posA, posB = find(DATA, '\r\n\r\n')
			if posA and posB then
				if #DATA > posB then
					content = {}
					insert(content, split(DATA, posB + 1, -1))
				end
				local protocol_start, protocol_end = find(DATA, '\r\n')
				if not protocol_start or not protocol_end then
					return nil, "can't resolvable protocol."
				end
				CODE = PARSER_PROTOCOL(split(DATA, 1, protocol_end))
				HEAD = PARSER_HEAD(split(DATA, 1, posA + 1))
				if not HEAD['Content-Length'] then
					break
				end
				Content_Length = HEAD['Content-Length']
				times = times + 1
			end
		end
		if times > 0 then
			BODY = concat(content)
			if #BODY >= Content_Length then
				break
			end
		end
	end
	return CODE, BODY
end


function httpc:close()
	self.tcp:close()
	self.tcp = nil
end


return httpc