local baidu = require "cloud.translate.baidu"
local youdao = require "cloud.translate.youdao"

--[[
  免费的有道词典接口, 采用https安全传输.
  youdao.ZH_CN2EN -- 中文 >> 英语
  youdao.ZH_CN2JA -- 中文 >> 日语
  youdao.ZH_CN2KR -- 中文 >> 韩语
  youdao.ZH_CN2FR -- 中文 >> 法语
  youdao.ZH_CN2RU -- 中文 >> 俄语
  youdao.ZH_CN2SP -- 中文 >> 西语
  youdao.EN2ZH_CN -- 英语 >> 中文
  youdao.JA2ZH_CN -- 日语 >> 中文
  youdao.KR2ZH_CN -- 韩语 >> 中文
  youdao.FR2ZH_CN -- 法语 >> 中文
  youdao.RU2ZH_CN -- 俄语 >> 中文
  youdao.SP2ZH_CN -- 西语 >> 中文
]]

local query = "床前明月光, 疑是地上霜. 举头望明月, 低头思故乡."

-- 免费
local code, ret = youdao.translate(youdao.ZH_CN2EN, query)
print(code, ret)

-- 数量收费
local app_id, app_key = "your_app_id", "your_app_key"
local code, ret = baidu.translate(app_id, app_key, {
  q = query,
  to = "en",
  from = "zh",
})
print(code, ret)