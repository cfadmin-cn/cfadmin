local httpc = require "httpc"
local crypt = require "crypt"
local md5 = crypt.md5
local urlencode = crypt.urlencode

local pairs = pairs
local ipairs = ipairs
local sort = table.sort
local concat = table.concat

--[[

  官网: https://lbs.amap.com

  文档: https://lbs.amap.com/api/webservice/summary
  
]]

local amap = { __Version__ = 0.1, host = "https://restapi.amap.com" }

-- sn签名
local function sign(app_key, secret_key, opt)
  local keys = {"key"}
  for key, value in pairs(opt) do
    keys[#keys+1] = key
  end
  sort(keys)
  local args = {}
  for _, key in ipairs(keys) do
    if key == "key" then
      args[#args+1] = "key=" .. app_key
    else
      args[#args+1] = key .. '=' .. urlencode(opt[key])
    end
  end
  args[#args+1] = "sig=" .. md5(concat(args, "&"), true) .. secret_key
  return concat(args, "&")
end

-- IP定位
function amap.ip(key, secret_key, ip)
  return httpc.get(amap.host .. "/v3/ip?" .. sign(key, secret_key, { ip = ip, output = "JSON"}))
end

-- 天气预报
function amap.weather(key, secret_key, city, extensions)
  return httpc.get(amap.host .. "/v3/weather/weatherInfo?" .. sign(key, secret_key, { output = "JSON", city = city, extensions = extensions}))
end

-- 坐标转换
function amap.convert(key, secret_key, locations, coordsys)
  return httpc.get(amap.host .. "/v3/assistant/coordinate/convert?" .. sign(key, secret_key, { output = "JSON", locations = locations, coordsys = coordsys }))
end

-- 地理编码
function amap.geo(key, secret_key, opt)
  return httpc.get(amap.host .. "/v3/geocode/geo?" .. sign(key, secret_key, opt))
end

-- 行政区域查询
function amap.district(key, secret_key, opt)
  return httpc.get(amap.host .. "/v3/config/district?" .. sign(key, secret_key, opt))
end

-- 输入提示
function amap.tips(key, secret_key, opt)
  return httpc.get(amap.host .. "/v3/assistant/inputtips?" .. sign(key, secret_key, opt))
end


return amap