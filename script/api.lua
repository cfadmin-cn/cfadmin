local class = require "class"
local json = require "json"
local json_encode = json.encode
local json_decode = json.decode

local tonumber = tonumber
local os_time = os.time
local os_date = os.date
local insert = table.insert
local random = math.random


local API = class("API")


function API:ctor(opt)
    self.args = opt.args
    self.file = opt.file
    self.path = opt.path
    self.method = opt.method
    self.header = opt.header
end

function API:API()
    local args = self.args
    local total = 5000000
    if args and tonumber(args.limit) and tonumber(args.limit) > total / 500 then
        args.limit = 1000
    end
    if args and tonumber(args.limit) and tonumber(args.page) then
        local t = {}
        for i = (tonumber(args.page) - 1) * tonumber(args.limit), tonumber(args.limit) * tonumber(args.page) - 1 do
            local data = {}
            data.id = i
            data.username = '我是'..tostring(i)
            data.sex = "男"
            if i & 0x01 == 1 then
                data.sex = "女"
            end
            data.phone = random(13000000000, 18999999999)
            data.birthday = os_date("%Y-%m-%d", random(1, os_time()))
            data.city = "China"
            insert(t, data)
        end
        return json_encode({
            code = 0,
            count = total,
            data = t,
        })
    end
    return json_encode({
        code = 404,
        data = json.null
    })
end


return API