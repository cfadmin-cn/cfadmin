
local dns = require "protocol.dns"
local dns_resolve = dns.resolve

local cf = require "cf"

local system = require "system"
local now = system.now
local fmt = string.format

-- 百度
for i = 1, 10 do
  cf.fork(function ( ... )
    local t1 = now()
    local domain = 'www.baidu.com'
		if i == 1 then
    	print("开始解析 :", domain, "时间:", fmt("%0.8f/Sec", t1))
		end
    local ok, ip = dns_resolve(domain)
    local t2 = now()
		if i == 10 then
    	print("结束解析 :", domain, "时间:", fmt("%0.8f/Sec", t2), "耗时:", fmt("%0.8f/Sec", t2 - t1))
		end
  end)
end

-- 腾讯
for i = 1, 10 do
  cf.fork(function ( ... )
    local t1 = now()
    local domain = 'www.qq.com'
		if i == 1 then
    	print("开始解析 :", domain, "时间:", fmt("%0.8f/Sec", t1))
		end
    local ok, ip = dns_resolve(domain)
    local t2 = now()
		if i == 10 then
    	print("结束解析 :", domain, "时间:", fmt("%0.8f/Sec", t2), "耗时:", fmt("%0.8f/Sec", t2 - t1))
		end
  end)
end

-- 淘宝
for i = 1, 10 do
  cf.fork(function ( ... )
    local t1 = now()
    local domain = 'www.taobao.com'
		if i == 1 then
    	print("开始解析 :", domain, "时间:", fmt("%0.8f/Sec", t1))
		end
    local ok, ip = dns_resolve(domain)
    local t2 = now()
		if i == 10 then
    	print("结束解析 :", domain, "时间:", fmt("%0.8f/Sec", t2), "耗时:", fmt("%0.8f/Sec", t2 - t1))
		end
  end)
end

-- 谷歌
for i = 1, 10 do
  cf.fork(function ( ... )
    local t1 = now()
    local domain = 'www.google.com'
		if i == 1 then
    	print("开始解析 :", domain, "时间:", fmt("%0.8f/Sec", t1))
		end
    local ok, ip = dns_resolve(domain)
    local t2 = now()
		if i == 10 then
    	print("结束解析 :", domain, "时间:", fmt("%0.8f/Sec", t2), "耗时:", fmt("%0.8f/Sec", t2 - t1))
		end
  end)
end

-- 网易
for i = 1, 10 do
  cf.fork(function ( ... )
    local t1 = now()
    local domain = 'www.163.com'
		if i == 1 then
    	print("开始解析 :", domain, "时间:", fmt("%0.8f/Sec", t1))
		end
    local ok, ip = dns_resolve(domain)
    local t2 = now()
		if i == 10 then
    	print("结束解析 :", domain, "时间:", fmt("%0.8f/Sec", t2), "耗时:", fmt("%0.8f/Sec", t2 - t1))
		end
  end)
end

-- 京东
for i = 1, 10 do
  cf.fork(function ( ... )
    local t1 = now()
    local domain = 'www.jd.com'
		if i == 1 then
    	print("开始解析 :", domain, "时间:", fmt("%0.8f/Sec", t1))
		end
    local ok, ip = dns_resolve(domain)
    local t2 = now()
		if i == 10 then
    	print("结束解析 :", domain, "时间:", fmt("%0.8f/Sec", t2), "耗时:", fmt("%0.8f/Sec", t2 - t1))
		end
  end)
end

-- 唯品会
for i = 1, 10 do
  cf.fork(function ( ... )
    local t1 = now()
    local domain = 'www.vip.com'
		if i == 1 then
    	print("开始解析 :", domain, "时间:", fmt("%0.8f/Sec", t1))
		end
    local ok, ip = dns_resolve(domain)
    local t2 = now()
		if i == 10 then
    	print("结束解析 :", domain, "时间:", fmt("%0.8f/Sec", t2), "耗时:", fmt("%0.8f/Sec", t2 - t1))
		end
  end)
end

-- 盛大
for i = 1, 10 do
  cf.fork(function ( ... )
    local t1 = now()
    local domain = 'www.sdo.com'
		if i == 1 then
    	print("开始解析 :", domain, "时间:", fmt("%0.8f/Sec", t1))
		end
    local ok, ip = dns_resolve(domain)
    local t2 = now()
		if i == 10 then
    	print("结束解析 :", domain, "时间:", fmt("%0.8f/Sec", t2), "耗时:", fmt("%0.8f/Sec", t2 - t1))
		end
  end)
end
