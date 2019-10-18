local httpc = require "httpc"
local crypt = require "crypt"
local md5 = crypt.md5

local type = type
local pairs = pairs
local time = os.time
local random = math.random
local concat = table.concat


local baidu = { __Version__ = 0.1, host = "https://fanyi-api.baidu.com/api/trans/vip/translate"}

--[[
文档地址 :http://api.fanyi.baidu.com/api/trans/product/apidoc

语言简写  名称
auto    自动检测
zh       中文
en       英语
yue      粤语
wyw     文言文
jp       日语
kor      韩语
fra      法语
spa     西班牙语
th       泰语
ara     阿拉伯语
ru       俄语
pt      葡萄牙语
de       德语
it      意大利语
el      希腊语
nl      荷兰语
pl      波兰语
bul    保加利亚语
est    爱沙尼亚语
dan     丹麦语
fin     芬兰语
cs      捷克语
rom    罗马尼亚语
slo    斯洛文尼亚语
swe     瑞典语
hu     匈牙利语
cht     繁体中文
vie     越南语
]]

-- 签名
local function sign(app_id, app_key, salt, opt)
  local sig = md5(concat({app_id, opt.q, salt, app_key}), true)
  local args = {{"appid", app_id}, {"salt", salt}, {"sign", sig}}
  for key, value in pairs(opt) do
    args[#args+1] = {key, value}
  end
  return args
end

-- 翻译接口
function baidu.translate(app_id, app_key, opt)
  assert(type(app_id) == 'string' and app_id ~= '', "invalid baidu translate app_id.")
  assert(type(app_key) == 'string' and app_key ~= '', "invalid baidu translate app_key.")
  assert(type(opt) == 'table' and type(opt.q) == 'string' and opt.q ~= '' , "invalid baidu translate opt.")
  return httpc.post(baidu.host, nil, sign(app_id, app_key, random(1, time()), {
    q = opt.q, -- 必填(其它选填)
    to = opt.to or "en",
    from = opt.from or "auto",
    tts = opt.tts and 0 or 1,
    dict = opt.dict and 0 or 1,
  }))
end

return baidu