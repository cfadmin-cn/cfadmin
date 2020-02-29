local CRYPT = require "lcrypt"
local new_tab = require("sys").new_tab

local uuid = CRYPT.uuid

local md5 = CRYPT.md5
local hmac64 = CRYPT.hmac64
local hmac_md5 = CRYPT.hmac_md5
local hmac64_md5 = CRYPT.hmac64_md5

local sha1 = CRYPT.sha1
local sha224 = CRYPT.sha224
local sha256 = CRYPT.sha256
local sha384 = CRYPT.sha384
local sha512 = CRYPT.sha512

local hmac_sha1 = CRYPT.hmac_sha1
-- local hmac_sha224 = CRYPT.hmac_sha224
local hmac_sha256 = CRYPT.hmac_sha256
-- local hmac_sha384 = CRYPT.hmac_sha384
local hmac_sha512 = CRYPT.hmac_sha512

local crc32 = CRYPT.crc32
local crc64 = CRYPT.crc64

local xor_str = CRYPT.xor_str
local hashkey = CRYPT.hashkey
local randomkey = CRYPT.randomkey

local hmac_hash = CRYPT.hmac_hash

local base64encode = CRYPT.base64encode
local base64decode = CRYPT.base64decode

local hexencode = CRYPT.hexencode
local hexdecode = CRYPT.hexdecode

local desencode = CRYPT.desencode
local desdecode = CRYPT.desdecode

local dhsecret = CRYPT.dhsecret
local dhexchange = CRYPT.dhexchange

local urlencode = CRYPT.urlencode
local urldecode = CRYPT.urldecode

local aes_ecb_encrypt = CRYPT.aes_ecb_encrypt
local aes_ecb_decrypt = CRYPT.aes_ecb_decrypt

local aes_cbc_encrypt = CRYPT.aes_cbc_encrypt
local aes_cbc_decrypt = CRYPT.aes_cbc_decrypt

local rsa_public_key_encode = CRYPT.rsa_public_key_encode
local rsa_private_key_decode = CRYPT.rsa_private_key_decode

local rsa_private_key_encode = CRYPT.rsa_private_key_encode
local rsa_public_key_decode = CRYPT.rsa_public_key_decode

local sha128WithRsa_sign = CRYPT.sha128WithRsa_sign
local sha128WithRsa_verify = CRYPT.sha128WithRsa_verify

local sha256WithRsa_sign = CRYPT.sha256WithRsa_sign
local sha256WithRsa_verify = CRYPT.sha256WithRsa_verify

local crypt = {}

function crypt.uuid()
  return uuid()
end

