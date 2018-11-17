-- local httpd = require "httpd"

-- local app = httpd:new("app")

-- app:start("localhost", 8080)

local dns = require "protocol.dns"
local ok, ip = dns.resolve("www.jd.com")
if ok then
    print("ip :", ip)
end