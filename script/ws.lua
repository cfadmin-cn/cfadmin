local class = require "class"
local timer = require 'internal.Timer'
local websocket = class("websocket")

function websocket:ctor(opt)
    self.timeout = 15
end

function websocket:on_open(ws)
    print('on_open')
    self.count = 0
    self.timer = timer.at(1, function ( ... )
        -- print('定时器执行第'..tostring(self.count)..'次')
        ws.send(tostring(self.count))
        self.count = self.count + 1
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
    self.timer:stop()
end

return websocket