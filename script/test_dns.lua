local LOG = require "logging"
local dns = require "protocol.dns"
local dns_resolve = dns.resolve

local cf = require "cf"
local fork = cf.fork

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
  return find(ip, '::ffff') and match(ip, "::[fF]+:([%d%.]+)") or ip
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
}

-- 查询次数
local min, max = 1, 10000

for company, domain in pairs(domains) do
  local t1 = now()
  for i = min, max do
    fork(function (...)
      local ok, ip = dns_resolve(domain)
      if i == max then
        local t2 = now()
        LOG:DEBUG("结束解析 : ".. company .. "[".. domain .."]" , "[".. delete_ipv4_prefix(ip) .."]", "总耗时: " .. fmt("%0.8f/Sec", t2 - t1))
      end
    end)
  end
end
