local class = require "class"
local Admin = require "Admin"
-- require "utils"

local route = class("route")

function route:ctor(opt)
    self.args = opt.args
    self.file = opt.file
    self.path = opt.path
    self.method = opt.method
    self.header = opt.header
end

function route:route()
    return Admin.login()
end

return route