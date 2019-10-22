local httpc = require "httpc"
local crypt = require "crypt"

local type = type
local pairs = pairs
local ipairs = ipairs
local assert = assert

--[[
  文档地址: https://lbs.qq.com/webservice_v1/index.html
  目前所有API接口仅支持SN码签名校验, 请自行在腾讯位置服务端`后台管理`->`key管理`中进行设置获取key并且生成sn码.
  所有接口数据均返回原生http code与json数据, 请开发者自行进行接口判断与json decode.
]]

local function sign(sn, path, opt)
  local key_sorts = {}
  for key, value in pairs(opt) do
    key_sorts[#key_sorts+1] = key
  end
  table.sort(key_sorts)
  local args = {}
  local signs = {}
  for index, key in ipairs(key_sorts) do
    signs[#signs+1] = key .. '=' .. opt[key]
    args[#args+1] = {key, opt[key]}
  end
  local sig = crypt.md5(path .. '?' .. table.concat(signs, "&") .. sn, true)
  args[#args+1] = {"sig", sig}
  return args
end

local tencent = { __Version__ = 0.1 }

-- IP定位
--[[
  ip : IP地址
]]
function tencent.getIpLocation (accesskey, sn, ip)
  return httpc.get("https://apis.map.qq.com/ws/location/v1/ip", nil, sign(sn, "/ws/location/v1/ip", {
    ip = ip, key = accesskey
  }))
end

-- 获取行政规划区列表
function tencent.getDistrictList (accesskey, sn)
  return httpc.get("https://apis.map.qq.com/ws/district/v1/list", nil, sign(sn, "/ws/district/v1/list", {key = accesskey}))
end

-- 获取指定行政规划区
--[[
  id: 父级行政区划ID，缺省时则返回最顶级行政区划
]]
function tencent.getDistrictChildren (accesskey, sn, id)
  return httpc.get("https://apis.map.qq.com/ws/district/v1/getchildren", nil, sign(sn, "/ws/district/v1/getchildren", {
    id = id, key = accesskey
  }))
end

-- 关键词猜测(补全)
--[[
  keyword: 搜索/联想/补全关键词
  region: 范围, 如: 广州
  region_fix : 是否固定范围.
  location: 不支持
  page_index: 当前是第几页
  page_size: 每页返回数量
]]
function tencent.searchSuggestion (accesskey, sn, keyword, region, region_fix, page_index, page_size)
  return httpc.get("https://apis.map.qq.com/ws/place/v1/suggestion", nil, sign(sn, "/ws/place/v1/suggestion", {
    key = accesskey, keyword = keyword,
    page_index = page_index or 1,
    page_size = page_size or 10,
    region = region or '',
    region_fix = region_fix or 1,
  }))
end

function tencent.searchPlace (accesskey, sn, keyword, boundary, page_index, page_size, order)
  return httpc.get("https://apis.map.qq.com/ws/place/v1/search", nil, sign(sn, "/ws/place/v1/search", {
    key = accesskey,
    keyword = keyword,
    boundary = boundary,
    page_index = page_index,
    page_size = page_size,
    order = order,
  }))
end

-- 关键词搜索行政规划区
--[[
  keyword: 行政区关键词
]]
function tencent.searchDistrict (accesskey, sn, keyword)
  return httpc.get("https://apis.map.qq.com/ws/district/v1/search", nil, sign(sn, "/ws/district/v1/search", {
    key = accesskey, keyword = keyword
  }))
end

-- 距离计算(一对多)
--[[
  mode: driving 驾车, wakling 步行
  from: 起始经纬度
  to: 目的经纬度
]]
function tencent.getDistance (accesskey, sn, opt)
  return httpc.get("https://apis.map.qq.com/ws/distance/v1/", nil, sign(sn, "/ws/distance/v1/", {
    key = accesskey, to = opt.to, from = opt.from, mode = opt.mode,
  }))
end

return tencent
