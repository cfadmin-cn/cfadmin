local class = require "class"

local ECHO = class("ECHO")


function ECHO:ctor(opt)
    self.args = opt.args
    self.file = opt.file
    self.path = opt.path
    self.method = opt.method
    self.header = opt.header
end

function ECHO:ECHO( ... )
    return '{"username":"admin", "password":"admin"}'
end

return ECHO