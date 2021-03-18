local CRYPT = require "lcrypt"
local crc32 = CRYPT.crc32
local crc64 = CRYPT.crc64

local CRC = {}

function CRC.crc32(text)
  return crc32(text)
end

function CRC.crc64(text)
  return crc64(text)
end

-- 初始化函数
return function (t)
  for k, v in pairs(CRC) do
    t[k] = v
  end
  return CRC
end