local socket = require "internal.socket"
local HTTP = require "protocol.http"
local class = require "class"
-- local dns = require "protocol.dns"


local PARSER_PROTOCOL = HTTP.RESPONSE_PROTOCOL_PARSER
local PARSER_HEAD = HTTP.RESPONSE_HEAD_PARSER
local PARSER_BODY = HTTP.RESPONSE_BODY_PARSER

local find = string.find
local split = string.sub
local insert = table.insert
local spliter = string.gsub

local httpc = class("httpc")

function httpc:ctor(opt)
	self.socket = nil
	self.version = 1.1
	self.SSL = nil
end

function check_ip(ip, version)
	if version == 4 then
	    if #str > 15 and #str < 7 then
	        return 
	    end
	    local num_list = {nil, nil, nil, nil}
	    string.gsub(str, '(%d+)', function (num)
	    	insert(num_list, tonumber(num))
	    end)
	    if #num_list ~= 4 then
	    	return
	    end
	    for num in ipairs(num_list) do
	    	if num < 0 or num > 255 then
	    		return false
	    	end
	    end
	    return true
	end
end

-- 设置User-Agent
function httpc:Set_UA(UA)
	self['User-Agent'] = UA
end

function httpc:get(address, port)
	self.method = "GET"
	local PORT = port or 80
	local PROTOCOL, IP, PATH
	spliter(address, '(http[s]*)://([%w%.%-]+)(.*)', function (protocol, domain, path)
		if protocol then
			if protocol == "https" then
				PROTOCOL = protocol
				self.SSL = true
			end
			if protocol == "http" then
				PROTOCOL = protocol
			end
		end
		IP = domain
		PATH = path
	end)
	if not PROTOCOL then
		return nil, "Invaild protocol."
	end
	if not IP then
		return nil, "Invaild domain or ip address."
	end
	-- if not check_ip(IP, 4) then
	-- 	IP = dns.resolve(IP)
	-- 	if not IP then
	-- 		return nil, "Can't resolve domain."
	-- 	end
	-- end
	if not self.socket then
		self.socket = socket:new()
	end
	local ok = self.socket:connect(IP, PORT)
	if not ok then
		return nil, "Can't connect to this IP and Port."
	end
	local ok = self.socket:write("GET / HTTP/1.1\r\n\r\n")
	if not ok then
		return nil, "Can't connect to this IP and Port."
	end
	return self:response()
end



function httpc:response()
	if not self.socket then
		return nil, "Can't used this method before other httpc method.."
	end
	local RESPONSE = ''
	local response = {
		Header = { },
	}
	local socket = self.socket
	local next_step = 1
	-- local file = io.open("./index.html", 'w')
	local TOTLE, HEAD, BODY = 0, 0, 0
	while 1 do
		local data = socket:readall()
		if not data then
			return nil
		end
		-- file:write(data)
		-- file:flush()
		RESPONSE = RESPONSE .. data
		if next_step == 1 then
			local header_start, header_end = find(RESPONSE, '\r\n\r\n')
			if header_start and header_end then
				local HEAD = header_end
				local protocol_start, protocol_end = find(RESPONSE, '\r\n')
				if not protocol_start or not protocol_end then
					return nil, "Invaild HTTP protocol."
				end
				local CODE = PARSER_PROTOCOL(response, split(RESPONSE, 1, protocol_start - 1))
				if CODE ~= 200 then
					return nil, "Invaild protocol header."
				end
				PARSER_HEAD(response['Header'], split(RESPONSE, protocol_end + 1, header_end))
				next_step = next_step + 1
			end
		end
		if next_step == 2 then

		end
	end
end


function httpc:close()
	return self.socket.close()
end




return httpc