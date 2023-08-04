local CRYPTO = require "lcrypt"

local hexencode = CRYPTO.hexencode
local hexdecode = CRYPTO.hexdecode
local base64encode = CRYPTO.base64encode
local base64decode = CRYPTO.base64decode

-- 填充方式
local RSA_NO_PADDING = CRYPTO.RSA_NO_PADDING
local RSA_PKCS1_PADDING = CRYPTO.RSA_PKCS1_PADDING
local RSA_PKCS1_OAEP_PADDING = CRYPTO.RSA_PKCS1_OAEP_PADDING

local rsa_public_key_encode = CRYPTO.rsa_public_key_encode
local rsa_private_key_encode = CRYPTO.rsa_private_key_encode
local rsa_private_key_decode = CRYPTO.rsa_private_key_decode

-- 当前支持的签名与验签方法
local rsa_sign = CRYPTO.rsa_sign
local rsa_verify = CRYPTO.rsa_verify

-- 当前支持的签名与验签
local rsa_algorithms = {
  ["md5"]     =  CRYPTO.nid_md5,
  ["sha1"]    =  CRYPTO.nid_sha1,
  ["sha128"]  =  CRYPTO.nid_sha1,
  ["sha224"]  =  CRYPTO.nid_sha224,
  ["sha256"]  =  CRYPTO.nid_sha256,
  ["sha384"]  =  CRYPTO.nid_sha384,
  ["sha512"]  =  CRYPTO.nid_sha512,
}

-- 加密后的格式
local rsa_padding = {
  ["oaep"]       = RSA_PKCS1_OAEP_PADDING,
  ["pkcs1"]      = RSA_PKCS1_PADDING,
  ["nopadding"]  = RSA_NO_PADDING,
}

local function rsa_pub_enc(text, pkey, b64, padding)
  local cipher = rsa_public_key_encode(text, pkey, rsa_padding[padding] or rsa_padding['pkcs1'])
  if cipher and b64 then
    return base64encode(cipher)
  end
  return cipher
end

local function rsa_pri_enc(text, pkey, b64, padding, pw)
  local cipher = rsa_private_key_encode(text, pkey, rsa_padding[padding] or rsa_padding['pkcs1'], pw)
  if cipher and b64 then
    return base64encode(cipher)
  end
  return cipher
end

local function rsa_pri_dec(cipher, pkey, b64, padding, pw)
  if b64 then
    cipher = base64decode(cipher)
  end
  return rsa_private_key_decode(cipher, pkey, rsa_padding[padding] or rsa_padding['pkcs1'], pw)
end

-- local function rsa_pub_dec(cipher, pkey, b64, padding)
--   if b64 then
--     cipher = base64decode(cipher)
--   end
--   return rsa_public_key_decode(cipher, pkey, rsa_padding[padding] or rsa_padding['pkcs1'])
-- end

---@class crypto
local RSA = {}

---------------- 私钥加密/解密 --------------------

---comment `RSA`私钥加密(`pkcs1`格式); 成功返回加密后的文本, 失败返回`false`与错误信息.
---@param text   string  @待加密的文本
---@param prikey string  @私钥内容或者私钥所在路径
---@param b64?   boolean @将加密后的内容进行`BASE64`编码
---@param pw?    string  @如果有密码则填入.
function RSA.rsa_private_key_encode(text, prikey, b64, pw)
  return rsa_pri_enc(text, prikey, b64 and true or false, 'pkcs1', pw)
end

---comment `RSA`私钥加密(`oaep`格式); 成功返回加密后的文本, 失败返回`false`与错误信息.
---@param text   string  @待加密的文本
---@param prikey string  @私钥内容或者私钥所在路径
---@param b64?   boolean @将加密后的内容进行`BASE64`编码
---@param pw?    string  @如果有密码则填入.
function RSA.rsa_private_key_oaep_padding_encode(text, prikey, b64, pw)
  return rsa_pri_enc(text, prikey, b64 and true or false, 'oaep', pw)
end

---comment `RSA`私钥加密(`nopadding`); 成功返回加密后的文本, 失败返回`false`与错误信息.
---@param text   string  @待加密的文本
---@param prikey string  @私钥内容或者私钥所在路径
---@param b64    boolean @将加密后的内容进行`BASE64`编码
---@param pw?    string  @如果有密码则填入.
function RSA.rsa_private_key_no_padding_encode(text, prikey, b64, pw)
  return rsa_pri_enc(text, prikey, b64 and true or false, 'nopadding', pw)
end

