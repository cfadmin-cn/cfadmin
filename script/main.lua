local httpd = require "httpd"
local http = require "httpd.http"
local httpc = require "httpc"


local app = httpd:new("App")


-- 每次http请求在处理函数之前将调用此方法, 第三方中间件可以在此针对回调函数设计.
-- 需要注意的是: 如果路由不存在, 则不会经过此回调!
-- 以下为使用示例:
-- 如果未使用before回调进行中间件设计或进行header验证, 请不要注册before回调
-- 只要注册了before回调, 即使不做任何操作(返回非法值(nil))也会返回http 401 code.
app:before(function (content)
	if true then
		return http.ok()
	end
	-- if true then
	-- 	return http.redirect('https://github.com/CandyMi/core_framework')
	-- end
	-- if true then
	-- 	return http.throw(431, '<h1> This is 413 Error, too long request header</h1>')
	-- end
end)

-- 单个连接最大保持时间
app:timeout(5)

-- 最大URI长度
app:max_path_size(1024)

-- 最大Header长度
app:max_header_size(65535)

-- 最大Body长度
app:max_body_size(1024 * 1024)

-- 可自定义Server Name
app:server_name('Candy Server/1.0')

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