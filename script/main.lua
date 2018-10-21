local httpd = require "httpd"

local app = httpd:new("app")

app:start("localhost", 8080)