---comment `RSA`私钥解密(`pkcs1`格式); 成功返回解密后的明文, 失败返回`false`与错误信息.
---@param cipher string  @已加密的文本
---@param prikey string  @私钥内容或者私钥所在路径
---@param b64?   boolean @内容进行`BASE64`解码
---@param pw?    string  @如果有密码则填入.
function RSA.rsa_private_key_decode(cipher, prikey, b64, pw)
  return rsa_pri_dec(cipher, prikey, b64 and true or false, 'pkcs1', pw)
end

---comment `RSA`私钥解密(`oaep`格式); 成功返回解密后的明文, 失败返回`false`与错误信息.
---@param cipher string  @已加密的文本
---@param prikey string  @私钥内容或者私钥所在路径
---@param b64?   boolean @内容进行`BASE64`解码
---@param pw?    string  @如果有密码则填入.
function RSA.rsa_private_key_oaep_padding_decode(cipher, prikey, b64, pw)
  return rsa_pri_dec(cipher, prikey, b64 and true or false, 'oaep', pw)
end

---comment `RSA`私钥解密(`nopadding`); 成功返回解密后的明文, 失败返回`false`与错误信息.
---@param cipher string  @已加密的文本
---@param prikey string  @私钥内容或者私钥所在路径
---@param b64?   boolean @内容进行`BASE64`解码
---@param pw?    string  @如果有密码则填入.
function RSA.rsa_private_key_no_padding_decode(cipher, prikey, b64, pw)
  return rsa_pri_dec(cipher, prikey, b64 and true or false, 'nopadding', pw)
end

---------------- 公钥加密/解密 --------------------

---comment `RSA`公钥加密(`pkcs1`格式); 成功返回加密后的文本, 失败返回`false`与错误信息.
---@param text   string  @待加密的文本
---@param pubkey string  @公钥内容或者公钥所在路径
---@param b64?   boolean @将加密后的内容进行`BASE64`编码
function RSA.rsa_public_key_encode(text, pubkey, b64)
  return rsa_pub_enc(text, pubkey, b64 and true or false, 'pkcs1')
end

---comment `RSA`公钥加密(`oaep`格式); 成功返回加密后的文本, 失败返回`false`与错误信息.
---@param text   string  @待加密的文本
---@param pubkey string  @公钥内容或者公钥所在路径
---@param b64?   boolean @将加密后的内容进行`BASE64`编码
function RSA.rsa_public_key_oaep_padding_encode(text, pubkey, b64)
  return rsa_pub_enc(text, pubkey, b64 and true or false, 'oaep')
end

---comment `RSA`公钥加密(`nopadding`); 成功返回加密后的文本, 失败返回`false`与错误信息.
---@param text   string  @待加密的文本
---@param pubkey string  @公钥内容或者公钥所在路径
---@param b64?   boolean @将加密后的内容进行`BASE64`编码
function RSA.rsa_public_key_no_padding_encode(text, pubkey, b64)
  return rsa_pub_enc(text, pubkey, b64 and true or false, 'nopadding')
end

----------------------------------------------------------------------------------------------------

---comment `RSA`签名函数(目前支持:`md5`、`sha128` ~ `sha512`)
---@param text    string                                             @待签名的明文
---@param prikey  string                                             @私钥内容或者所在路径
---@param alg     "md5"|"sha128"|"sha224"|"sha256"|"sha384"|"sha512" @签名算法(例如: `"md5"`)
---@param hex?    'base64' | boolean                                 @签名是否编码(可选)
function RSA.rsa_sign(text, prikey, alg, hex)
  local sign = rsa_sign(text, prikey, rsa_algorithms[alg] or rsa_algorithms['md5'])
  if sign and hex then
    if hex == 'base64' then
      sign = base64encode(sign)
    else
      sign = hexencode(sign)
    end
  end
  return sign
end

---comment `RSA`验签函数(目前支持:`md5`、`sha128` ~ `sha512`)
---@param text    string                                             @待签名的明文
---@param pubkey  string                                             @公钥内容或者所在路径
---@param sign    string                                             @待对比的签名内容
---@param alg     "md5"|"sha128"|"sha224"|"sha256"|"sha384"|"sha512" @签名算法(例如: `"md5"`)
---@param hex?    'base64' | boolean                                 @`sign`是否解码(可选)
function RSA.rsa_verify(text, pubkey, sign, alg, hex)
  if hex then
    if hex == 'base64' then
      sign = base64decode(sign)
    else
      sign = hexdecode(sign)
    end
  end
  return rsa_verify(text, pubkey, sign, rsa_algorithms[alg] or rsa_algorithms['md5'])
end

-- 初始化函数
return function (t)
  for k, v in pairs(RSA) do
    t[k] = v
  end
  return RSA
end