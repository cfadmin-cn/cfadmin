local httpd = require "httpd"

local app = httpd:new("App")

local httpc = require "httpc"

-- 注册接口
app:api("/api", require "api")

app:api("/app", function (opt)
	local code, resp = httpc.get('http://t.weather.sojson.com/api/weather/city/101030100')
	if code ~= 200 then
		print(code, resp)
		return '{"code":500,"message":"请求失败."}'
	end
	return resp
end)

-- 注册普通路由(html/text)
app:use("/view", function (opt)
    return "<html><h1 align=center>This is text/html content-type<hr></h1><body align=center>Server: cf/0.1</body></html>"
end)

-- 批量路由注册
app:group(app.API, '/admin', require "admin")

-- 批量路由注册
app:group(app.USE, '/login', require "admin")

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