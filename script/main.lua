-- local httpd = require "httpd"

-- local app = httpd:new("app")

-- app:start("localhost", 8080)

-- local httpc = require "httpc"

-- local code, body = httpc.get("https://api.github.com/search/users?q=candymi")
-- print(body)
-- if code ~= 200 then
-- 	local f = io.open("error.html", "w")
-- 	if f then
-- 		f:write(body)
-- 		f:close()
-- 	end
-- end

local timer = require "timer"