local config = require 'admin.config'

local crypt = require 'crypt'
local xor_str = crypt.xor_str
local hexencode = crypt.hexencode
local hexdecode = crypt.hexdecode

local sys = require "sys"
local now = sys.now
local match = string.match
local concat = table.concat

local token = {}

-- token加密与序列化
function token.encode (str)
  return hexencode(xor_str(str, config.secure)):upper()
end

-- token解密与反序列化
function token.decode (token)
  return xor_str(hexdecode(token:lower()), config.secure)
end

-- 生成 token
function token.generate (uid)
  return token.encode(concat({uid, now()}, ':'))
end

-- 解析token
-- function token.parser (token)
--   local str = token.decode(token)
--   return match(str, '([%d]+):([%d%.]+)')
-- end

return token
