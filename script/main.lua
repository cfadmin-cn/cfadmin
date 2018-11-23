local httpd = require "httpd"

local app = httpd:new("app")

app:start("localhost", 8080)

-- local httpc = require "httpc"

-- local code, body = httpc:get("https://www.qq.com")
-- if code ~= 200 then
-- 	local f = io.open("error.html", "w")
-- 	if f then
-- 		f:write(body)
-- 		f:close()
-- 	end
-- end