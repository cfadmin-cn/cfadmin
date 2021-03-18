local CRYPT = require "lcrypt"

local hexencode = CRYPT.hexencode
local hexdecode = CRYPT.hexdecode
local base64encode = CRYPT.base64encode
local base64decode = CRYPT.base64decode

-- 填充方式
local RSA_NO_PADDING = CRYPT.RSA_NO_PADDING
local RSA_PKCS1_PADDING = CRYPT.RSA_PKCS1_PADDING
local RSA_PKCS1_OAEP_PADDING = CRYPT.RSA_PKCS1_OAEP_PADDING

local rsa_public_key_encode = CRYPT.rsa_public_key_encode
local rsa_private_key_decode = CRYPT.rsa_private_key_decode

local rsa_private_key_encode = CRYPT.rsa_private_key_encode
local rsa_public_key_decode = CRYPT.rsa_public_key_decode

-- 当前支持的签名与验签方法
local rsa_sign = CRYPT.rsa_sign
local rsa_verify = CRYPT.rsa_verify

-- 当前支持的签名与验签
local rsa_algorithms = {
  ["md5"]     =  CRYPT.nid_md5,
  ["sha1"]    =  CRYPT.nid_sha1,
  ["sha128"]  =  CRYPT.nid_sha1,
  ["sha256"]  =  CRYPT.nid_sha256,
  ["sha512"]  =  CRYPT.nid_sha512,
}

local RSA = {}

-- `text` 为原始文本内容, `public_key_path` 为公钥路径, `b64` 为是否为结果进行`base64`编码
function RSA.rsa_public_key_encode(text, public_key_path, b64)
  local hash = rsa_public_key_encode(text, public_key_path, RSA_PKCS1_PADDING)
  if hash and b64 then
    return base64encode(hash)
  end
  return hash
end

-- `text` 为原始文本内容, `public_key_path` 为公钥路径, `b64` 为是否为结果进行`base64`编码
function RSA.rsa_public_key_no_padding_encode(text, public_key_path, b64)
  local hash = rsa_public_key_encode(text, public_key_path, RSA_NO_PADDING)
  if hash and b64 then
    return base64encode(hash)
  end
  return hash
end

-- `text` 为原始文本内容, `public_key_path` 为公钥路径, `b64` 为是否为结果进行`base64`编码
function RSA.rsa_public_key_oaep_padding_encode(text, public_key_path, b64)
  local hash = rsa_public_key_encode(text, public_key_path, RSA_PKCS1_OAEP_PADDING)
  if hash and b64 then
    return base64encode(hash)
  end
  return hash
end

-- `text` 为加密后的内容, `private_key_path` 为私钥路径, `b64` 为是否为`text`先进行`base64`解码
function RSA.rsa_private_key_decode(text, private_key_path, b64)
  return rsa_private_key_decode(b64 and base64decode(text) or text, private_key_path, RSA_PKCS1_PADDING)
end

-- `text` 为加密后的内容, `private_key_path` 为私钥路径, `b64` 为是否为`text`先进行`base64`解码
function RSA.rsa_private_key_no_padding_decode(text, private_key_path, b64)
  return rsa_private_key_decode(b64 and base64decode(text) or text, private_key_path, RSA_NO_PADDING)
end

-- `text` 为加密后的内容, `private_key_path` 为私钥路径, `b64` 为是否为`text`先进行`base64`解码
function RSA.rsa_private_key_oaep_padding_decode(text, private_key_path, b64)
  return rsa_private_key_decode(b64 and base64decode(text) or text, private_key_path, RSA_PKCS1_OAEP_PADDING)
end


-- `text` 为原始文本内容, `private_key_path` 为公钥路径, `b64` 为是否为结果进行`base64`编码
function RSA.rsa_private_key_encode(text, private_key_path, b64)
  local hash = rsa_private_key_encode(text, private_key_path, RSA_PKCS1_PADDING)
  if hash and b64 then
    return base64encode(hash)
  end
  return hash
end

-- `text` 为原始文本内容, `private_key_path` 为公钥路径, `b64` 为是否为结果进行`base64`编码
function RSA.rsa_private_key_no_padding_encode(text, private_key_path, b64)
  local hash = rsa_private_key_encode(text, private_key_path, RSA_NO_PADDING)
  if hash and b64 then
    return base64encode(hash)
  end
  return hash
end

-- `text` 为原始文本内容, `private_key_path` 为公钥路径, `b64` 为是否为结果进行`base64`编码
function RSA.rsa_private_key_oaep_padding_encode(text, private_key_path, b64)
  local hash = rsa_private_key_encode(text, private_key_path, RSA_PKCS1_OAEP_PADDING)
  if hash and b64 then
    return base64encode(hash)
  end
  return hash
end

-- `text` 为加密后的内容, `public_key_path` 为公钥路径, `b64`为是否为`text·先进行`base64`解码
function RSA.rsa_public_key_decode(text, public_key_path, b64)
  return rsa_public_key_decode(b64 and base64decode(text) or text, public_key_path, RSA_PKCS1_PADDING)
end

function RSA.rsa_public_key_no_padding_decode(text, public_key_path, b64)
  return rsa_public_key_decode(b64 and base64decode(text) or text, public_key_path, RSA_NO_PADDING)
end

function RSA.rsa_public_key_oaep_padding_decode(text, public_key_path, b64)
  return rsa_public_key_decode(b64 and base64decode(text) or text, public_key_path, RSA_PKCS1_OAEP_PADDING)
end

-- RSA签名函数: 第一个参数是等待签名的明文, 第二个参数是私钥所在路径, 第三个参数是算法名称, 第四个参数决定是否以hex输出
function RSA.rsa_sign(text, private_key_path, algorithm, hex)
  local hash = rsa_sign(text, private_key_path, rsa_algorithms[(algorithm or ""):lower()] or rsa_algorithms["md5"])
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

-- RSA验签函数: 第一个参数是等待签名的明文, 第二个参数是私钥所在路径, 第三个参数为签名sign密文, 第四个参数是算法名称, 第五个参数决定是否对sign进行unhex
function RSA.rsa_verify(text, public_key_path, sign, algorithm, hex)
  if hex then
    sign = hexdecode(sign)
  end
  return rsa_verify(text, public_key_path, sign, rsa_algorithms[(algorithm or ""):lower()] or rsa_algorithms["md5"])
end

-- 初始化函数
return function (t)
  for k, v in pairs(RSA) do
    t[k] = v
  end
  return RSA
end