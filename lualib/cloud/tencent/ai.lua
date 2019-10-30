local httpc = require "httpc"
local crypt = require "crypt"
local md5 = crypt.md5
local urlencode = crypt.urlencode

local modf = math.modf
local now = require"sys".now
local time = os.time
local fmt = string.format

local sort = table.sort
local concat = table.concat


local function sign(AppID, AppKey, opt)
  opt["app_id"] = AppID
  opt["time_stamp"] = time()
  opt['nonce_str'] = fmt("%x", modf(now() * 100))
  opt["sign"] = ""
  local keys = {}
  for k, v in pairs(opt) do
    keys[#keys+1] = k
  end
  sort(keys)
  local args = {}
  local sign_list = {}
  for _, key in ipairs(keys) do
    local k, v = key, opt[key]
    if v ~= '' then
      args[#args+1] = {k, v}
      sign_list[#sign_list+1] = k .. '=' .. urlencode(v)
    end
  end
  sign_list[#sign_list+1] = "app_key=" .. AppKey
  args[#args+1] = {"sign", md5(concat(sign_list, "&"), true):upper()}
  return args
end

local ai = { __Version__ = 0.1, host = "https://api.ai.qq.com"}

-- 智能闲聊
function ai.chat(AppID, AppKey, session, text)
  return httpc.post(ai.host .. "/fcgi-bin/nlp/nlp_textchat", nil, sign(AppID, AppKey, { session = session, question = text }))
end

-- 文本转换为语音
function ai.text_to_voice(AppID, AppKey, opt)
  return httpc.post(ai.host .. "/fcgi-bin/aai/aai_tts", nil, sign(AppID, AppKey, opt))
end

-- 语种识别
function ai.text_detect(AppID, AppKey, force, langs, text)
  return httpc.post(ai.host .. "/fcgi-bin/nlp/nlp_textdetect", nil, sign(AppID, AppKey, { force = force or 0, candidate_langs = langs or "zh|en|jp|kr", text = text }))
end

-- 文本翻译
function ai.text_translate(AppID, AppKey, lang_code, text)
  return httpc.post(ai.host .. "/fcgi-bin/nlp/nlp_texttrans", nil, sign(AppID, AppKey, { type = lang_code, text = text }))
end

-- 语音翻译
function ai.voice_translate(AppID, AppKey, lang_code, text)
  return httpc.post(ai.host .. "/fcgi-bin/nlp/nlp_texttrans", nil, sign(AppID, AppKey, { type = lang_code, text = text }))
end

return ai