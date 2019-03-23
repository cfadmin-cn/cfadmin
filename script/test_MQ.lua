-- 基于redis的订阅与发布消息队列(同步处理)
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

-- 基于mqtt的订阅与发布消息队列(同步处理)
local MQ = require "MQ"
require "utils"

local mqtt = MQ:new {
	host = 'localhost',
	port = 1883,
	type = 'mqtt'
}

print(mqtt:on('/test/*', function (msg)
	var_dump(msg)
end))
