-- 测试redis
local redis = require "protocol.redis"
require "utils"
local opt = {
    host = "localhost",
    port = 6379,
    auth = nil,
    db = nil,
}

print('开始测试redis脚本缓存/编译')
local rds = redis:new(opt)
local ok, err = rds:connect()
if not ok then
    return print('error:', err)
end

local ok, data = rds:loadscripts({"return {1}", "return {2}", "return {3}"})
if not ok then
    return print(data)
end
var_dump(data)


local ok, data = rds:evalsha('9c8545b8579e405965831fc6d1e3d0b3ac248d51', "admin")
if not ok then
    return print(data)
end
var_dump(data)

local ok, data = rds:eval("return {1}", "admin")
if not ok then
    return print(data)
end
var_dump(data)

rds:close()
print('redis脚本缓存/编译测试完成')

local times = 100
for i = 1, times do
    local rds = redis:new(opt)
    local ok, err = rds:connect()
    if not ok then
        return print('error:'..err)
    end
    -- hash表
    rds:hset("table", "username", "Candy")

    -- 获取username
    rds:hget("table", "username")

    -- 检查哈希表是否存在
    rds:exists("table")

    -- 设置哈希表生命周期
    rds:expire("table", 10086)

    -- 查看生命周期
    rds:ttl("table")

    rds:close()
end
print("测试100次redis创建->操作->关闭成功")


local pool = {}

for i = 1, times do
    local rds = redis:new(opt)
    local ok, err = rds:connect()
    if not ok then
        return print('error:'..err)
    end
    -- hash表
    rds:hset("table", "username", "Candy")

    -- 获取username
    rds:hget("table", "username")

    -- 检查哈希表是否存在
    rds:exists("table")

    -- 设置哈希表生命周期
    rds:expire("table", 10086)

    -- 查看生命周期
    rds:ttl("table")

    pool[#pool+1] = rds

end
print("创建100个redis连接池成功")

for i = 1, times do
    local rds = pool[i]
    rds:close()
    pool[i] = nil
end
print("关闭100个redis连接池成功")
