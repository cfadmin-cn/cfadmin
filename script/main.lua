-- local httpd = require "httpd"

-- local app = httpd:new("app")

-- app:start("localhost", 8080)


local socket = require "internal.socket"

local sock = socket:new()

local ok = sock:connect("192.168.2.18", 8000)

sock:send("哈哈哈!")