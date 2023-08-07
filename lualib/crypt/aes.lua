local CRYPT = require "lcrypt"
local hexencode = CRYPT.hexencode
local hexdecode = CRYPT.hexdecode

local base64encode = CRYPT.base64encode
local base64decode = CRYPT.base64decode

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

local aes_ccm_encrypt = CRYPT.aes_ccm_encrypt
local aes_ccm_decrypt = CRYPT.aes_ccm_decrypt

---@class CRYPT
---@field aes_128_ecb_encrypt  fun(key:string, text:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_192_ecb_encrypt  fun(key:string, text:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_256_ecb_encrypt  fun(key:string, text:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_128_cbc_encrypt  fun(key:string, text:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_192_cbc_encrypt  fun(key:string, text:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_256_cbc_encrypt  fun(key:string, text:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_128_cfb_encrypt  fun(key:string, text:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_192_cfb_encrypt  fun(key:string, text:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_256_cfb_encrypt  fun(key:string, text:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_128_ofb_encrypt  fun(key:string, text:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_192_ofb_encrypt  fun(key:string, text:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_256_ofb_encrypt  fun(key:string, text:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_128_ctr_encrypt  fun(key:string, text:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_192_ctr_encrypt  fun(key:string, text:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_256_ctr_encrypt  fun(key:string, text:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_128_ecb_decrypt  fun(key:string, cipher:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_192_ecb_decrypt  fun(key:string, cipher:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_256_ecb_decrypt  fun(key:string, cipher:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_128_cbc_decrypt  fun(key:string, cipher:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_192_cbc_decrypt  fun(key:string, cipher:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_256_cbc_decrypt  fun(key:string, cipher:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_128_cfb_decrypt  fun(key:string, cipher:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_192_cfb_decrypt  fun(key:string, cipher:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_256_cfb_decrypt  fun(key:string, cipher:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_128_ofb_decrypt  fun(key:string, cipher:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_192_ofb_decrypt  fun(key:string, cipher:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_256_ofb_decrypt  fun(key:string, cipher:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_128_ctr_decrypt  fun(key:string, cipher:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_192_ctr_decrypt  fun(key:string, cipher:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_256_ctr_decrypt  fun(key:string, cipher:string, iv:string, hex:boolean|'base64'?, padding:integer?):string
---@field aes_128_gcm_encrypt  fun(key:string, text:string, iv:string, aad:string, tag_len:integer?, hex:boolean|'base64'?):string
---@field aes_192_gcm_encrypt  fun(key:string, text:string, iv:string, aad:string, tag_len:integer?, hex:boolean|'base64'?):string
---@field aes_256_gcm_encrypt  fun(key:string, text:string, iv:string, aad:string, tag_len:integer?, hex:boolean|'base64'?):string
---@field aes_128_gcm_decrypt  fun(key:string, cipher:string, iv:string, aad:string, tag_len:integer?, hex:boolean|'base64'?):string
---@field aes_192_gcm_decrypt  fun(key:string, cipher:string, iv:string, aad:string, tag_len:integer?, hex:boolean|'base64'?):string
---@field aes_256_gcm_decrypt  fun(key:string, cipher:string, iv:string, aad:string, tag_len:integer?, hex:boolean|'base64'?):string
local AES = {}

--[[
 aes.aes_128/192/256_xxx_encrypt(...) -- 加密
 aes.aes_128/192/256_xxx_decrypt(...) -- 解密
--]]

local len = { 16, 24, 32 }
local bit = { 128, 192, 256 }

local padding_map = {
  [0]  = CRYPT.AES_PADDING_ZERO,
  -- [5]  = CRYPT.AES_PADDING_PKCS5,
  [7] = CRYPT.AES_PADDING_PKCS7,
}

local enc_map = {
  { name = "cbc_encrypt", f = aes_cbc_encrypt },
  { name = "ecb_encrypt", f = aes_ecb_encrypt },
  { name = "cfb_encrypt", f = aes_cfb_encrypt },
  { name = "ofb_encrypt", f = aes_ofb_encrypt },
  { name = "ctr_encrypt", f = aes_ctr_encrypt },
}

local dec_map = {
  { name = "cbc_decrypt", f = aes_cbc_decrypt },
  { name = "ecb_decrypt", f = aes_ecb_decrypt },
  { name = "cfb_decrypt", f = aes_cfb_decrypt },
  { name = "ofb_decrypt", f = aes_ofb_decrypt },
  { name = "ctr_decrypt", f = aes_ctr_decrypt },
}

for i = 1 , #enc_map do
  local e, d = enc_map[i], dec_map[i]
  for j = 1, #len do
    AES[string.format("aes_%d_%s", bit[j], e.name)] = function(key, text, iv, hex, padding)
      local hash, err = e.f(len[j], key, text, iv, padding_map[padding])
      if hash then
        if hex then
          if hex == 'base64' then
            hash = base64encode(hash)
          else
            hash = hexencode(hash)
          end
        end
        return hash
      end
      return false, err
    end
    AES[string.format("aes_%d_%s", bit[j], d.name)] = function(key, cipher, iv, hex, padding)
      if hex then
        if hex == 'base64' then
          cipher = base64decode(cipher, true)
        else
          cipher = hexdecode(cipher)
        end
      end
      return d.f(len[j], key, cipher, iv, padding_map[padding])
    end
  end
end

local enc_map_ex = {
  { name = "gcm_encrypt", f = aes_gcm_encrypt },
  { name = "ccm_encrypt", f = aes_ccm_encrypt },
}

local dec_map_ex = {
  { name = "gcm_decrypt", f = aes_gcm_decrypt },
  { name = "ccm_decrypt", f = aes_ccm_decrypt },
}

for i = 1 , #enc_map_ex do
  local e, d = enc_map_ex[i], dec_map_ex[i]
  for j = 1, #len do
    AES[string.format("aes_%d_%s", bit[j], e.name)] = function(key, text, iv, aad, tag_len, hex)
      local hash, err = e.f(len[j], key, text, iv, aad, tag_len)
      if hash then
        if hex then
          if hex == 'base64' then
            hash = base64encode(hash)
          else
            hash = hexencode(hash)
          end
        end
        return hash
      end
      return false, err
    end
    AES[string.format("aes_%d_%s", bit[j], d.name)] = function(key, cipher, iv, aad, tag_len, hex)
      if hex then
        if hex == 'base64' then
          cipher = base64decode(cipher, true)
        else
          cipher = hexdecode(cipher)
        end
      end
      return d.f(len[j], key, cipher, iv, aad, tag_len)
    end
  end
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