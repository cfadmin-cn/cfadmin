local LOG = require "logging"
local dns = require "protocol.dns"
local dns_resolve = dns.resolve

local cf = require "cf"
local fork = cf.fork
local wait = cf.wait

local system = require "system"
local now = system.now
local fmt = string.format
local find = string.find
local match = string.match

local pairs = pairs

-- 去除ipv4->ipv6映射前缀
local function delete_ipv4_prefix (ip)
  if system.is_ipv4(ip) then
    return ip
  end
  return find(ip or "", '::ffff') and match(ip, "::[fF]+:([%d%.]+)") or ip
end

local domains = {
  ["百度"] = "www.baidu.com",
  ["腾讯"] = "www.qq.com",
  ["淘宝"] = "www.taobao.com",
  ["谷歌"] = "www.google.com",
  ["网易"] = "www.163.com",
  ["京东"] = "www.jd.com",
  ["唯品会"] = "www.vip.com",
  ["盛大"] = "www.sdo.com",
  ["测试"] = "pwaj.dwauidwa.raw"
}

--[[
计算方式
(min - max + 1) * 1 为单个域名查询总次数
(min - max + 1) * #domain 为所有域名查询总次数
]]
local min, max = 1, 1

--[[
测试方式: 每隔3秒后为每个域名建立1万个协程进行并发查询测试;
空间消耗: 内存消耗预计在250MB左右;
时间消耗: 每次网络查询应该在0.1/Sec左右, 每次缓存查询应该在0.001/Sec左右;
]]
cf.at(3, function (  )
  for company, domain in pairs(domains) do
    local start = now()
    local total = 0
    for i = min, max do
      fork(function (...)
        local t1 = now()
        local ok, ip = dns_resolve(domain)
        if not ok then
          LOG:WARN(fmt("测试失败: <%s>[%s]的结果:[%s]", company, domain, ip))
          return
        end
        total = total + (now() - t1)
        if i == max then
          LOG:DEBUG(fmt("测试完成 : <%s>[%s]的结果:[%s]; 平均消耗: %0.5f, 总计消耗: %0.8f", company, domain, delete_ipv4_prefix(ip), total / max, now() - start))
        end
      end)
    end
  end
  collectgarbage()
end)

wait()