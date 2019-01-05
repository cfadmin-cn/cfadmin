local class = require "class"
local httpc = require "httpc"

local HTTPC = class("HTTPC")

function HTTPC:ctor(opt)
    self.args = opt.args
    self.file = opt.file
    self.path = opt.path
    self.method = opt.method
    self.header = opt.header
end

function HTTPC:HTTPC(...)
    if not self.args then
        return '{"code": 403, "ERROR": "找不到需要查询的用户名"}'
    end
    local code, body = httpc.get(string.format("https://api.github.com/users/%s", self.args['name'] or 'CandyMI'))
    if code ~= 200 then
        print(code, type(code), body)
        return '{"code": 500, "ERROR":"内部服务器错误"}'
    end
    return body
end

return HTTPC