local CRYPT = require "lcrypt"
local hmac64 = CRYPT.hmac64
local hmac_hash = CRYPT.hmac_hash
local hmac_md2 = CRYPT.hmac_md2
local hmac_md4 = CRYPT.hmac_md4
local hmac_md5 = CRYPT.hmac_md5
local hmac64_md5 = CRYPT.hmac64_md5

local hmac_sha1 = CRYPT.hmac_sha1
local hmac_sha224 = CRYPT.hmac_sha224
local hmac_sha256 = CRYPT.hmac_sha256
local hmac_sha384 = CRYPT.hmac_sha384
local hmac_sha512 = CRYPT.hmac_sha512
local hmac_ripemd160 = CRYPT.hmac_ripemd160
local hmac_pbkdf2 = CRYPT.hmac_pbkdf2

local hexencode = CRYPT.hexencode


local md_map = {
  md5    = CRYPT.EVP_md5,
  sha128 = CRYPT.EVP_sha128,
  sha224 = CRYPT.EVP_sha224,
  sha256 = CRYPT.EVP_sha256,
  sha384 = CRYPT.EVP_sha384,
  sha512 = CRYPT.EVP_sha512,
}

local HMAC = {}

function HMAC.hmac_pbkdf2(mdname, password, salt, iter, hex)
  local hash = hmac_pbkdf2(md_map[mdname], password, salt, iter)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function HMAC.hmac64(key, text, hex)
  local hash = hmac64(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function HMAC.hmac64_md5(key, text, hex)
  local hash = hmac64_md5(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function HMAC.hmac_hash(key, text, hex)
  local hash = hmac_hash(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function HMAC.hmac_md2(key, text, hex)
  local hash = hmac_md2(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function HMAC.hmac_md4(key, text, hex)
  local hash = hmac_md4(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function HMAC.hmac_md5(key, text, hex)
  local hash = hmac_md5(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function HMAC.hmac_sha1(key, text, hex)
  local hash = hmac_sha1(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function HMAC.hmac_sha128(key, text, hex)
  local hash = hmac_sha1(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function HMAC.hmac_sha224(key, text, hex)
  local hash = hmac_sha224(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function HMAC.hmac_sha256(key, text, hex)
  local hash = hmac_sha256(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function HMAC.hmac_sha384(key, text, hex)
  local hash = hmac_sha384(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function HMAC.hmac_sha512(key, text, hex)
  local hash = hmac_sha512(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function HMAC.hmac_ripemd(key, text, hex)
  local hash = hmac_ripemd160(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

-- 初始化函数
return function (t)
  for k, v in pairs(HMAC) do
    t[k] = v
  end
  return HMAC
end