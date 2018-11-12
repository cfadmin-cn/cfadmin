-- local httpd = require "httpd"

-- local app = httpd:new("app")

-- app:start("localhost", 8080)



local httpc = require "httpc"
local to_string = require "utils"

local hc = httpc:new()

-- local data, err = hc:get("http://34.226.187.139/")

-- www.qq.com
local data, msg = hc:get("http://58.250.137.36/")
print(data)
print(msg)