local httpd = require "httpd"
local http = require "httpd.http"

local app = httpd:new("httpd")

app:before(function (content)
  return http.ok()
end)

app:api('/api/login', function (content)
  return '{"code":200, "data":{"token":"admin","uid":1}}'
end)

app:listen("0.0.0.0", 8080)

app:run()
