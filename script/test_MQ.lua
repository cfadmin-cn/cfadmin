local MQ = require "MQ"
local Timer = require "internal.Timer"
-- require "utils"

local mq = MQ:new {host = 'localhost', port = 8883, ssl = true, auth = {username = "車先生的账号", password = "車先生的密码"}}
-- local mq = MQ:new {host = 'localhost', port = 1883, ssl = false, auth = {username = "車先生的账号", password = "車先生的密码"}}
if not mq then
    return print(err)
end

mq:on({id = math.random(1, 0xFFFFFFFF), topic = "LUAMQTT/login", queue = false, qos = 1, clean = true}, function (msg)
    print("recv from [LUAMQTT/login] msg:", msg)
end)

-- var_dump(mq)
mq:start()