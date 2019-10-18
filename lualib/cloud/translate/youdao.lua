local httpc = require "httpc"

local type = type

--[[
  免费的有道词典接口, 采用https安全传输.
]]

local youdao = { __Version__ = 0.1, host = "https://fanyi.youdao.com/translate"}

-- 中文 >> 英语
youdao.ZH_CN2EN = "ZH_CN2EN"
-- 中文 >> 日语
youdao.ZH_CN2JA = "ZH_CN2JA"
-- 中文 >> 韩语
youdao.ZH_CN2KR = "ZH_CN2KR"
-- 中文 >> 法语
youdao.ZH_CN2FR = "ZH_CN2FR"
-- 中文 >> 俄语
youdao.ZH_CN2RU = "ZH_CN2RU"
-- 中文 >> 西语
youdao.ZH_CN2SP = "ZH_CN2SP"
-- 英语 >> 中文
youdao.EN2ZH_CN = "EN2ZH_CN"
-- 日语 >> 中文
youdao.JA2ZH_CN = "JA2ZH_CN"
-- 韩语 >> 中文
youdao.KR2ZH_CN = "KR2ZH_CN"
-- 法语 >> 中文
youdao.FR2ZH_CN = "FR2ZH_CN"
-- 俄语 >> 中文
youdao.RU2ZH_CN = "RU2ZH_CN"
-- 西语 >> 中文
youdao.SP2ZH_CN = "SP2ZH_CN"

-- 转换
function youdao.translate(translate_type, translate_text)
  translate_type = youdao[translate_type]
  if type(translate) ~= 'string' then
    translate_type = "AUTO"
  end
  if type(translate_text) ~= 'string' or translate_text == '' then
    return nil, "invalid translate_text."
  end
  return httpc.get(youdao.host, nil, {
    {"doctype", "json"},
    {"i", translate_text},
    {"type", translate_type},
  })
end

return youdao