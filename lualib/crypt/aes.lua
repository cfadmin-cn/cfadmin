local CRYPT = require "lcrypt"
local hexencode = CRYPT.hexencode
local hexdecode = CRYPT.hexdecode
local aes_ecb_encrypt = CRYPT.aes_ecb_encrypt
local aes_ecb_decrypt = CRYPT.aes_ecb_decrypt

local aes_cbc_encrypt = CRYPT.aes_cbc_encrypt
local aes_cbc_decrypt = CRYPT.aes_cbc_decrypt

local aes_cfb_encrypt = CRYPT.aes_cfb_encrypt
local aes_cfb_decrypt = CRYPT.aes_cfb_decrypt

local aes_ofb_encrypt = CRYPT.aes_ofb_encrypt
local aes_ofb_decrypt = CRYPT.aes_ofb_decrypt

local aes_ctr_encrypt = CRYPT.aes_ctr_encrypt
local aes_ctr_decrypt = CRYPT.aes_ctr_decrypt

local aes_gcm_encrypt = CRYPT.aes_gcm_encrypt
local aes_gcm_decrypt = CRYPT.aes_gcm_decrypt

local AES = {}

-- 高级对称分组解密方法
function AES.aes_128_cbc_encrypt(key, text, iv, hex)
  local hash = aes_cbc_encrypt(16, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function AES.aes_128_ecb_encrypt(key, text, iv, hex)
  local hash = aes_ecb_encrypt(16, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function AES.aes_128_cfb_encrypt(key, text, iv, hex)
  local hash = aes_cfb_encrypt(16, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function AES.aes_128_ofb_encrypt(key, text, iv, hex)
  local hash = aes_ofb_encrypt(16, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function AES.aes_128_ctr_encrypt(key, text, iv, hex)
  local hash = aes_ctr_encrypt(16, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function AES.aes_128_gcm_encrypt(key, text, iv, aad, hex)
  local hash = aes_gcm_encrypt(16, key, text, iv, aad)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function AES.aes_192_cbc_encrypt(key, text, iv, hex)
  local hash = aes_cbc_encrypt(24, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function AES.aes_192_ecb_encrypt(key, text, iv, hex)
  local hash = aes_ecb_encrypt(24, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function AES.aes_192_cfb_encrypt(key, text, iv, hex)
  local hash = aes_cfb_encrypt(24, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function AES.aes_192_ofb_encrypt(key, text, iv, hex)
  local hash = aes_ofb_encrypt(24, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function AES.aes_192_ctr_encrypt(key, text, iv, hex)
  local hash = aes_ctr_encrypt(24, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function AES.aes_192_gcm_encrypt(key, text, iv, aad, hex)
  local hash = aes_gcm_encrypt(24, key, text, iv, aad)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function AES.aes_256_cbc_encrypt(key, text, iv, hex)
  local hash = aes_cbc_encrypt(32, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function AES.aes_256_ecb_encrypt(key, text, iv, hex)
  local hash = aes_ecb_encrypt(32, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function AES.aes_256_cfb_encrypt(key, text, iv, hex)
  local hash = aes_cfb_encrypt(32, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function AES.aes_256_ofb_encrypt(key, text, iv, hex)
  local hash = aes_ofb_encrypt(32, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function AES.aes_256_ctr_encrypt(key, text, iv, hex)
  local hash = aes_ctr_encrypt(32, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function AES.aes_256_gcm_encrypt(key, text, iv, aad, hex)
  local hash = aes_gcm_encrypt(32, key, text, iv, aad)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

-- 高级对称分组解密方法
function AES.aes_128_cbc_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_cbc_decrypt(16, key, cipher, iv)
end

function AES.aes_128_ecb_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_ecb_decrypt(16, key, cipher, iv)
end

function AES.aes_128_cfb_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_cfb_decrypt(16, key, cipher, iv)
end

function AES.aes_128_ofb_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_ofb_decrypt(16, key, cipher, iv)
end

function AES.aes_128_ctr_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_ctr_decrypt(16, key, cipher, iv)
end

function AES.aes_128_gcm_decrypt(key, cipher, iv, aad, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_gcm_decrypt(16, key, cipher, iv, aad)
end

function AES.aes_192_cbc_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_cbc_decrypt(24, key, cipher, iv)
end

function AES.aes_192_ecb_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_ecb_decrypt(24, key, cipher, iv)
end

function AES.aes_192_cfb_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_cfb_decrypt(24, key, cipher, iv)
end

function AES.aes_192_ofb_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_ofb_decrypt(24, key, cipher, iv)
end

function AES.aes_192_ctr_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_ctr_decrypt(24, key, cipher, iv)
end

function AES.aes_192_gcm_decrypt(key, cipher, iv, aad, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_gcm_decrypt(24, key, cipher, iv, aad)
end

function AES.aes_256_cbc_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_cbc_decrypt(32, key, cipher, iv)
end

function AES.aes_256_ecb_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_ecb_decrypt(32, key, cipher, iv)
end

function AES.aes_256_cfb_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_cfb_decrypt(32, key, cipher, iv)
end

function AES.aes_256_ofb_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_ofb_decrypt(32, key, cipher, iv)
end

function AES.aes_256_ctr_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_ctr_decrypt(32, key, cipher, iv)
end

function AES.aes_256_gcm_decrypt(key, cipher, iv, aad, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_gcm_decrypt(32, key, cipher, iv, aad)
end
-- 初始化函数
return function (t)
  for k, v in pairs(AES) do
    t[k] = v
  end
  return AES
end