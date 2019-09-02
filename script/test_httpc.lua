local cf = require "cf"
local httpc = require "httpc"
local http = require "httpc.class"
local json = require "json"
local system = require "system"
local now = system.now

require "utils"

-- 这里列举出了httpc库在各种情况下的使用方式.
local domain = 'http://localhost:8080'    -- domain
-- local domain = 'http://127.0.0.1:8080'    -- ipv4
-- local domain = 'http://[::1]:8080'        -- ipv6
-- local domain = 'http://[fe80::875:95ce:bcaa:f66%en0]:8080' -- internal ipv6

cf.timeout(3, function ( ... )
  cf.fork(function ( ... )
    local t1 = now()
    print("开始时间:", t1)
    -- GET请求: 在参数固定的情况下可以直接写在url内
    local code, body = httpc.get(domain.."/api?page=1&limit=10", {{"Auth", "admin"}})
    print(code, body)

    -- GET请求: 在参数为动态的情况下可以提供请求数组由httpc库进行拼接
    local code, body = httpc.get(domain.."/api", {{"Auth", "admin"}}, {{'page', 1}, {'limit', 10}})
    print(code, body)

    -- POST HEADER 为数组, BODY为数组
    local code, body = httpc.post(domain.."/api", {{"Auth", "admin"}}, {{'page', 1}, {'limit', 10}})
    print(code, body)

    -- POST HEADER 为数组, BODY为字符串
    local code, body = httpc.post(domain.."/api", {{"Auth", "admin"}}, "page=1&limit=10")
    print(code, body)

    -- http json请求示例
    local code, body = httpc.json(domain.."/api", {{"Auth", "admin"}}, json.encode({page=1, limit=10}))
    print(code, body)

    -- http 上传文件示例
    local code, body = httpc.file(domain..'/api', nil, {
        {name='1', filename='1.jpg', file='1', type='abc'},
        {name='2', filename='2.jpg', file='2', type='abc'},
        })
    print(code, body)

    local t2 = now()
    print("结束时间:", t1, "总耗时:", t2 - t1)
  end)
end)


cf.timeout(1, function ( ... )
  cf.fork(function ( ... )
    local hc = http:new {}
    local t1 = now()
    print("开始时间:", t1)
    -- GET请求: 在参数固定的情况下可以直接写在url内
    local code, body = hc:get(domain.."/api?page=1&limit=10", {{"Auth", "admin"}})
    print(code, body)

    -- GET请求: 在参数为动态的情况下可以提供请求数组由httpc库进行拼接
    local code, body = hc:get(domain.."/api", {{"Auth", "admin"}}, {{'page', 1}, {'limit', 10}})
    print(code, body)

    -- POST HEADER 为数组, BODY为数组
    local code, body = hc:post(domain.."/api", {{"Auth", "admin"}}, {{'page', 1}, {'limit', 10}})
    print(code, body)

    -- POST HEADER 为数组, BODY为字符串
    local code, body = hc:post(domain.."/api", {{"Auth", "admin"}}, "page=1&limit=10")
    print(code, body)

    -- http json请求示例
    local code, body = hc:json(domain.."/api", {{"Auth", "admin"}}, json.encode({page=1, limit=10}))
    print(code, body)

    local t2 = now()
    print("结束时间:", t1, "总耗时:", t2 - t1)
    hc:close()
  end)
end)

cf.timeout(5, function ()
  cf.fork(function ( ... )
    local hc = http:new {}
    local t1 = now()
    print("开始时间:", t1)
    local ok, response = hc:multi_request {
      {
        domain = domain.."/api",
        method = "get",
        headers = {{"Auth", "admin"}},
        args = {{'page', 1}, {'limit', 10}}
      },
      {
        domain = domain.."/api",
        method = "post",
        headers = {{"Auth", "admin"}},
        body = {{'page', 1}, {'limit', 10}}
      },
      {
        domain = domain.."/api",
        method = "json",
        headers = {{"Auth", "admin"}},
        json = json.encode({page=1, limit=10})
      },
      {
        domain = domain.."/api",
        method = "file",
        headers = {{"Auth", "admin"}},
        files = {
          {name='1', filename='1.jpg', file='1', type='abc'},
          {name='2', filename='2.jpg', file='2', type='abc'},
        }
      }
    }
    local t2 = now()
    print("结束时间:", t2, "总耗时:", t2 - t1)

    require('logging'):new({path = 'test_httpc', dump=true}):DEBUG(response, "回应数量: " .. #response)
    hc:close()
  end)
end)

-- -- 如果有需要可以开启这段注释
-- local httpd = require "httpd"
-- local app = httpd:new()
-- app:api('/api', function (content)
-- 	return "{}"
-- end)
-- app:listen("", 8080)
-- app:run()
