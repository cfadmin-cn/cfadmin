local crypt = require "crypt"
local Log = require("logging"):new()

-- 测试crc32编码
Log:DEBUG("测试crc32",crypt.crc32("admin"))
-- 测试crc64编码
Log:DEBUG("测试crc64", crypt.crc64("admin"))

-- 测试md5编码
Log:DEBUG("测试md5", crypt.md5("admin", true))

-- 测试sha1编码, 第二个参数表示进行hex
Log:DEBUG("测试sha1", crypt.sha1("admin", true))

-- 测试sha256编码, 第二个参数表示进行hex
Log:DEBUG("测试sha256", crypt.sha256("admin", true))

-- 测试sha512编码
Log:DEBUG("测试sha512", crypt.sha512("admin", true))

-- 测试hmac_sha1编码, 第二个参数表示进行hex
Log:DEBUG("测试hmac_sha1", crypt.hmac_sha1("admin", "123", true))

-- 测试hmac_sha256编码, 第二个参数表示进行hex
Log:DEBUG("测试hmac_sha256", crypt.hmac_sha256("admin", "123", true))

-- 测试hmac_sha512编码, 第二个参数表示进行hex
Log:DEBUG("测试hmac_sha512", crypt.hmac_sha512("admin", "123", true))

-- 测试hmac_md5编码
Log:DEBUG("测试hmac_md5", crypt.hmac_md5("admin", "123", true))

-- 测试hmac64编码
Log:DEBUG("测试hmac64", crypt.hmac64("12345678", "abcdefgh", true))

-- 测试hmac64_md5编码
Log:DEBUG("测试hmac64_md5", crypt.hmac64_md5("12345678", "abcdefgh", true))

-- 测试hmac_hash编码
Log:DEBUG("测试hmac_hash", crypt.hmac_hash("12345678", "abcdefgh", true))

-- 测试randomkey编码
Log:DEBUG("测试randomkey", crypt.randomkey(true))

-- 测试hashkey编码
Log:DEBUG("测试hashkey", crypt.hashkey("admin", true))

-- 测试desencode编码
Log:DEBUG("测试desencode", crypt.desencode("12345678", "87654321"))
-- 测试desdecode编码
Log:DEBUG("测试desdecode", crypt.desdecode("12345678", crypt.desencode("12345678", "87654321")) == "87654321")

-- 测试hexencode编码
Log:DEBUG("测试hexencode", crypt.hexencode("1234567890"), crypt.hexencode("1234567890") == "31323334353637383930")
-- 测试hexdecode编码
Log:DEBUG("测试hexdecode", crypt.hexdecode("31323334353637383930"), crypt.hexdecode("31323334353637383930") == "1234567890")

-- 测试base64encode编码
Log:DEBUG("测试base64encode", crypt.base64encode("1234567890"), crypt.base64encode("1234567890") == "MTIzNDU2Nzg5MA==")
-- 测试base64decode编码
Log:DEBUG("测试base64decode", crypt.base64decode("MTIzNDU2Nzg5MA=="), crypt.base64decode("MTIzNDU2Nzg5MA==") == "1234567890")

-- 测试str_xor编码, 2次xor将还原.
Log:DEBUG("测试str_xor", crypt.xor_str("1234567890", "123", true), crypt.xor_str(crypt.xor_str("1234567890", "123"), "123") == "1234567890")
