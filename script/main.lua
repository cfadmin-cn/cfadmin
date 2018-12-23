-- -- 测试cjson、https、var_dump
-- -- 需要注意cjson 默认没有编译, 需要手动进入luaclib/src/lcjson make编译一下就行了
-- require "utils"
--
-- local httpc = require "httpc"
-- local cjson = require "cjson"
--
-- -- local code, body = httpc.get("https://api.github.com/search/users?q=candymi")
-- local code, body = httpc.get("https://api.github.com/users/candymi")
--
-- if code ~= 200 then
-- 	local f = io.open("error.html", "w")
-- 	if f then
-- 		f:write(body)
-- 		f:close()
-- 	end
-- end
--
-- var_dump(cjson.decode(body))
--
-- print(pcall(cjson.c, body))


-- -- 测试魔改后的mysql
-- require "utils"
-- local mysql = require "protocol.mysql"
--
--
-- local config = {
--     host = "localhost",
--     port = 3306,
--     database = "mysql",
--     user = "root",
--     -- password = ""
-- }
-- local db, err = mysql:new()
-- if not db then
-- 	return nil
-- end
--
-- local ok, err, errno, sqlstate = db:connect(config)
--
-- if not ok then
-- 	return nil
-- end
--
-- var_dump(db:query("select * from user"))
--
-- db:close()


-- -- 测试redis
-- local redis = require "protocol.redis"
--
-- local ok, redis = redis.connect({
--     host = "localhost",
--     port = 6379,
--     auth = nil,
--     db = nil,
-- })
-- if not ok then
--     print("not connect")
--     return
-- end
--
-- -- hash表
-- print(redis:hset("table", "username", "Candy"))
--
-- -- 获取username
-- print(redis:hget("table", "username"))
--
-- -- 检查哈希表是否存在
-- print(redis:exists("table"))
--
-- -- 设置哈希表生命周期
-- print(redis:expire("table", 10086))
--
-- -- 查看生命周期
-- print(redis:ttl("table"))


local httpd = require "httpd"
local app = httpd:new("App")

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

app:listen("0.0.0.0", 8080)

app:log("./http.log")

app:run()

