-- 测试redis
local Cache = require "Cache"
local cf = require "cf"
require "utils"

local opt = {
    host = "localhost",
    port = 6379,
    auth = nil,
    db = 1,
    max = 1,
}

cf.fork(function ( ... )
    local Cache = Cache:new(opt)
		local ok, err = Cache:connect()
    if not ok then
        return print(err)
    end
    -- 测试 GET/SET/DEL 命令示例
    local ok, ret = Cache:set("test", 1)
    print(ok); var_dump(ret)

    local ok, ret = Cache:get("test")
    print(ok); var_dump(ret)

    local ok, ret = Cache:del("test")
    print(ok); var_dump(ret)

    -- 测试哈希表命令示例
    local ok, ret = Cache:hmset("website", "google", "www.google.com", "baidu", "www.baidu.com")
    print(ok); var_dump(ret)

    local ok, ret = Cache:hlen("website")
    print(ok); var_dump(ret)

    local ok, ret = Cache:hkeys("website")
    print(ok); var_dump(ret)

    local ok, ret = Cache:hgetall("website")
    print(ok); var_dump(ret)

    local ok, ret = Cache:hmget("website", "google", "baidu")
    print(ok); var_dump(ret)

    local ok, ret = Cache:hdel("website", "google", "baidu")
    print(ok); var_dump(ret)

    -- 测试列表命令示例
    local ok, ret = Cache:lpush("language", "lua", "python", "C", "C++")
    print(ok); var_dump(ret)

    local ok, ret = Cache:rpush("language", "golang", "java", "ruby", "javascript")
    print(ok); var_dump(ret)

    local ok, ret = Cache:lrange("language", 0, -1)
    print(ok); var_dump(ret)

    local ok, ret = Cache:ltrim("language" , -1, 0)
    print(ok); var_dump(ret)

    local ok, ret = Cache:llen("language")
    print(ok); var_dump(ret)

    -- 测试有序集合命令示例
    local ok, ret = Cache:smembers("bbs")
    print(ok); var_dump(ret)

    local ok, ret = Cache:sadd("bbs", "discuz.cn", "group.google.com", "oschina.net", "csdn.net")
    print(ok); var_dump(ret)

    local ok, ret = Cache:sismember("bbs", "oschina.net")
    print(ok); var_dump(ret)

    local ok, ret = Cache:srem("bbs", "discuz.cn", "group.google.com", "oschina.net", "csdn.net")
    print(ok); var_dump(ret)

    local ok, ret = Cache:sismember("bbs", "oschina.net")
    print(ok); var_dump(ret)

    local ok, ret = Cache:sadd("book1", "宝宝的C++", "宝宝的HTML", "宝宝的CSS", "C程序设计")
    local ok, ret = Cache:sadd("book2", "宝宝的C++", "宝宝的HTML", "宝宝的CSS", "C++从入门到放弃")
    local ok, ret = Cache:sadd("book3", "宝宝的C++", "宝宝的HTML", "宝宝的CSS", "MySQL从入门到删库跑路")

    local ok, ret = Cache:sdiff("book1", "book2", "book3")
    print(ok); var_dump(ret)

    local ok, ret = Cache:del("book1", "book2", "book3")
    print(ok); var_dump(ret)

    -- 测试有序集合命令示例
    local ok, ret = Cache:zadd("scores", 10, "admin", 20, "Candy", 30, "QQ", 40, "Guest")
    print(ok); var_dump(ret)

    local ok, ret = Cache:zrange("scores", 0, -1)
    -- local ok, ret = Cache:zrange("scores", 0, -1, "WITHSCORES")
    print(ok); var_dump(ret)

    local ok, ret = Cache:zcount("scores", 10, 100)
    print(ok); var_dump(ret)

    local ok, ret = Cache:zscore("scores", "QQ")
    print(ok); var_dump(ret)

    local ok, ret = Cache:zrank("scores", "Candy")
    print(ok); var_dump(ret)

    local ok, ret = Cache:zrem("scores", "admin", "Candy", "QQ", "Guest")
    print(ok); var_dump(ret)

    local ok, ret = Cache:del("scores")
    print(ok); var_dump(ret)

    -- 脚本支持
    local ok, ret = Cache:script_load("return 10086")
    print(ok); var_dump(ret)

    local sha = ret
    local ok, ret = Cache:script_exists(sha)
    print(ok); var_dump(ret)

    local ok, ret = Cache:evalsha(sha, 0)
    print(ok); var_dump(ret)

    local ok, ret = Cache:script_flush()
    print(ok); var_dump(ret)

    -- 其它一些特殊方法支持
    -- type, move, rename, keys, randomkey等等
		print(Cache:count())

    -- 管道命令支持
    local ok, ret = Cache:pipeline {
      {"HMSET", "USER_INFO", "name", "Candy", "email", '869646063@qq.com', 'phone', '13000000000'},
      {"HGET",  "USER_INFO", "email"},
      {"HGET",  "USER_INFO", "phone"},
    }
    print(ok); var_dump(ret)
end)
