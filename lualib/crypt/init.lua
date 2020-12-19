local CRYPT = require "lcrypt"

local sys = require "sys"
local now = sys.now
local hostname = sys.hostname
local modf = math.modf

local uuid = CRYPT.uuid
local guid = CRYPT.guid

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
local hmac_sha224 = CRYPT.hmac_sha224
local hmac_sha256 = CRYPT.hmac_sha256
local hmac_sha384 = CRYPT.hmac_sha384
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

local des_encrypt = CRYPT.des_encrypt
local des_decrypt = CRYPT.des_decrypt

local dhsecret = CRYPT.dhsecret
local dhexchange = CRYPT.dhexchange

local urlencode = CRYPT.urlencode
local urldecode = CRYPT.urldecode

local sm3 = CRYPT.sm3
local hmac_sm3 = CRYPT.hmac_sm3
local sm3 = CRYPT.sm3
local sm2keygen = CRYPT.sm2keygen
local sm2sign = CRYPT.sm2sign
local sm2verify = CRYPT.sm2verify

local sm4_cbc_encrypt = CRYPT.sm4_cbc_encrypt
local sm4_cbc_decrypt = CRYPT.sm4_cbc_decrypt

local sm4_ecb_encrypt = CRYPT.sm4_ecb_encrypt
local sm4_ecb_decrypt = CRYPT.sm4_ecb_decrypt

local sm4_ofb_encrypt = CRYPT.sm4_ofb_encrypt
local sm4_ofb_decrypt = CRYPT.sm4_ofb_decrypt

local sm4_ctr_encrypt = CRYPT.sm4_ctr_encrypt
local sm4_ctr_decrypt = CRYPT.sm4_ctr_decrypt

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

-- 填充方式
local RSA_NO_PADDING = CRYPT.RSA_NO_PADDING
local RSA_PKCS1_PADDING = CRYPT.RSA_PKCS1_PADDING
local RSA_PKCS1_OAEP_PADDING = CRYPT.RSA_PKCS1_OAEP_PADDING

local rsa_public_key_encode = CRYPT.rsa_public_key_encode
local rsa_private_key_decode = CRYPT.rsa_private_key_decode

local rsa_private_key_encode = CRYPT.rsa_private_key_encode
local rsa_public_key_decode = CRYPT.rsa_public_key_decode

-- 当前支持的签名与验签
local rsa_algorithms = {
  ["md5"]     =  CRYPT.nid_md5,
  ["sha1"]    =  CRYPT.nid_sha1,
  ["sha128"]  =  CRYPT.nid_sha1,
  ["sha256"]  =  CRYPT.nid_sha256,
  ["sha512"]  =  CRYPT.nid_sha512,
}

-- 当前支持的签名与验签方法
local rsa_sign = CRYPT.rsa_sign
local rsa_verify = CRYPT.rsa_verify

local crypt = {}

function crypt.uuid()
  return uuid()
end

