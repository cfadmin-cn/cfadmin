local log = require "logging"
local class = require "class"
local Timer = require "internal.Timer"
local mqtt = require "protocol.mqtt"
local redis = require "protocol.redis"

local Log = log:new({ dump = true, path = 'MQ' })

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
			rds:close()
			Log:ERROR('连接mq(redis)失败:'..(err or "unknow")..'.正在尝试重连')
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
			mqtt:close()
			Log:ERROR('连接mq(mqtt)失败:'..(err or "unknow")..'.正在尝试重连')
			Timer.sleep(3)
			times = times + 1
		else
			error("未知的mq类型.")
		end
	end
end

local function redis_subscribe(self)
	local sub_mq, err = mq_login(self)
	if not sub_mq then
		return nil, err
	end
	self.sub_mq = sub_mq
	return sub_mq:subscribe(self.pattern, self.func)
end

local function mqtt_subscribe(self)
	local sub_mq, err = mq_login(self)
	if not sub_mq then
		return nil, err
	end
	self.sub_mq = sub_mq
	return sub_mq:subscribe({qos = 2, topic = self.pattern, clean = self.clean}, self.func)
end

local function redis_publish(self)
	local index = 1
	while 1 do
		if not self.pub_mq then
			local pub_mq, err = mq_login(self)
			if not pub_mq then
				return nil, err
			end
			self.pub_mq = pub_mq
		end
		while 1 do
			local msg = self.queue[index]
			if not msg then
				self.queue = {}
				return true
			end
			local ok, err = self.pub_mq:publish(msg.pattern, msg.payload)
			if not ok then
				break
			end
			index = index + 1
		end
		if self.pub_mq then
			self.pub_mq:close()
			self.pub_mq = nil
		end
	end
end

local function mqtt_publish(self)
	local index = 1
	while 1 do
		if not self.pub_mq then
			local pub_mq, err = mq_login(self)
			if not pub_mq then
				return nil, err
			end
			self.pub_mq = pub_mq
		end
		while 1 do
			local msg = self.queue[index]
			if not msg then
				self.queue = {}
				return true
			end
			local ok = self.pub_mq:publish{topic = msg.pattern, payload = msg.payload, qos = 2}
			if not ok then
				break
			end
			index = index + 1
		end
		if self.pub_mq then
			self.pub_mq:close()
			self.pub_mq = nil
		end
	end
end

-- 发布消息
function mq:emit(pattern, data)
	if type(pattern) ~= 'string' or pattern == '' then
		return nil, "publish pattern error."
	end
	if type(data) ~= 'string' or data == '' then
		return nil, "publish string error."
	end
	if not self.queue then
		self.queue = {{pattern = pattern, payload = data}}
	else
		self.queue[#self.queue + 1] = {pattern = pattern, payload = data}
	end
	if self.type == 'redis' then
		return redis_publish(self)
	elseif self.type == 'mqtt' then
		return mqtt_publish(self)
	end
	return error("mq publish error: 目前仅支持redis/mqtt协议.")
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
	if self.sub_mq then
		self.sub_mq:close()
		self.sub_mq = nil
	end
	if self.pub_mq then
		self.pub_mq:close()
		self.pub_mq = nil
	end
end

return mq
