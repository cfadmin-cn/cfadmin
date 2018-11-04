-- local httpd = require "httpd"

-- local app = httpd:new("app")

-- app:start("localhost", 8080)


local socket = require "internal.socket"

local sock = socket:new()

local ok = sock:connect("163.177.151.110", 80)

if ok then
	local ok = sock:send("GET / HTTP/1.1\r\n\r\n")
	if not ok then
		sock:close()
		sock = nil
		return
	end
	local data = ''
	while 1 do
		local str, len = sock:recv(1024)
		print(len)
		if len < 1024 then
			sock:close()
			break
		end
		data = string.format('%s%s', data, str)
	end
end