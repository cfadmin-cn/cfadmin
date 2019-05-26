-- 基于redis的订阅与发布消息队列(同步处理)
local cf = require "cf"
local MQ = require "MQ"
require "utils"

local rds = MQ:new {
	host = 'localhost',
	port = 6379,
	type = 'redis'
}

print(rds:on('/test/*', function (msg)
	var_dump(msg)
end))

cf.at(1, function ( ... )
	rds:emit("/test/admin", '{"code":100}')
end)

cf.sleep(10)
print("停止消息队列监听与投递.")
rds:close()

-- 基于mqtt的订阅与发布消息队列(同步处理)
local cf = require "cf"
local MQ = require "MQ"
require "utils"

local mqtt = MQ:new {
	host = 'localhost',
	port = 1883,
	type = 'mqtt'
}

cf.at(0.1, function ( ... )
	mqtt:emit("/test/admin", '{"code":100}')
end)

print(mqtt:on('/test/*', function (msg)
	var_dump(msg)
end))

cf.sleep(10)
print("停止消息队列监听与投递.")
mqtt:close()
