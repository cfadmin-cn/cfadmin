-- local httpd = require "httpd"

-- local app = httpd:new("app")

-- app:start("localhost", 8080)

require "utils"

local httpc = require "httpc"
local cjson = require "cjson"

-- local code, body = httpc.get("https://api.github.com/search/users?q=candymi")
local code, body = httpc.get("https://api.github.com/users/candymi")

if code ~= 200 then
	local f = io.open("error.html", "w")
	if f then
		f:write(body)
		f:close()
	end
end

var_dump(cjson.decode(body))

print(pcall(cjson.c, body))
