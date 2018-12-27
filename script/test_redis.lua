-- 测试redis
local redis = require "protocol.redis"

local config = {
    host = "localhost",
    port = 6379,
    auth = nil,
    db = nil,
}

local pool = {}
local times = 100

for i = 1, times do
	local ok, redis = redis.connect(config)
	if not ok then
	    return print("连接redis失败")
	end
	-- hash表
	print(redis:hset("table", "username", "Candy"))

	-- 获取username
	print(redis:hget("table", "username"))

	-- 检查哈希表是否存在
	print(redis:exists("table"))

	-- 设置哈希表生命周期
	print(redis:expire("table", 10086))

	-- 查看生命周期
	print(redis:ttl("table"))

	redis:close()
end
print("测试100次redis创建->操作->关闭成功")



for i = 1, times do
	local ok, redis = redis.connect(config)
	if not ok then
	    return print("连接redis失败")
	end
	pool[#pool+1] = redis 
	-- hash表
	print(redis:hset("table", "username", "Candy"))

	-- 获取username
	print(redis:hget("table", "username"))

	-- 检查哈希表是否存在
	print(redis:exists("table"))

	-- 设置哈希表生命周期
	print(redis:expire("table", 10086))

	-- 查看生命周期
	print(redis:ttl("table"))
end
print("创建100个redis连接池成功")

for i = 1, times do
	local redis = pool[i]
	redis:close()
	pool[i] = nil
end
print("关闭100个redis连接池成功")
