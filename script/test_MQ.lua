local MQ = require "MQ"
local Timer = require "internal.Timer"
-- require "utils"

local mq = MQ:new {host = '10.0.0.15', port = 8883, ssl = true, auth = {username = "車先生的账号", password = "車先生的密码"}}
-- local mq = MQ:new {host = 'localhost', port = 1883, ssl = false, auth = {username = "車先生的账号", password = "車先生的密码"}}
if not mq then
    return print(err)
end

local rr = 1
local topics = {
    'luamqtt/login',
    'luamqtt/user',
    'luamqtt/log',
}

local timer = Timer.at(0.01, function ( ... )
    mq:publish(topics[rr], '{"code":200,"data":null}', false)
    rr = rr % #topics + 1
end)

mq:on("luamqtt/login", function (msg)
    print("recv from [luamqtt/login] msg:", msg)
end)

mq:on("luamqtt/user", function (msg)
    print("recv from [luamqtt/user] msg:", msg)
end)

mq:on("luamqtt/log", function (msg)
    print("recv from [luamqtt/log] msg:", msg)
end)

-- var_dump(mq)
mq:start()