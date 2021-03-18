local CRYPT = require "lcrypt"
local sm3 = CRYPT.sm3
local hmac_sm3 = CRYPT.hmac_sm3
local sm2keygen = CRYPT.sm2keygen
local sm2sign = CRYPT.sm2sign
local sm2verify = CRYPT.sm2verify
local hexencode = CRYPT.hexencode
local base64encode = CRYPT.base64encode
local base64decode = CRYPT.base64decode

local sm4_cbc_encrypt = CRYPT.sm4_cbc_encrypt
local sm4_cbc_decrypt = CRYPT.sm4_cbc_decrypt

local sm4_ecb_encrypt = CRYPT.sm4_ecb_encrypt
local sm4_ecb_decrypt = CRYPT.sm4_ecb_decrypt

local sm4_ofb_encrypt = CRYPT.sm4_ofb_encrypt
local sm4_ofb_decrypt = CRYPT.sm4_ofb_decrypt

local sm4_ctr_encrypt = CRYPT.sm4_ctr_encrypt
local sm4_ctr_decrypt = CRYPT.sm4_ctr_decrypt

local SM = {}

-- 哈希
function SM.sm3(str, hex)
  local hash = sm3(str)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

-- 摘要
function SM.hmac_sm3 (key, text, hex)
  local hash = hmac_sm3(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

-- 生成SM2私钥、公钥
function SM.sm2keygen(pri_path, pub_path)
  return sm2keygen(pri_path, pub_path)
end

-- SM3WithSM2签名
function SM.sm2sign(pri_path, text, b64)
  local sign = sm2sign(pri_path, text)
  if b64 then
    sign = base64encode(sign)
  end
  return sign
end

-- SM3WithSM2验签
function SM.sm2verify(pub_path, text, sign, b64)
  if b64 then
    sign = base64decode(sign)
  end
  return sm2verify(pub_path, text, sign)
end

-- SM4分组加密算法之CBC
function SM.sm4_cbc_encrypt(key, text, iv, b64)
  local cipher = sm4_cbc_encrypt(key, text, iv)
  if b64 then
    cipher = base64encode(cipher)
  end
  return cipher
end

-- SM4分组加密算法之CBC
function SM.sm4_cbc_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64decode(cipher)
  end
  return sm4_cbc_decrypt(key, cipher, iv)
end

-- SM4分组加密算法之ECB
function SM.sm4_ecb_encrypt(key, text, iv, b64)
  local cipher = sm4_ecb_encrypt(key, text, iv)
  if b64 then
    cipher = base64encode(cipher)
  end
  return cipher
end

-- SM4分组解密算法之ECB
function SM.sm4_ecb_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64decode(cipher)
  end
  return sm4_ecb_decrypt(key, cipher, iv)
end

-- SM4分组加密算法之OFB
function SM.sm4_ofb_encrypt(key, text, iv, b64)
  local cipher = sm4_ofb_encrypt(key, text, iv)
  if b64 then
    cipher = base64encode(cipher)
  end
  return cipher
end

-- SM4分组解密算法之OFB
function SM.sm4_ofb_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64decode(cipher)
  end
  return sm4_ofb_decrypt(key, cipher, iv)
end

-- SM4分组加密算法之CTR
function SM.sm4_ctr_encrypt(key, text, iv, b64)
  local cipher = sm4_ctr_encrypt(key, text, iv)
  if b64 then
    cipher = base64encode(cipher)
  end
  return cipher
end

-- SM4分组解密算法之CTR
function SM.sm4_ctr_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64decode(cipher)
  end
  return sm4_ctr_decrypt(key, cipher, iv)
end

-- 初始化函数
return function (t)
  for k, v in pairs(SM) do
    t[k] = v
  end
  return SM
end