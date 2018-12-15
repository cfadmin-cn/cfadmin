local class = require "class"
-- local httpc = require "httpc"
require "utils"

local route = class("route")


function route:ctor(opt)
    var_dump(opt)
    self.args = opt.args
    self.file = opt.file
    self.path = opt.path
    self.method = opt.method
    self.header = opt.header
end

function route:route( ... )
    return '{"username":"admin", "password":"admin"}'
end

return route