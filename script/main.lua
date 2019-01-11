local httpd = require "httpd"

local app = httpd:new("App")

-- 注册接口
app:api("/httpc", require "hc")
app:api("/echo", require "echo")
app:api("/api", require "api")

-- 注册普通路由(html/text)
app:use("/view", require "view")

-- 注册websocket路由
app:ws("/ws", require "ws")

-- 注册静态文件目录
app:static('static', 10)

-- 需要记录日志, 并且指定日志存放路径
-- app:log("./http.log")

-- http监听端口
app:listen("0.0.0.0", 8080)

-- 运行
app:run()