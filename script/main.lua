local httpd = require "httpd"

local app = httpd:new("App")

-- 注册接口
app:api("/api", require "api")

app:api("/app", function (opt)
    return "<html><h1 align=center>this is test header<hr>cf/0.1</h1></html>"
end)

-- 注册普通路由(html/text)
app:use("/view", function (opt)
    return "<html><h1 align=center>This is text/html content-type<hr></h1><body align=center>Server: cf/0.1</body></html>"
end)

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