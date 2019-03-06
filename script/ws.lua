local class = require "class"
local timer = require 'internal.Timer'
local json = require "json"
local MQ = require "MQ"
local websocket = class("websocket")

function websocket:ctor(opt)
    self.timeout = 15
    self.count = 0
    self.mq = MQ:new({host = 'localhost', port = 6379, type = 'redis'})
end

function websocket:on_open(ws)
    print('on_open')
    self.timer = timer.at(1, function ( ... ) -- 定时器
        self.count = self.count + 1
        ws.send(tostring(self.count))
    end)
    self.mq:on('/test/*', function (msg) -- 消息队列
        ws.send(json.encode(msg))
    end)
end

function websocket:on_message(ws, data)
    print('on_message', ws, data)
    ws.send('welcome')
    -- ws.close(data)
end

function websocket:on_error(ws, error)
    print('on_error',ws, error)
end

function websocket:on_close(ws, data)
    print('on_close', ws, data)
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