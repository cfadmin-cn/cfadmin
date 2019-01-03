local httpd = require "httpd"

local app = httpd:new("App")

-- 注册html路由r1
app:api("/httpc", require "httpc")

-- 注册API路由r2
app:api("/echo", require "echo")

-- test
app:api("/api", require "api")

-- 注册静态文件目录
app:static('static', 10)

-- 需要记录日志, 并且指定日志存放路径
app:log("./http.log")

-- http监听端口
app:listen("0.0.0.0", 8080)

-- 运行
app:run()