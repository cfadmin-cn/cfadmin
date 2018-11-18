-- local httpd = require "httpd"

-- local app = httpd:new("app")

-- app:start("localhost", 8080)

local httpc = require "httpc"

local code, body = httpc:get("http://www.baidu.com")
print(code, body)