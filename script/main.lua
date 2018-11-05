-- local httpd = require "httpd"

-- local app = httpd:new("app")

-- app:start("localhost", 8080)


local socket = require "internal.socket"

function HEAD_PARSER(head)
	local HEAD = {}
	local s, e = string.find(head, '\r\n')
	local protocol = string.sub(head, 1, s)
	HEAD['method'], HEAD['PATH'], HEAD['VERSION'] = string.match(protocol, "HTTP/([%d%.]+) (%d+) (%w+)")
	string.gsub(string.sub(head, e+1, -1), "(.-): (.-)\r\n", function (key, value)
		HEAD[key] = value
	end)
	-- HEAD['head'] = nil
	return HEAD
end

function HTTP_PARSER(sock)
	local HTTP = {}
	local http = ''
	local s, e
	while 1 do	-- read header
		local data = sock:readall()
		if not data then
			return {}
		end
		http = http .. data
		local s, e = string.find(http, '\r\n\r\n')
		if s and e then
			print(s, e)
			HTTP['head'] = string.sub(http, 1, s)
			break
		end
	end

	HTTP["HEAD"] = HEAD_PARSER(HTTP['head'])
	return HTTP
end

local sock = socket:new()

local ok = sock:connect("163.177.151.109", 80)
if ok then
	local ok = sock:write("GET / HTTP/1.1\r\n\r\n")
	if not ok then
		sock:close()
		sock = nil
		return
	end
	local HTTP = HTTP_PARSER(sock)
	print(table.tostring(HTTP))
end




