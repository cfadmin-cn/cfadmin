local httpd = require "httpd"

local app = httpd:new("App")

local r1 = require "r1"
local r2 = require "r2"
local radmin = require "r-admin"

local demo = require "demo"

-- 注册html路由r1
app:api("/a", r1)

-- 注册API路由r2
app:api("/b", r2)

-- 注册API路由admin
app:use("/", radmin)

-- test
app:api("/demo", demo)

-- 注册静态文件目录
app:static('static', 10)

-- 需要记录日志, 并且指定日志存放路径
app:log("./http.log")

-- http监听端口
app:listen("0.0.0.0", 8080)

-- 运行
app:run()