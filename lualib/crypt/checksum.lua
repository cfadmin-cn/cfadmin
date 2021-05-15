local CRYPT = require "lcrypt"
local crc32 = CRYPT.crc32
local crc64 = CRYPT.crc64
local adler32 = CRYPT.adler32

local CHECKSUM = {}

function CHECKSUM.crc32(text)
  return crc32(text)
end

function CHECKSUM.crc64(text)
  return crc64(text)
end

function CHECKSUM.adler32(text)
  return adler32(text)
end

-- 初始化函数
return function (t)
  for k, v in pairs(CHECKSUM) do
    t[k] = v
  end
  return CHECKSUM
end