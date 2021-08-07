-- 测试redis
local Cache = require "Cache.ssdb"
local cf = require "cf"
local Log = require("logging"):new()

local opt = {
    host = "127.0.0.1",
    -- port = 6379,
    port = 8888,
    -- auth = "rTVB9Fm2l2rctOJlIzVxIN0BreQQoiET", -- 如果需要验证
    -- db = 1, -- SSDB不支持多DB
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
    Log:DEBUG(ok, ret)

    local ok, ret = Cache:get("test")
    Log:DEBUG(ok, ret)

    local ok, ret = Cache:del("test")
    Log:DEBUG(ok, ret)

    -- 测试哈希表命令示例
    local ok, ret = Cache:hmset("website", "google", "www.google.com", "baidu", "www.baidu.com")
    Log:DEBUG(ok, ret)

    local ok, ret = Cache:hlen("website")
    Log:DEBUG(ok, ret)

    local ok, ret = Cache:hkeys("website")
    Log:DEBUG(ok, ret)

    local ok, ret = Cache:hgetall("website")
    Log:DEBUG(ok, ret)

    local ok, ret = Cache:hmget("website", "google", "baidu")
    Log:DEBUG(ok, ret)

    local ok, ret = Cache:hdel("website", "google", "baidu")
    Log:DEBUG(ok, ret)

    -- 测试列表命令示例
    local ok, ret = Cache:lpush("language", "lua", "python", "C", "C++")
    Log:DEBUG(ok, ret)

    local ok, ret = Cache:rpush("language", "golang", "java", "ruby", "javascript")
    Log:DEBUG(ok, ret)

    local ok, ret = Cache:lrange("language", 0, -1)
    Log:DEBUG(ok, ret)

    -- SSDB不支持Ltrim
    -- local ok, ret = Cache:ltrim("language" , -1, 0)
    -- Log:DEBUG(ok, ret)

    local ok, ret = Cache:llen("language")
    Log:DEBUG(ok, ret)

    -- 测试集合命令示例(SSDB 不支持集合)
    -- local ok, ret = Cache:smembers("bbs")
    -- Log:DEBUG(ok, ret)

    -- local ok, ret = Cache:sadd("bbs", "discuz.cn", "group.google.com", "oschina.net", "csdn.net")
    -- Log:DEBUG(ok, ret)

    -- local ok, ret = Cache:sismember("bbs", "oschina.net")
    -- Log:DEBUG(ok, ret)

    -- local ok, ret = Cache:srem("bbs", "discuz.cn", "group.google.com", "oschina.net", "csdn.net")
    -- Log:DEBUG(ok, ret)

    -- local ok, ret = Cache:sismember("bbs", "oschina.net")
    -- Log:DEBUG(ok, ret)

    -- local ok, ret = Cache:sadd("book1", "宝宝的C++", "宝宝的HTML", "宝宝的CSS", "C程序设计")
    -- local ok, ret = Cache:sadd("book2", "宝宝的C++", "宝宝的HTML", "宝宝的CSS", "C++从入门到放弃")
    -- local ok, ret = Cache:sadd("book3", "宝宝的C++", "宝宝的HTML", "宝宝的CSS", "MySQL从入门到删库跑路")

    -- local ok, ret = Cache:sdiff("book1", "book2", "book3")
    -- Log:DEBUG(ok, ret)

    local ok, ret = Cache:del("book1", "book2", "book3")
    Log:DEBUG(ok, ret)

    -- 测试有序集合命令示例
    local ok, ret = Cache:zadd("scores", 10, "admin", 20, "Candy", 30, "QQ", 40, "Guest")
    Log:DEBUG(ok, ret)

    local ok, ret = Cache:zrange("scores", 0, -1)
    -- local ok, ret = Cache:zrange("scores", 0, -1, "WITHSCORES")
    Log:DEBUG(ok, ret)

    local ok, ret = Cache:zcount("scores", 10, 100)
    Log:DEBUG(ok, ret)

    local ok, ret = Cache:zscore("scores", "QQ")
    Log:DEBUG(ok, ret)

    local ok, ret = Cache:zrank("scores", "Candy")
    Log:DEBUG(ok, ret)

    local ok, ret = Cache:zrem("scores", "admin", "Candy", "QQ", "Guest")
    Log:DEBUG(ok, ret)

    local ok, ret = Cache:del("scores")
    Log:DEBUG(ok, ret)

    -- 测试脚本支持 (SSDB 不支持脚本操作)
    -- local ok, ret = Cache:script_load("return 10086")
    -- Log:DEBUG(ok, ret)

    -- local sha = ret
    -- local ok, ret = Cache:script_exists(sha)
    -- Log:DEBUG(ok, ret)

    -- local ok, ret = Cache:evalsha(sha, 0)
    -- Log:DEBUG(ok, ret)

    -- local ok, ret = Cache:script_flush()
    -- Log:DEBUG(ok, ret)

    -- 其它一些特殊方法支持
    -- type, move, rename, keys, randomkey等等
		Log:DEBUG(Cache:count())

    Log:DEBUG(Cache:multi_set("a1", "1001", "a2", "1002"))

    Log:DEBUG(Cache:multi_get("a1", "a2"))

    Log:DEBUG(Cache:multi_del("a1", "a2"))

    Log:DEBUG(Cache:multi_hset("jmap", "a1", "1001", "a2", "1002"))

    Log:DEBUG(Cache:multi_hget("jmap", "a1", "a2"))

    Log:DEBUG(Cache:multi_hdel("jmap", "a1", "a2"))

    -- 管道命令支持
    local ok, ret = Cache:pipeline {
      {"HMSET", "USER_INFO", "name", "Candy", "email", '869646063@qq.com', 'phone', '13000000000'},
      {"HGET",  "USER_INFO", "email"},
      {"HGET",  "USER_INFO", "phone"},
    }
    Log:DEBUG(ok, ret)
end)
