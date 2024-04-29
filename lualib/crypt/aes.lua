local CRYPT = require "lcrypt"

local aesenc = CRYPT.aes_enc
local aesdec = CRYPT.aes_dec

local hexencode = CRYPT.hexencode
local hexdecode = CRYPT.hexdecode

local base64encode = CRYPT.base64encode
local base64decode = CRYPT.base64decode

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

local padding_map = {
  [0]  = CRYPT.AES_PADDING_ZERO,
  [5]  = CRYPT.AES_PADDING_PKCS5,
  [7] = CRYPT.AES_PADDING_PKCS7,
}

local bits = { 128, 192, 256 }

local list = { "ecb", "cbc", "cfb", "ofb", "ocb", "ctr" }

for _, name in ipairs(list) do
  for _, bit in ipairs(bits) do
    local nid = 'EVP_aes_' .. bit .. '_' .. name
    AES['aes_' .. bit .. '_' ..  name .. '_encrypt'] = function (key, text, iv, hex, padding)
      local data, errinfo = aesenc(CRYPT[nid], key, text, iv, padding_map[padding or 7])
      if not data then
        return nil, errinfo
      end
      if hex then
        data = hex == 'base64' and base64encode(data) or hexencode(data)
      end
      return data
    end
    AES['aes_' .. bit .. '_' .. name .. '_decrypt'] = function (key, cipher, iv, hex, padding)
      if hex then
        cipher = hex == 'base64' and base64decode(cipher) or hexdecode(cipher)
      end
      return aesdec(CRYPT[nid], key, cipher, iv, padding_map[padding or 7])
    end
  end
end

local list_ex = { "ccm", "gcm" }

for _, name in ipairs(list_ex) do
  for _, bit in ipairs(bits) do
    local nid = 'EVP_aes_' .. bit .. '_' .. name
    AES['aes_' .. bit .. '_' ..  name .. '_encrypt'] = function (key, text, iv, aad, taglen, hex)
      local data, errinfo = aesenc(CRYPT[nid], key, text, iv, nil, aad, taglen)
      if not data then
        return nil, errinfo
      end
      if hex then
        data = hex == 'base64' and base64encode(data) or hexencode(data)
      end
      return data
    end
    AES['aes_' .. bit .. '_' .. name .. '_decrypt'] = function (key, cipher, iv, aad, taglen, hex)
      if hex then
        cipher = hex == 'base64' and base64decode(cipher) or hexdecode(cipher)
      end
      return aesdec(CRYPT[nid], key, cipher, iv, nil, aad, taglen)
    end
  end
end

-- 初始化函数
return function (t)
  for k, v in pairs(AES) do
    t[k] = v
  end
  return AES
end