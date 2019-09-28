local httpc = require "httpc"
local crypt = require "crypt"

local type = type
local assert = assert

--[[
  文档地址: https://lbs.qq.com/webservice_v1/index.html
  目前所有API接口仅支持SN码签名校验, 请自行在腾讯位置服务端`后台管理`->`key管理`中进行设置获取key并且生成sn码.
  所有接口数据均返回原生http code与json数据, 请开发者自行进行接口判断与json decode.
]]

local Location = { __Version__ = 0.1 }

-- IP定位
--[[
  ip : IP地址
]]
function Location.getIpLocation (accesskey, sn, ip)
  return httpc.get("https://apis.map.qq.com/ws/location/v1/ip", nil, {
    {"ip", ip},
    {"key", accesskey},
    {"sig", crypt.md5("/ws/location/v1/ip?"
      .. "ip=" .. ip .. "&" .. "key=" .. accesskey
      .. sn , true)
    }
  })
end

-- 获取行政规划区列表
function Location.getDistrictList (accesskey, sn)
  return httpc.get("https://apis.map.qq.com/ws/district/v1/list", nil, {
    {"key", accesskey},
    {"sig", crypt.md5("/ws/district/v1/list?"
      .. "key=" .. accesskey
      .. sn , true)
    }
  })
end

-- 获取指定行政规划区
--[[
  id: 父级行政区划ID，缺省时则返回最顶级行政区划
]]
function Location.getDistrictChildren (accesskey, sn, id)
  return httpc.get("https://apis.map.qq.com/ws/district/v1/getchildren", nil, {
    {"key", accesskey},
    {"id", id},
    {"sig", crypt.md5("/ws/district/v1/getchildren?"
      .. "id=" .. id .. "&" .. "key=" .. accesskey
      .. sn , true)
    }
  })
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
function Location.searchSuggestion (accesskey, sn, keyword, region, region_fix, page_index, page_size)
  return httpc.get("https://apis.map.qq.com/ws/place/v1/suggestion", nil, {
    {"key", accesskey},
    {"keyword", keyword},
    {"page_index", page_index or 1},
    {"page_size", page_size or 10},
    {"region", region or '' },
    {"region_fix", region_fix or 1},
    {"sig", crypt.md5("/ws/place/v1/suggestion?"
      .. "key=" .. accesskey .. "&" .. "keyword=" .. keyword .. "&"
      .. "page_index=" .. (page_index or 1) .. "&" .. "page_size=" .. (page_size or 10) .. "&"
      .. "region=" .. (region or '') .. "&" .. "region_fix=" .. (region_fix or 1)
      .. sn , true)
    }
  })
end

function Location.searchPlace (accesskey, sn, keyword, boundary)
  return httpc.get("https://apis.map.qq.com/ws/place/v1/search", nil, {
    {"boundary", boundary},
    {"key", accesskey},
    {"keyword", keyword},
    {"page_index", page_index or 1},
    {"page_size", page_size or 10},
    {"sig", crypt.md5("/ws/place/v1/search?"
      .. "boundary=" .. boundary .. "&" .. "key=" .. accesskey .. "&" .. "keyword=" .. keyword .. "&"
      .. "page_index=" .. (page_index or 1) .. "&" .. "page_size=" .. (page_size or 10) .. "&"
      .. sn , true)
    }
  })
end

-- 关键词搜索行政规划区
--[[
  keyword: 行政区关键词
]]
function Location.searchDistrict (accesskey, sn, keyword)
  return httpc.get("https://apis.map.qq.com/ws/district/v1/search", nil, {
    {"key", accesskey},
    {"keyword", keyword},
    {"sig", crypt.md5("/ws/district/v1/search?"
      .. "key=" .. accesskey .. "&" .. "keyword=" .. keyword
      .. sn , true)
    }
  })
end

-- 距离计算(一对多)
--[[
  mode: driving 驾车, wakling 步行
  from: 起始经纬度
  to: 目的经纬度
]]
function Location.getDistance (accesskey, sn, opt)
  assert(type(opt) == 'table', "invaild arguments")
  assert(opt.from, "invaild current position.")
  assert(opt.to, "invaild Destination position.")
  assert(opt.mode == 'driving' or opt.mode == 'walking', "invaild mode. [driving | walking]")
  return httpc.get("https://apis.map.qq.com/ws/distance/v1/", nil, {
    {"from", opt.from},
    {"mode", opt.mode},
    {"key", accesskey},
    {"to", opt.to},
    {"sig", crypt.md5("/ws/distance/v1/?"
      .. "from=" .. opt.from .. "&" .. "key=" .. accesskey .. "&" .. "mode=" .. opt.mode .. "&" .. "to=" .. opt.to
      .. sn , true)
    }
  })
end

return Location
