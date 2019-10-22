local location = require "cloud.tencent.location"

--[[
  腾讯定位服务
  使用详情请参考: lualib/cloud/location/tencent.lua
]]

-- local accesskey = "Your_Access_key"
-- local secretkey = "Your_Secret_Key"

-- local code, ret = location.getIpLocation(accesskey, secretkey, '8.8.8.8')
-- print(code, ret)

-- local code, ret = location.getDistrictList(accesskey, secretkey)
-- print(code, ret)

-- local code, ret = location.getDistrictChildren(accesskey, secretkey, 110000)
-- print(code, ret)

-- local code, ret = location.searchDistrict(accesskey, secretkey, "香格里拉")
-- print(code, ret)

-- local code, ret = location.searchSuggestion(accesskey, secretkey, "盐津铺子", "广州", 1)
-- print(code, ret)

-- local code, ret = location.getDistance(accesskey, secretkey, {
--  mode = "walking", from = "39.071510,117.190091", to="39.840177,116.463318"
-- })
-- print(code, ret)

-- local code, ret = location.searchPlace(accesskey, secretkey, "长沙", "region(湖南,0)")
-- print(code, ret)


local amap = require "cloud.location.amap"

--[[
  高德定位服务
  使用详情请参考: lualib/cloud/location/amap.lua
]]

-- local accesskey = "Your_Access_key"
-- local secretkey = "Your_Secret_Key"

-- local code, ret = amap.ip(accesskey, secretkey, "114.114.114.114")
-- print(code, ret)

-- local code, ret = amap.weather(accesskey, secretkey, "110101")
-- print(code, ret)

-- local code, ret = amap.tips(accesskey, secretkey, { keywords = "三环" })
-- print(code, ret)

-- local code, ret = amap.district(accesskey, secretkey, { keywords = "天马山"})
-- print(code, ret)

-- local code, ret = amap.convert(accesskey, secretkey, "116.481499,39.990475|116.481499,39.990375", "gps")
-- print(code, ret)

local baidu = require "cloud.location.baidu"

--[[
  百度定位服务
  使用详情请参考: lualib/cloud/location/tencent.lua
]]

-- local accesskey = "Your_Access_key"
-- local secretkey = "Your_Secret_Key"

-- local code, ret = baidu.geosuggestion(accesskey, secretkey, { query = "天安门", region = "北京市", output = "json"})
-- print(code, ret)

-- local code, ret = baidu.geosearch(accesskey, secretkey, { query = "天安门", region = "北京市", output = "json"})
-- print(code, ret)

-- local code, ret = baidu.geoip(accesskey, secretkey, { ip = "114.114.114.114"})
-- print(code, ret)

-- local code, ret = baidu.timezone(accesskey, secretkey, { location = "39.934,116.387", timestamp = os.time()})
-- print(code, ret)

-- local code, ret = baidu.convert(accesskey, secretkey, { coords = "114.21892734521,29.575429778924", from = 1, to = 5})
-- print(code, ret)

-- local code, ret = baidu.parking(accesskey, secretkey, { location = "116.313064,40.048541", coordtype = "bd09ll"})
-- print(code, ret)

-- local code, ret = baidu.road(accesskey, secretkey, { road_name = "天河路", city = "广州市"})
-- print(code, ret)
