local log = require "log"
local class = require "class"
local Timer = require "Internal.Timer"
local mqtt = require "protocol.mqtt"
local redis = require "protocol.redis"

local type = type
local math = math
local random = math.random
local stirng = string
local fmt = string.format
local assert = assert

local mq = class("mq")

function mq:ctor(opt)
	self.id   = opt.id	 -- mqtt需要id可以指定
	self.host = opt.host -- 地址
	self.port = opt.port -- 端口
	self.type = opt.type -- 消息队列种类
	self.auth = opt.auth -- redis需要auth可以指定
	self.clean = opt.clean or true   -- mqtt 默认清除会话
	self.username = opt.username -- mqtt只支持用户名+密码认证
	self.password = opt.password -- mqtt只支持用户名+密码认证
end

local function mq_login(self)
	local times = 1
	while 1 do
		if self.type == 'redis' then
			local rds = redis:new {auth = self.auth, host = self.host, port = self.port}
			local ok, err = rds:connect()
			if ok then
				return rds
			end
			log.error('第'..times..'次连接mq(redis)失败:'..(err or "unknow"))
			if times >= 3 then
				log.error("超过最大尝试次数, 请检查mq(redis)网络或者服务是否正常.")
				return nil, "超过最大尝试次数, 请检查mq(redis)网络或者服务是否正常."
			end
			Timer.sleep(3)
			times = times + 1
		elseif self.type == 'mqtt' then
			local mqtt = mqtt:new {
				host = self.host,
				port = self.port,
				auth = {
					username = self.username,
					password = self.password
				},
				id = self.id or fmt('luamqtt-cf-v1-%X', random(1, 0xFFFFFFFF)),
			}
			local ok, err = mqtt:connect()
			if ok then
				return mqtt
			end
			log.error('第'..times..'次连接mq(mqtt)失败:'..(err or "unknow"))
			if times >= 3 then
				log.error("超过最大尝试次数, 请检查mq(mqtt)网络或者服务是否正常.")
				return nil, "超过最大尝试次数, 请检查mq(mqtt)网络或者服务是否正常."
			end
			Timer.sleep(3)
			times = times + 1
		end
	end
end

local function redis_subscribe(self)
	local mq, err = mq_login(self)
	if not mq then
		return nil, err
	end
	self.mq = mq
	return mq:psubscribe(self.pattern, self.func)
end

local function mqtt_subscribe(self)
	local mq, err = mq_login(self)
	if not mq then
		return nil, err
	end
	self.mq = mq
	return mq:subscribe({qos = 2, topic = self.pattern, clean = self.clean}, self.func)
end

-- 订阅消息
function mq:on(pattern, func)
	if type(pattern) ~= 'string' or pattern == '' then
		return nil, "subscribe pattern error."
	end
	if type(func) ~= 'function' then
		return nil, "subscribe func error."
	end
	self.func = func 	   -- 回调处理函数
	self.pattern = pattern -- 监听规则
	if self.type == 'redis' then
		return redis_subscribe(self)
	elseif self.type == 'mqtt' then
		return mqtt_subscribe(self)
	end
	return error("mq subscribe error: 目前仅支持redis/mqtt协议.")
end

-- 关闭消息队列监听
function mq:close()
	if self.mq then
		self.mq:close()
		self.mq = nil
	end
end

return mq