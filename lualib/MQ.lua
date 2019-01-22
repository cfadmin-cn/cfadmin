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


local os_time = os.time
local math_random = math.random
local math_randomseed = math.randomseed
math_randomseed(os_time())

local MQ = class("MQ")

function MQ:ctor(opt)
    self.host = opt.host
    self.port = opt.port
    self.auth = opt.auth
    self.ssl = opt.ssl
    self.keep_alive = opt.keep_alive
    self.TOPIC = {}
    self.init = true
end

-- 传入授权Key 与 GroupID后得到passwd
function MQ.AliKey(accessKey, GroupID)
    local crypt = require "crypt"
    local hmac_sha1 = crypt.hmac_sha1
    local base64encode = crypt.base64encode
    return base64encode(hmac_sha1(accessKey, GroupID))
end

-- 注册感兴趣的消息主题
function MQ:on(opt, func)
    assert(self and self.init, "调用on失败, 尚未初始化")
    for _, t in ipairs(self.TOPIC) do
        if t.topic == opt.topic or opt.id == t.id then
            return nil, log.error("多次注册同样的topic是无意义的")
        end
    end
    self.TOPIC[#self.TOPIC+1] = {id = opt.id, topic = opt.topic, queue = opt.queue, qos = opt.qos, func = func}
end

-- 内部创建使用
function MQ:create_session(opt)
    assert(self and self.init, "调用create_session失败")
    local mq = mqtt:new {host = self.host, port = self.port, ssl = self.ssl, auth = self.auth, id = opt.id, clean = opt.clean, keep_alive = self.keep_alive}
    local ok, err = mq:connect()
    if not ok then
        mq:close()
        return nil, log.error("连接到MQ失败, 请检查网络与端口后重启本服务."..tostring(err))
    end
    return mq
end

-- 启动事件循环
function MQ:start()
    assert(self and self.init, "启动失败, 尚未初始化")
    for _, t in ipairs(self.TOPIC) do
        co_spwan(function ()
            local topic, func, queue, qos, id, clean = t.topic, t.func, t.queue, t.qos, t.id, t.clean
            local mq
            if type(qos) ~= "number" and (qos < 0 or qos > 2 ) then qos = 0 end
            while 1 do
                mq = self:create_session { id = id, clean = clean }
                if mq then
                    mq:subscribe { topic = topic, qos = qos, payload = ''}
                    mq:on("message", function (msg)
                        if not queue then
                            return co_spwan(func, msg) --  异步处理消息
                        end
                        return func(msg) -- 同步处理消息
                    end)
                    mq:message_dispatch()
                    mq:close()
                    log.warn("服务端断开了连接")
                end
                Timer.sleep(1)
            end
        end)
    end
    return co_wait()
end

return MQ