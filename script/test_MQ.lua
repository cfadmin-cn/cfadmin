local MQ = require "MQ"

local mq, err = MQ:new {host = 'localhost', port = 1883, ssl = false, auth = {username = "車先生的账号", password = "車先生的密码"}}
if not mq then
    return print(err)
end

mq:on("luamqtt/login", function (msg)
    print("recv from [luamqtt/login] msg:", msg)
end)

mq:on("luamqtt/user", function (msg)
    print("recv from [luamqtt/user] msg:", msg)
end)

mq:on("luamqtt/log", function (msg)
    print("recv from [luamqtt/login] msg:", msg)
end)

mq:start()