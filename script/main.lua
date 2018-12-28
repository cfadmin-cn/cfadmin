local httpd = require "httpd"
local DB = require "DB"

local app = httpd:new("App")

local ok = DB.init("mysql://localhost:3306/mysql", "root", "zhugeng")
if not ok then
    return print("连接mysql 失败")
end

-- 一个简单的DB使用查询示例
local ret, err = DB.select(
    {'host', 'user'}, -- fields
    'user',           -- table
    {
        {"user", "=","root"},
    },      -- conditions
    nil,    -- orderby
    "DESC", -- sort
    {10},   -- limit
)
if not ret then
    return print(err)
end


local r1 = require "r1"
local r2 = require "r2"
local radmin = require "r-admin"

-- 注册html路由r1
app:api("/a", r1)

-- 注册API路由r2
app:api("/b", r2)

-- -- 注册API路由admin
app:use("/", radmin)

-- 注册静态文件目录
app:static('static', 10)

-- 需要记录日志, 并且指定日志存放路径
app:log("./http.log")

-- http监听端口
app:listen("0.0.0.0", 8080)

-- 运行
app:run()