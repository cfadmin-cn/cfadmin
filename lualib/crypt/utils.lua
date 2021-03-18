local CRYPT = require "lcrypt"
local xor_str = CRYPT.xor_str
local hashkey = CRYPT.hashkey
local randomkey = CRYPT.randomkey
local hexencode = CRYPT.hexencode

local UTILS = {}

function UTILS.xor_str (text, key, hex)
  local hash = xor_str(text, key)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function UTILS.randomkey(hex)
  local hash = randomkey(8)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function UTILS.randomkey_ex(byte, hex)
  local hash = randomkey(byte)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function UTILS.hashkey (key, hex)
  local hash = hashkey(key)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

-- 初始化函数
return function (t)
  for k, v in pairs(UTILS) do
    t[k] = v
  end
  return UTILS
end