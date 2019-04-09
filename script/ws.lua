local class = require "class"
local cf = require "cf"
local json = require "json"
local MQ = require "MQ"
local websocket = class("websocket")

function websocket:ctor(opt)
    self.ws = opt.ws             -- websocket对象
    self.send_masked = false     -- 掩码(默认为false, 不建议修改或者使用)
    self.max_payload_len = 65535 -- 最大有效载荷长度(默认为65535, 不建议修改或者使用)
    self.timeout = 15
    self.count = 0
    self.mq = MQ:new({host = 'localhost', port = 6379, type = 'redis'})
end

function websocket:on_open()
    print('on_open')
    self.timer = cf.at(0.01, function ( ... ) -- 定时器
        self.count = self.count + 1
        self.ws:send(tostring(self.count))
    end)
    self.mq:on('/test/*', function (msg) -- 消息队列
        if not msg then
            self.ws:send('{"code":500,"message":"无法连接到mq(reds)"}')
            return self.ws:close()
        end
        self.ws:send(json.encode(msg))
    end)
end

function websocket:on_message(data, typ)
    print('on_message', self.ws, data)
    self.ws:send('welcome')
    self.ws:close(data)
end

function websocket:on_error(error)
    print('on_error', self.ws, error)
end

function websocket:on_close(data)
    print('on_close', self.ws, data)
    if self.mq then     -- 清理消息队列
        self.mq:close()
        self.mq = nil
    end
    if self.timer then  -- 清理定时器
        self.timer:stop()
        self.timer = nil
    end
end

return websocket