function crypt.md5(str, hex)
  local hash = md5(str)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.hmac_md5 (key, text, hex)
  local hash = hmac_md5(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.sha1(str, hex)
  local hash = sha1(str)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.sha224 (str, hex)
  local hash = sha224(str)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.sha256 (str, hex)
  local hash = sha256(str)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.sha384 (str, hex)
  local hash = sha384(str)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.sha512 (str, hex)
  local hash = sha512(str)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end


function crypt.hmac_sha1 (key, text, hex)
  local hash = hmac_sha1(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

-- function crypt.hmac_sha224 (key, text, hex)
--   local hash = hmac_sha224(key, text)
--   if hash and hex then
--     return hexencode(hash)
--   end
--   return hash
-- end

function crypt.hmac_sha256 (key, text, hex)
  local hash = hmac_sha256(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

-- function crypt.hmac_sha384 (key, text, hex)
--   local hash = hmac_sha384(key, text)
--   if hash and hex then
--     return hexencode(hash)
--   end
--   return hash
-- end

function crypt.hmac_sha512 (key, text, hex)
  local hash = hmac_sha512(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.xor_str (text, key, hex)
  local hash = xor_str(text, key)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.randomkey(hex)
  local hash = randomkey()
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.hashkey (key, hex)
  local hash = hashkey(key)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.hmac_hash (key, text, hex)
  local hash = hmac_hash(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.hmac64 (key, text, hex)
  local hash = hmac64(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.hmac64_md5 (key, text, hex)
  local hash = hmac64_md5(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_128_cbc_encrypt(key, text, iv, hex)
  local hash = aes_cbc_encrypt(16, key, text, (type(iv) == 'string' and #iv == 16) and iv or "")
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_128_ecb_encrypt(key, text, iv, hex)
  local hash = aes_ecb_encrypt(16, key, text, (type(iv) == 'string' and #iv == 16) and iv or "")
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_128_cbc_decrypt(key, text, iv)
  return aes_cbc_decrypt(16, key, text, (type(iv) == 'string' and #iv == 16) and iv or "")
end

function crypt.aes_128_ecb_decrypt(key, text, iv)
  return aes_ecb_decrypt(16, key, text, (type(iv) == 'string' and #iv == 16) and iv or "")
end

function crypt.base64urlencode(data)
  return base64encode(data):gsub('+', '-'):gsub('/', '_')
end

function crypt.base64urldecode(data)
  return base64decode(data:gsub('-', '+'):gsub('_', '/'))
end

function crypt.base64encode (...)
  return base64encode(...)
end

function crypt.base64decode (...)
  return base64decode(...)
end

function crypt.hexencode (...)
  return hexencode(...)
end

function crypt.hexdecode (...)
  return hexdecode(...)
end

function crypt.desencode (key, text, hex)
  local hash = desencode(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.desdecode (key, text, hex)
  if hex then
    text = hexdecode(text)
  end
  return desdecode(key, text)
end

function crypt.dhsecret (...)
  return dhsecret(...)
end

function crypt.dhexchange (...)
  return dhexchange(...)
end

function crypt.crc32 (...)
  return crc32(...)
end

function crypt.crc64 (...)
  return crc64(...)
end

function crypt.urldecode (...)
  return urldecode(...)
end

function crypt.urlencode (...)
  return urlencode(...)
end

-- text 为原始文本内容, public_key_path 为公钥路径, b64 为是否为结果进行base64编码
function crypt.rsa_public_key_encode(text, public_key_path, b64)
  local hash = rsa_public_key_encode(text, public_key_path)
  if hash and b64 then
    return base64encode(hash)
  end
  return hash
end

-- text 为加密后的内容, private_key_path 为私钥路径, b64 为是否为text先进行base64解码
function crypt.rsa_private_key_decode(text, private_key_path, b64)
  return rsa_private_key_decode(b64 and base64decode(text) or text, private_key_path)
end

-- text 为原始文本内容, private_key_path 为公钥路径, b64 为是否为结果进行base64编码
function crypt.rsa_private_key_encode(text, private_key_path, b64)
  local hash = rsa_private_key_encode(text, private_key_path)
  if hash and b64 then
    return base64encode(hash)
  end
  return hash
end

-- text 为加密后的内容, public_key_path 为公钥路径, b64 为是否为text先进行base64解码
function crypt.rsa_public_key_decode(text, public_key_path, b64)
  return rsa_public_key_decode(b64 and base64decode(text) or text, public_key_path)
end


-- sha with rsa sign/verify
function crypt.sha128_with_rsa_sign(text, private_key_path, hex)
  local hash = sha128WithRsa_sign(text, private_key_path)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.sha128_with_rsa_verify(text, public_key_path, sign, hex)
  if hex and sign then
    sign = hexdecode(sign)
  end
  return sha128WithRsa_verify(text, public_key_path, sign)
end

function crypt.sha256_with_rsa_sign(text, private_key_path, hex)
  local hash = sha256WithRsa_sign(text, private_key_path)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.sha256_with_rsa_verify(text, public_key_path, sign, hex)
  if hex and sign then
    sign = hexdecode(sign)
  end
  return sha256WithRsa_verify(text, public_key_path, sign)
end

return crypt
