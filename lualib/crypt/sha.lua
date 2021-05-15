local CRYPT = require "lcrypt"
local md2 = CRYPT.md2
local md4 = CRYPT.md4
local md5 = CRYPT.md5
local sha1 = CRYPT.sha1
local sha224 = CRYPT.sha224
local sha256 = CRYPT.sha256
local sha384 = CRYPT.sha384
local sha512 = CRYPT.sha512
local ripemd160 = CRYPT.ripemd160
local hexencode = CRYPT.hexencode

local SHA = {}

function SHA.md2(text, hex)
  local hash = md2(text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function SHA.md4(text, hex)
  local hash = md4(text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function SHA.md5(text, hex)
  local hash = md5(text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function SHA.sha1(text, hex)
  local hash = sha1(text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function SHA.sha128(text, hex)
  local hash = sha1(text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function SHA.sha224(text, hex)
  local hash = sha224(text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function SHA.sha256(text, hex)
  local hash = sha256(text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function SHA.sha384(text, hex)
  local hash = sha384(text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function SHA.sha512(text, hex)
  local hash = sha512(text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function SHA.ripemd(text, hex)
  local hash = ripemd160(text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

-- 初始化函数
return function (t)
  for k, v in pairs(SHA) do
    t[k] = v
  end
  return SHA
end