local class = require "class"


local API = class("API")

function API:ctor(opt)
    self.args = opt.args
    self.method = opt.method
    self.header = opt.header
    self.file = opt.file
end

function API:get()
    return '{"code":200,"message":"This is GET method request"}'
end

function API:post()
    return '{"code":200,"message":"This is POST method request"}'
end

return API