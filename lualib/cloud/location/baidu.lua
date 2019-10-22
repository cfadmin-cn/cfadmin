local httpc = require "httpc"
local crypt = require "crypt"
local md5 = crypt.md5
local urlencode = crypt.urlencode

local pairs = pairs
local ipairs = ipairs
local sort = table.sort
local concat = table.concat

--[[
  官网: https://lbsyun.baidu.com
  文档地址: https://lbsyun.baidu.com/index.php?title=webapi
]]

local baidu = { __Version__ = 0.1, host = "https://api.map.baidu.com" }

local function sign(query_str, ak, sk, opt)
  local keys = {}
  for key, _ in pairs(opt) do
    keys[#keys+1] = key
  end 
  sort(keys)
  local args = {}
  for index, key in ipairs(keys) do
    args[#args+1] = key .. "=" .. urlencode(opt[key])
  end
  args[#args+1] = "ak=" .. ak
  args[#args+1] = "sn=" .. md5(urlencode(query_str .. concat(args, "&") ..sk), true)
  return concat(args, "&")
end

-- 智能硬件定位
function baidu.locapi(ak, sk, opt)
  local path = "/locapi/v2?"
  return httpc.get(baidu.host .. path .. sign(path, ak, sk, opt))
end

-- 实时路况
function baidu.road(ak, sk, opt)
  local path = "/traffic/v1/road?"
  return httpc.get(baidu.host .. path .. sign(path, ak, sk, opt))
end

-- 坐标附近上车点
function baidu.parking(ak, sk, opt)
  local path = "/parking/search?"
  return httpc.get(baidu.host .. path .. sign(path, ak, sk, opt))
end

-- 坐标系转换
function baidu.convert(ak, sk, opt)
  local path = "/geoconv/v1/?"
  return httpc.get(baidu.host .. path .. sign(path, ak, sk, opt))
end

-- 位置时区
function baidu.timezone(ak, sk, opt)
  local path = "/timezone/v1?"
  return httpc.get(baidu.host .. path .. sign(path, ak, sk, opt))
end

-- 位置检索
function baidu.geosearch(ak, sk, opt)
  local path = "/place/v2/search?"
  return httpc.get(baidu.host .. path .. sign(path, ak, sk, opt))
end

-- 位置IP
function baidu.geoip(ak, sk, opt)
  local path = "/location/ip?"
  return httpc.get(baidu.host .. path .. sign(path, ak, sk, opt))
end

-- 坐标检索
function baidu.geosuggestion(ak, sk, opt)
  local path = "/place/v2/suggestion?"
  return httpc.get(baidu.host .. path .. sign(path, ak, sk, opt))
end

-- 坐标编码
function baidu.geo(ak, sk, opt)
  local path = "/geocoding/v3/?"
  return httpc.get(baidu.host .. path .. sign(path, ak, sk, opt))
end

return baidu