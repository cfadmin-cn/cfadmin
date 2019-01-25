local class = require "class"


local API = class("API")

function API:ctor(opt)
    self.args = opt.args
    self.method = opt.method
    self.headers = opt.headers
    self.files = opt.files
    self.body = opt.body
end

function API:get()
    return '{"code":200,"message":"This is GET method request"}'
end

function API:post()
    return '{"code":200,"message":"This is POST method request"}'
end

return API