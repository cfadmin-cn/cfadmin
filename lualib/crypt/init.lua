local CRYPT = require "lcrypt"
local new_tab = require("sys").new_tab

local fmt = string.format
local byte = string.byte
local match = string.match
local concat = table.concat

local md5 = CRYPT.md5
local hmac64 = CRYPT.hmac64
local hmac_md5 = CRYPT.hmac_md5
local hmac64_md5 = CRYPT.hmac64_md5

local sha1 = CRYPT.sha1
local sha256 = CRYPT.sha256
local sha512 = CRYPT.sha512

local hmac_sha1 = CRYPT.hmac_sha1
local hmac_sha256 = CRYPT.hmac_sha256
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


local crypt = {}

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

function crypt.sha256 (str, hex)
  local hash = sha256(str)
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

function crypt.hmac_sha256 (key, text, hex)
  local hash = hmac_sha256(key, text)
  if hash and hex then
    return hexencode(hash)
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

function crypt.xor_str (str, sec, hex)
  local hash = xor_str(str, sec)
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

function crypt.base64encode (...)
  return base64encode(...)
end

function crypt.base64decode (...)
  return base64decode(...)
end

function crypt.base64urlencode(data)
  return base64encode(data):gsub('+', '-'):gsub('/', '_')
end

function crypt.base64urldecode(data)
  return base64decode(data:gsub('-', '+'):gsub('_', '/'))
end

function crypt.hexencode (...)
  return hexencode(...)
end

function crypt.hexdecode (...)
  return hexdecode(...)
end

function crypt.desencode (...)
  return desencode(...)
end

function crypt.desdecode (...)
  return desdecode(...)
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

return crypt
