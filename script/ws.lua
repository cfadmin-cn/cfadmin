local class = require "class"

local ws = class("ws")

function ws:ctor(opt)
    
end

function ws:on_open(...)
    print('on_open', ...)
end

function ws:on_message(...)
    print('on_message', ...)
end

function ws:on_error(...)
    print('on_error', ...)
end

function ws:on_close(...)
    print('on_close', ...)
end

return ws