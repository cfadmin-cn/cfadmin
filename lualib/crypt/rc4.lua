local CRYPT = require "lcrypt"
local hexencode = CRYPT.hexencode
local hexdecode = CRYPT.hexdecode
local rc4 = CRYPT.rc4

local RC4 = {}

-- `RC4`加密
function RC4.rc4_encrypt(key, text, hex)
  local hash = rc4(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

-- `RC4`解密
function RC4.rc4_decrypt(key, cipher, hex)
  if cipher and hex then
    cipher = hexdecode(cipher)
  end
  return rc4(key, cipher)
end

-- 初始化函数
return function (t)
  for k, v in pairs(RC4) do
    t[k] = v
  end
  return RC4
end