local log = require "log"
local class = require "class"
local co = require "internal.Co"
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
    self.host = opt.host
    self.port = opt.port
    self.auth = opt.auth
    self.TOPIC = {}
    self.init = true
end

-- 注册感兴趣的消息主题
function MQ:on(topic, func)
    assert(self and self.init, "调用on失败, 尚未初始化")
    for _, t in ipairs(self.TOPIC) do
        if t.topic == topic then
            return nil, log.error("多次注册同样的topic是无意义的")
        end
    end
    self.TOPIC[#self.TOPIC+1] = {topic = topic, func = func}
end

-- 内部使用
function MQ:create_session()
    assert(self and self.init, "调用create_session失败")
    local mq = mqtt:new {host = self.host, port = self.port, clean = true, ssl = self.ssl, auth = self.auth}
    local ok, err = mq:connect()
    if not ok then
        return error("连接到MQ失败, 请检查网络与端口后重启本服务."..tostring(err))
    end
    return mq
end

-- 启动事件循环
function MQ:start()
    assert(self and self.init, "调用start失败, 尚未初始化")
    for _, t in ipairs(self.TOPIC) do
        co_spwan(function ()
            while 1 do
                local mq = self:create_session()
                mq:subscribe { topic = t.topic }
                mq:on("message", function (msg)
                    return co_spwan(t.func, msg)
                end)
                mq:message_dispatch()
            end
        end)
    end
    return co_wait()
end

return MQ