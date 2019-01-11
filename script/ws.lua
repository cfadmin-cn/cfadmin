local class = require "class"

local websocket = class("websocket")

function websocket:ctor(opt)
    
end

function websocket:on_open(ws)
    print('on_open', ws)
end

function websocket:on_message(ws, data)
    print('on_message', data)
    ws.send(data)
    ws.close(data)
end

function websocket:on_error(ws, error)
    print('on_error',ws, error)
end

function websocket:on_close(ws, data)
    print('on_close', ws, data)
end

return websocket