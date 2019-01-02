local class = require "class"
local Admin = require "Admin"
local cjson = require "cjson"

local cjson_encode = cjson.encode

local cjson_decode = cjson.decode
-- require "utils"

local demo = class("demo")


function demo:ctor(opt)
    self.args = opt.args
    self.file = opt.file
    self.path = opt.path
    self.method = opt.method
    self.header = opt.header
end

function demo:demo()
    local args = self.args
    local total = 5000000
    if args and args.limit and args.page then
        local t = {}
        for i = (tonumber(args.page) - 1) * tonumber(args.limit), tonumber(args.limit) * tonumber(args.page) - 1 do
            local data = {}
            data.id = i
            data.username = '我是'..tostring(i)
            data.sex = "男"
            if i % 2 == 0 then
                data.sex = "女"
            end
            data.city = "China"
            table.insert(t, data)
        end
        return cjson_encode({
            code = 0,
            count = total,
            data = t,
        })
    end
    return cjson_encode({
        code = 404,
        data = cjson.NULL
    })
end


return demo