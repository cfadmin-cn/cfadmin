local class = require "class"
local httpc = require "httpc"
-- require "utils"

local route = class("route")

function route:ctor(opt)
    -- var_dump(opt)
    self.args = opt.args
    self.file = opt.file
    self.path = opt.path
    self.method = opt.method
    self.header = opt.header
end

function route:route()
    if not self.args then
        return '{"code": 403, "ERROR": "找不到需要查询的用户名"}'
    end
    local code, body = httpc.get(string.format("https://api.github.com/users/%s", self.args['name'] or 'NULL'))
    if code ~= 200 then
        return '{"code": 500, "ERROR":"内部服务器错误"}'
    end
    return body
end

return route