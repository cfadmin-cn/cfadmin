local CRYPT = require "lcrypt"

local crypt = {
  -- HEX编码/解码
  hexencode = CRYPT.hexencode,
  hexdecode = CRYPT.hexdecode,
  -- URL编码/解码
  urlencode = CRYPT.urlencode,
  urldecode = CRYPT.urldecode,
}

-- UUID与GUID
require "crypt.id"(crypt)

-- 安全哈希与摘要算法
require "crypt.sha"(crypt)

-- 哈希消息认证码算法
require "crypt.hmac"(crypt)

-- 循环冗余校验算法
require "crypt.crc"(crypt)

-- Base64编码/解码算法
require "crypt.b64"(crypt)

-- RC4算法
require "crypt.rc4"(crypt)

-- AES对称加密算法
require "crypt.aes"(crypt)

-- DES对称加密算法
require "crypt.des"(crypt)

-- 密钥交换算法
require "crypt.dh"(crypt)

-- 商用国密算法
require "crypt.sm"(crypt)

-- 非对称加密算法
require "crypt.rsa"(crypt)

-- 一些特殊算法
require "crypt.utils"(crypt)

return crypt