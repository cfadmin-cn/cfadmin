-- 测试redis
local Cache = require "Cache"
local Co = require "internal.Co"
local timer = require "internal.Timer"
require "utils"
local opt = {
    host = "localhost",
    port = 6379,
    auth = nil,
    db = nil,
    max = 5,
}

-- 测试海量协程竞争opt.max个协程
local ok, err = Cache.init(opt)
if not ok then
    return print(err)
end

for i = 1, 10000 do 
    Co.spwan( function ( ... )
        local ok, ret = Cache:hget('user', 'candy')
        print(ok, i, ret)
    end)
end

local t = timer.at(1, function ( ... )
    print('当前Cache连接数为:', Cache.count())
    print('当前协程数连接数为:', Co.count())
end)

Co.wait()