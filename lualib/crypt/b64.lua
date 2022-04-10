local CRYPT = require "lcrypt"
local base64encode = CRYPT.base64encode
local base64decode = CRYPT.base64decode

local B64 = {}

---comment 普通BASE64编码
---@param text string        @等待编码的内容
---@param nopadding boolean  @是否保留填充字符(默认保留)
---@return string @返回编码后的内容
function B64.base64encode(text, nopadding)
  return base64encode(text, false, nopadding)
end

---comment 普通BASE64解码
---@param text string  @等待解码的内容
---@return string      @返回解码后的内容
function B64.base64decode(text)
  return base64decode(text, false)
end

---comment URL安全的BASE64编码
---@param text string        @等待编码的内容
---@param nopadding boolean  @是否保留填充字符(默认保留)
---@return string            @返回编码后的内容
function B64.base64urlencode(text, nopadding)
  return base64encode(text, true, nopadding)
end

---comment URL安全的BASE64解码
---@param text string  @等待解码的内容
---@return string      @返回解码后的内容
function B64.base64urldecode(text)
  return base64decode(text, true)
end

-- 初始化函数
return function (t)
  for k, v in pairs(B64) do
    t[k] = v
  end
  return B64
end