-- local httpd = require "httpd"

-- local app = httpd:new("app")

-- app:start("localhost", 8080)


-- local socket = require "internal.socket"

-- local match = string.match
-- local split = string.sub

local httpc = require "httpc"
local hc = httpc:new()
local data = hc:get("http://163.177.151.109/")
print(table.tostring(data))