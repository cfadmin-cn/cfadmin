local httpd = require "httpd"
local httpc = require "httpc"
local DB = require "DB"

--[[
请按照以下步奏初始化后台:
	1. 创建一个数据库(名字任意);
	2. 请手动打开lualib/db/database.sql文件, 复制里面的SQL语句在GUI工具中执行一次;
	3. 执行完成之后, 将您填写的数据库替换database字段, 并且charset需要设置一致.
]]

local db = DB:new({
	host = '10.0.0.16',
	port = 3306,
	username = 'root',
	password = '123456789',
	charset = 'utf8',
	database = 'cfadmin',
	max = 100,
})

db:connect()

-- 导入httpd对象
local app = httpd:new("App")
-- httpd启用Cookie扩展
app:enable_cookie()
-- httpd设置Cookie加密的密匙
app:cookie_secure("https://github.com/CandyMi/core_framework")
-- app:cookie_secure("candymi")


app:ws('/ws', require "ws")

app:api('/api', function (content)
	local code, response = httpc.get("https://www.baifubao.com/callback?cmd=1059&callback=phone&phone=13000000000")
	return code == 200 and response or "httc请求失败"
end)

app:use('/view', function (content)
	return "<h1>cfadmin v0.3</h1>"
end)


-- 导入cf内置的admin库
local cfadmin = require "admin"

-- 注册后台页面路由
cfadmin.init_page(app, db)


-- 这个函数仅在第一次初始化数据的时候适用
-- 初始化完成之后, 请不要再运行.
cfadmin.init_db()

-- 这里设置首页的显示的页面
-- cfadmin.init_home(location or domain + path)
-- cfadmin.init_home('https://www.baidu.com')

local view = require "admin.view"
-- 参数:
-- 1. ctx是一个http req 对象, 目前内置包括: get_method, get_args, get_path, get_raw_path, get_headers, get_cookie
-- 2. db初始化后的db对象, 方便用户直接使用.

view.use('/admin/test1', function (ctx, db)
	return "hello world"
end)

view.api('/api/admin/test2', function (ctx, db)
	return '{"code":0,"msg":"hello world"}'
end)

-- 这里是设置语言的地方
-- 语言表在admin/locales内, 可参照key -> value进行填写.
-- 传入一个数组表: 索引1是key, 索引2为显示内容.

-- cfadmin.add_locale_item('ZH-CN', {
-- 	{'login.form.title', '这是登录页Title'},
-- 	{'dashboard.header.logo', '仪表盘 Logo'}
-- })

-- cfadmin.add_locale_item('EN-US', {
-- 	{'login.form.title', 'This is Login Page Title'},
-- 	{'dashboard.header.logo', 'dashboard Logo'}
-- })

-- 开启页面缓存能显著提升页面渲染性能. 生产环境下建议开启.
-- 也因为cf缓存模板页面内容, 所以开发模式下不建议开启.
-- cfadmin.cached()

-- 这个方法可以用来设置静态文件域名与前缀.
-- 如果静态文件在其它域名或者无法访问, 可以使用这个参数修改.(域名后必须加上'/')
-- cfadmin.static('/')

-- 设置cfadmin的区域语言, 默认为: ZH-CN
-- cfadmin.set_locale('EN-US')

-- 设置客户端静态文件ttl值内无需再次请求, 减少服务端消耗
-- app:static('static', 30)
app:static('static')

-- httpd监听端口
app:listen("0.0.0.0", 8080)

-- 运行
app:run()
