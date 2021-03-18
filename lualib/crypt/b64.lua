local CRYPT = require "lcrypt"
local base64encode = CRYPT.base64encode
local base64decode = CRYPT.base64decode

local B64 = {}

function B64.base64encode(text)
  return base64encode(text)
end

function B64.base64decode(text)
  return base64decode(text)
end

function B64.base64urlencode(data)
  return base64encode(data):gsub('+', '-'):gsub('/', '_')
end

function B64.base64urldecode(data)
  return base64decode(data:gsub('-', '+'):gsub('_', '/'))
end

-- 初始化函数
return function (t)
  for k, v in pairs(B64) do
    t[k] = v
  end
  return B64
end