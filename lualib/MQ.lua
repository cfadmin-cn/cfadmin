local log = require "log"
local class = require "class"
local co = require "internal.Co"
local Timer = require "internal.Timer"
local mqtt = require "protocol.mqtt"
local co_spwan = co.spwan
local co_wait = co.wait

local type = type
local error = error
local ipairs = ipairs
local assert = assert
local tostring = tostring

local MQ = class("MQ")

function MQ:ctor(opt)
    assert(type(opt.host) == 'string', '创建MQ失败: 错误的host')
    assert(type(opt.port) == 'number', '创建MQ失败: 错误的port')
    assert(not opt.auth or type(opt.auth) == 'table', '创建MQ失败: 错误的auth')
    assert(not opt.qos or type(opt.qos) == 'number', '创建MQ失败: 错误的QOS值')
    self.id = opt.id
    self.host = opt.host
    self.port = opt.port
    self.auth = opt.auth
    self.ssl = opt.ssl
    self.clean = opt.clean
    self.TOPIC = {}
    self.init = true
end

-- 注册感兴趣的消息主题
function MQ:on(opt, func)
    assert(self and self.init, "调用on失败, 尚未初始化")
    for _, t in ipairs(self.TOPIC) do
        if t.topic == opt.topic then
            return nil, log.error("多次注册同样的topic是无意义的")
        end
    end
    self.TOPIC[#self.TOPIC+1] = {topic = opt.topic, queue = opt.queue, qos = opt.qos, func = func, retain = opt.retain}
end

function MQ:AliKey(accessKey, GroupID)
    local crypt = require "crypt"
    local hmac_sha1 = crypt.hmac_sha1
    local base64encode = crypt.base64encode
    return base64encode(hmac_sha1(accessKey, GroupID))
end

function MQ:publish(topic, payload)
    if not self.queue then
        self.queue = {{topic = topic, payload = payload, retain = retain}}
        co_spwan(function ( ... )
            local queue = self.queue
            local index = 1
            while 1 do
                self.client = self.client or self:create_session()
                if self.client then
                    while 1 do
                        local ok, err = self.client:publish(queue[index])
                        if not ok then
                            break
                        end
                        index = index + 1
                        if index >= #queue then
                            self.queue = nil
                            return
                        end
                    end
                    self.client:close()
                    self.client = nil
                end
                log.error('[publish]: MQTTServer断开了链接, 3秒后尝试重连..')
                Timer.sleep(3)
            end
        end)
    end
    self.queue[#self.queue+1] = {topic = topic, payload = payload, retain = retain}
end

-- 内部创建使用
function MQ:create_session()
    assert(self and self.init, "调用create_session失败")
    local mq = mqtt:new { host = self.host, port = self.port, clean = self.clean, ssl = self.ssl, auth = self.auth, id = self.id }
    local ok, err = mq:connect()
    if not ok then
        mq:close()
        return nil, log.error("连接到MQ失败, 请检查网络与端口后重启本服务."..tostring(err))
    end
    return mq
end

-- 启动事件循环
function MQ:start()
    assert(self and self.init, "调用start失败, 尚未初始化")
    for _, t in ipairs(self.TOPIC) do
        co_spwan(function ()
            local topic, func, queue, qos, retain = t.topic, t.func, t.queue, t.qos, t.retain
            if type(qos) ~= "number" then qos = 0 end
            while 1 do
                local mq = self:create_session()
                if mq then
                    mq:subscribe { topic = topic, qos = qos, payload = '', retain = retain }
                    mq:on("message", function (msg)
                        if topic == msg.topic then
                            if not queue then
                                return co_spwan(func, msg)  异步
                            end
                            return func(msg)  同步
                        end
                    end)
                    mq:message_dispatch()
                    mq:close()
                end
                log.error('[start]: MQTTServer断开了链接, 3秒后尝试重连..')
                Timer.sleep(3)
            end
        end)
    end
    return co_wait()
end

return MQ