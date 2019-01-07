local class = require "class"
local template = require "template"
-- require "utils"

local VIEW = class("VIEW")


function VIEW:ctor(opt)
    self.args = opt.args
    self.file = opt.file
    self.path = opt.path
    self.method = opt.method
    self.header = opt.header
    -- var_dump(opt)
end

function VIEW:VIEW(...)
    return string.format("<html><h1>%s</h1></html>", "hello world!")
end

return VIEW