local Co = require "internal.Co"
local timer = require "internal.Timer"
local httpc = require "httpc"
local json = require "json"

local ti = timer.timeout(2, function ( ... )
    Co.spwan(function ( ... )
        -- POST HEADER 为数组, BODY为数组
        local code, body = httpc.post("http://localhost:8080/api", {{"Auth", "admin"}}, {{'page', 1}, {'limit', 10}})
        print(code, body)

        -- POST HEADER 为数组, BODY为字符串
        local code, body = httpc.post("http://localhost:8080/api", {{"Auth", "admin"}}, "page=1&limit=10")
        print(code, body)

        -- POST HEADER 为数组, BODY为字符串
        local code, body = httpc.get("http://localhost:8080/api?page=1&limit=10", {{"Auth", "admin"}})
        print(code, body)

        -- POST HEADER 为数组, BODY为字符串
        local code, body = httpc.json("http://localhost:8080/api", {{"Auth", "admin"}}, json.encode({page=1, limit=10}))
        print(code, body)
    end)
end)