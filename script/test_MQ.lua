-- local MQ = require "MQ.stomp"
local MQ = require "MQ.redis"
-- local MQ = require "MQ.mqtt"

local cf = require "cf"
require "utils"

local mq = MQ:new {
	host = 'localhost',
	-- port = 61613,
	-- port = 1883,
	port = 6379,
	-- vhost = '/exchange',
	-- auth = "admin",
	-- username = "guest",
	-- password = "guest",
}

mq:on('/test', function (msg)
	print("收到来自/test的消息.")
	var_dump(msg)
end)

mq:on('/admin', function (msg)
	print("收到来自/admin的消息.")
	var_dump(msg)
end)

cf.at(0.1, function (args)
	print(mq:emit('/test', '{"code":'..math.random(1, 100)..',"from":"/test"}'))
	print(mq:emit('/admin', '{"code":'..math.random(1, 100)..',"from":"/admin"}'))
end)

mq:start()
