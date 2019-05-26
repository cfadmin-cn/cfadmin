local dns = require "protocol.dns"
local cf = require "cf"
cf.fork(function ( ... )
    print("申请解析 1")
    local ok, ip = dns.resolve('www.baidu.com')
    print("解析完成 1", ok, ip)
end)

cf.fork(function ( ... )
    print("申请解析 2")
    local ok, ip = dns.resolve('www.baidu.com')
    print("解析完成 2", ok, ip)
end)

cf.fork(function ( ... )
    print("申请解析 3")
    local ok, ip = dns.resolve('www.baidu.com')
    print("解析完成 3", ok, ip)
end)

cf.fork(function ( ... )
    print("申请解析 11")
    local ok, ip = dns.resolve('www.qq.com')
    print("解析完成 11", ok, ip)
end)

cf.fork(function ( ... )
    print("申请解析 12")
    local ok, ip = dns.resolve('www.qq.com')
    print("解析完成 12", ok, ip)
end)

cf.fork(function ( ... )
    print("申请解析 13")
    local ok, ip = dns.resolve('www.qq.com')
    print("解析完成 13", ok, ip)
end)