-- hash(主机名)-时间戳-微秒-(1~65535的随机数)
function crypt.guid(host)
  local hi, lo = modf(now())
  return guid(host or hostname(), hi, lo * 1e4 // 1)
end

function crypt.sm3(str, hex)
  local hash = sm3(str)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.md5(str, hex)
  local hash = md5(str)
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

crypt.sha128 = crypt.sha1

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

-- 哈希信息摘要码方法(常见)

function crypt.hmac_md5 (key, text, hex)
  local hash = hmac_md5(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.hmac_sm3 (key, text, hex)
  local hash = hmac_sm3(key, text)
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

crypt.hmac_sha128 = crypt.hmac_sha1

function crypt.hmac_sha224(key, text, hex)
  local hash = hmac_sha224(key, text)
  if hex then
    hash = hexencode(hash)
  end
  return hash
end

function crypt.hmac_sha256 (key, text, hex)
  local hash = hmac_sha256(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.hmac_sha384(key, text, hex)
  local hash = hmac_sha384(key, text)
  if hex then
    hash = hexencode(hash)
  end
  return hash
end

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
  local hash = randomkey(8)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.randomkey_ex(byte, hex)
  local hash = randomkey(byte)
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

-- 哈希信息摘要码方法(特殊)

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

-- 高级对称分组解密方法

function crypt.aes_128_cbc_encrypt(key, text, iv, hex)
  local hash = aes_cbc_encrypt(16, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_128_ecb_encrypt(key, text, iv, hex)
  local hash = aes_ecb_encrypt(16, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_128_cfb_encrypt(key, text, iv, hex)
  local hash = aes_cfb_encrypt(16, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_128_ofb_encrypt(key, text, iv, hex)
  local hash = aes_ofb_encrypt(16, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_128_ctr_encrypt(key, text, iv, hex)
  local hash = aes_ctr_encrypt(16, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_128_gcm_encrypt(key, text, iv, hex)
  local hash = aes_gcm_encrypt(16, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_192_cbc_encrypt(key, text, iv, hex)
  local hash = aes_cbc_encrypt(24, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_192_ecb_encrypt(key, text, iv, hex)
  local hash = aes_ecb_encrypt(24, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_192_cfb_encrypt(key, text, iv, hex)
  local hash = aes_cfb_encrypt(24, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_192_ofb_encrypt(key, text, iv, hex)
  local hash = aes_ofb_encrypt(24, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_192_ctr_encrypt(key, text, iv, hex)
  local hash = aes_ctr_encrypt(24, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_192_gcm_encrypt(key, text, iv, hex)
  local hash = aes_gcm_encrypt(24, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_256_cbc_encrypt(key, text, iv, hex)
  local hash = aes_cbc_encrypt(32, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_256_ecb_encrypt(key, text, iv, hex)
  local hash = aes_ecb_encrypt(32, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_256_cfb_encrypt(key, text, iv, hex)
  local hash = aes_cfb_encrypt(32, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_256_ofb_encrypt(key, text, iv, hex)
  local hash = aes_ofb_encrypt(32, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_256_ctr_encrypt(key, text, iv, hex)
  local hash = aes_ctr_encrypt(32, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function crypt.aes_256_gcm_encrypt(key, text, iv, hex)
  local hash = aes_gcm_encrypt(32, key, text, iv)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

-- 高级对称分组解密方法

function crypt.aes_128_cbc_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_cbc_decrypt(16, key, cipher, iv)
end

function crypt.aes_128_ecb_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_ecb_decrypt(16, key, cipher, iv)
end

function crypt.aes_128_cfb_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_cfb_decrypt(16, key, cipher, iv)
end

function crypt.aes_128_ofb_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_ofb_decrypt(16, key, cipher, iv)
end

function crypt.aes_128_ctr_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_ctr_decrypt(16, key, cipher, iv)
end

function crypt.aes_128_gcm_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_gcm_decrypt(16, key, cipher, iv)
end

function crypt.aes_192_cbc_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_cbc_decrypt(24, key, cipher, iv)
end

function crypt.aes_192_ecb_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_ecb_decrypt(24, key, cipher, iv)
end

function crypt.aes_192_cfb_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_cfb_decrypt(24, key, cipher, iv)
end

function crypt.aes_192_ofb_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_ofb_decrypt(24, key, cipher, iv)
end

function crypt.aes_192_ctr_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_ctr_decrypt(24, key, cipher, iv)
end

function crypt.aes_192_gcm_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_gcm_decrypt(24, key, cipher, iv)
end

function crypt.aes_256_cbc_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_cbc_decrypt(32, key, cipher, iv)
end

function crypt.aes_256_ecb_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_ecb_decrypt(32, key, cipher, iv)
end

function crypt.aes_256_cfb_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_cfb_decrypt(32, key, cipher, iv)
end

function crypt.aes_256_ofb_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_ofb_decrypt(32, key, cipher, iv)
end

function crypt.aes_256_ctr_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_ctr_decrypt(32, key, cipher, iv)
end

function crypt.aes_256_gcm_decrypt(key, cipher, iv, hex)
  if hex then
    cipher = hexdecode(cipher)
  end
  return aes_gcm_decrypt(32, key, cipher, iv)
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

function crypt.desx_encrypt(key, text, iv, b64)
  local hash = des_encrypt(0, key, text, iv)
  if b64 then
    hash = base64encode(hash)
  end
  return hash
end

function crypt.desx_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64decode(cipher)
  end
  return des_decrypt(0, key, cipher, iv)
end

function crypt.desx_cbc_encrypt(key, text, iv, b64)
  return crypt.desx_encrypt(key, text, iv, b64)
end

function crypt.desx_cbc_decrypt(key, cipher, iv, b64)
  return crypt.desx_decrypt(key, cipher, iv, b64)
end

function crypt.des_cbc_encrypt(key, text, iv, b64)
  local hash = des_encrypt(1, key, text, iv)
  if b64 then
    hash = base64encode(hash)
  end
  return hash
end

function crypt.des_cbc_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64encode(cipher)
  end
  return des_decrypt(1, key, cipher, iv)
end

function crypt.des_ecb_encrypt(key, text, iv, b64)
  local hash = des_encrypt(2, key, text, iv)
  if b64 then
    hash = base64encode(hash)
  end
  return hash
end

function crypt.des_ecb_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64encode(cipher)
  end
  return des_decrypt(2, key, cipher, iv)
end

function crypt.des_cfb_encrypt(key, text, iv, b64)
  local hash = des_encrypt(3, key, text, iv)
  if b64 then
    hash = base64encode(hash)
  end
  return hash
end

function crypt.des_cfb_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64encode(cipher)
  end
  return des_decrypt(3, key, cipher, iv)
end

function crypt.des_ofb_encrypt(key, text, iv, b64)
  local hash = des_encrypt(4, key, text, iv)
  if b64 then
    hash = base64encode(hash)
  end
  return hash
end

function crypt.des_ofb_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64encode(cipher)
  end
  return des_decrypt(4, key, cipher, iv)
end

function crypt.des_ede_encrypt(key, text, iv, b64)
  local hash = des_encrypt(5, key, text, iv)
  if b64 then
    hash = base64encode(hash)
  end
  return hash
end

function crypt.des_ede_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64encode(cipher)
  end
  return des_decrypt(5, key, cipher, iv)
end

function crypt.des_ede3_encrypt(key, text, iv, b64)
  local hash = des_encrypt(6, key, text, iv)
  if b64 then
    hash = base64encode(hash)
  end
  return hash
end

function crypt.des_ede3_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64encode(cipher)
  end
  return des_decrypt(6, key, cipher, iv)
end

function crypt.des_ede_ecb_encrypt(key, text, iv, b64)
  local hash = des_encrypt(7, key, text, iv)
  if b64 then
    hash = base64encode(hash)
  end
  return hash
end

function crypt.des_ede_ecb_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64encode(cipher)
  end
  return des_decrypt(7, key, cipher, iv)
end

function crypt.des_ede3_ecb_encrypt(key, text, iv, b64)
  local hash = des_encrypt(8, key, text, iv)
  if b64 then
    hash = base64encode(hash)
  end
  return hash
end

function crypt.des_ede3_ecb_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64encode(cipher)
  end
  return des_decrypt(8, key, cipher, iv)
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
  local hash = rsa_public_key_encode(text, public_key_path, RSA_PKCS1_PADDING)
  if hash and b64 then
    return base64encode(hash)
  end
  return hash
end

function crypt.rsa_public_key_oaep_padding_encode(text, public_key_path, b64)
  local hash = rsa_public_key_encode(text, public_key_path, RSA_PKCS1_OAEP_PADDING)
  if hash and b64 then
    return base64encode(hash)
  end
  return hash
end

-- text 为加密后的内容, private_key_path 为私钥路径, b64 为是否为text先进行base64解码
function crypt.rsa_private_key_decode(text, private_key_path, b64)
  return rsa_private_key_decode(b64 and base64decode(text) or text, private_key_path, RSA_PKCS1_PADDING)
end

function crypt.rsa_private_key_oaep_padding_decode(text, private_key_path, b64)
  return rsa_private_key_decode(b64 and base64decode(text) or text, private_key_path, RSA_PKCS1_OAEP_PADDING)
end


-- text 为原始文本内容, private_key_path 为公钥路径, b64 为是否为结果进行base64编码
function crypt.rsa_private_key_encode(text, private_key_path, b64)
  local hash = rsa_private_key_encode(text, private_key_path, RSA_PKCS1_PADDING)
  if hash and b64 then
    return base64encode(hash)
  end
  return hash
end

function crypt.rsa_private_key_oaep_padding_encode(text, private_key_path, b64)
  local hash = rsa_private_key_encode(text, private_key_path, RSA_PKCS1_OAEP_PADDING)
  if hash and b64 then
    return base64encode(hash)
  end
  return hash
end

-- text 为加密后的内容, public_key_path 为公钥路径, b64 为是否为text先进行base64解码
function crypt.rsa_public_key_decode(text, public_key_path, b64)
  return rsa_public_key_decode(b64 and base64decode(text) or text, public_key_path, RSA_PKCS1_PADDING)
end

function crypt.rsa_public_key_oaep_padding_decode(text, public_key_path, b64)
  return rsa_public_key_decode(b64 and base64decode(text) or text, public_key_path, RSA_PKCS1_OAEP_PADDING)
end

-- RSA签名函数: 第一个参数是等待签名的明文, 第二个参数是私钥所在路径, 第三个参数是算法名称, 第四个参数决定是否以hex输出
function crypt.rsa_sign(text, private_key_path, algorithm, hex)
  local hash = rsa_sign(text, private_key_path, rsa_algorithms[(algorithm or ""):lower()] or rsa_algorithms["md5"])
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

-- RSA验签函数: 第一个参数是等待签名的明文, 第二个参数是私钥所在路径, 第三个参数为签名sign密文, 第四个参数是算法名称, 第五个参数决定是否对sign进行unhex
function crypt.rsa_verify(text, public_key_path, sign, algorithm, hex)
  if hex then
    sign = hexdecode(sign)
  end
  return rsa_verify(text, public_key_path, sign, rsa_algorithms[(algorithm or ""):lower()] or rsa_algorithms["md5"])
end

-- 生成SM2私钥、公钥
function crypt.sm2keygen(pri_path, pub_path)
  return sm2keygen(pri_path, pub_path)
end

-- SM3WithSM2签名
function crypt.sm2sign(pri_path, text, b64)
  local sign = sm2sign(pri_path, text)
  if b64 then
    sign = base64encode(sign)
  end
  return sign
end

-- SM3WithSM2验签
function crypt.sm2verify(pub_path, text, sign, b64)
  if b64 then
    sign = base64decode(sign)
  end
  return sm2verify(pub_path, text, sign)
end

-- SM4分组加密算法之CBC
function crypt.sm4_cbc_encrypt(key, text, iv, b64)
  local cipher = sm4_cbc_encrypt(key, text, iv)
  if b64 then
    cipher = base64encode(cipher)
  end
  return cipher
end

-- SM4分组加密算法之CBC
function crypt.sm4_cbc_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64decode(cipher)
  end
  return sm4_cbc_decrypt(key, cipher, iv)
end

-- SM4分组加密算法之ECB
function crypt.sm4_ecb_encrypt(key, text, iv, b64)
  local cipher = sm4_ecb_encrypt(key, text, iv)
  if b64 then
    cipher = base64encode(cipher)
  end
  return cipher
end

-- SM4分组解密算法之ECB
function crypt.sm4_ecb_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64decode(cipher)
  end
  return sm4_ecb_decrypt(key, cipher, iv)
end

-- SM4分组加密算法之OFB
function crypt.sm4_ofb_encrypt(key, text, iv, b64)
  local cipher = sm4_ofb_encrypt(key, text, iv)
  if b64 then
    cipher = base64encode(cipher)
  end
  return cipher
end

-- SM4分组解密算法之OFB
function crypt.sm4_ofb_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64decode(cipher)
  end
  return sm4_ofb_decrypt(key, cipher, iv)
end

-- SM4分组加密算法之CTR
function crypt.sm4_ctr_encrypt(key, text, iv, b64)
  local cipher = sm4_ctr_encrypt(key, text, iv)
  if b64 then
    cipher = base64encode(cipher)
  end
  return cipher
end

-- SM4分组解密算法之CTR
function crypt.sm4_ctr_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64decode(cipher)
  end
  return sm4_ctr_decrypt(key, cipher, iv)
end

return crypt