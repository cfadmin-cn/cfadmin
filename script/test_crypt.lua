local crypt = require "crypt"
local Log = require "logging"

local function test_hex()
  print("----------*** 开始测试 HEXENCODE/HEXDECODE ***----------")

  -- 测试hexencode编码
  Log:DEBUG("测试hexencode", crypt.hexencode("1234567890"), crypt.hexencode("1234567890") == "31323334353637383930")
  -- 测试hexdecode编码
  Log:DEBUG("测试hexdecode", crypt.hexdecode("31323334353637383930"), crypt.hexdecode("31323334353637383930") == "1234567890")

  print("----------*** 开始测试 HEXENCODE/HEXDECODE ***----------\n")
end


local function test_crc()
  print("----------*** 开始测试CRC32/CRC64 ***----------")

  -- 测试crc32编码
  Log:DEBUG("测试crc32",crypt.crc32("admin"))
  -- 测试crc64编码
  Log:DEBUG("测试crc64", crypt.crc64("admin"))

  print("----------*** CRC32/CRC64 测试完毕 ***----------\n")
end


local function test_url( ... )
  print("----------*** 开始测试 urlencode/urldecode ***----------")

  local url = "https://www.baiud.com/我是谁/api?name=水果糖的小铺子&age=30"

  Log:DEBUG("测试urlencode: " .. crypt.urlencode(url))

  Log:DEBUG("测试urlencode: " .. crypt.urldecode(crypt.urlencode(url)))

  assert(crypt.urldecode(crypt.urlencode(url)) == url, "测试失败")

  print("----------*** urlencode/urldecode 测试完毕 ***----------\n")
end

local function test_sha()

  print("----------*** 开始测试MD5/SHA128/SHA256/SHA512 ***----------")

  local text = "123456789admin"

  Log:DEBUG("测试md5 :" .. crypt.md5(text, true))
  assert(crypt.md5(text, true) == "dce70093fd997b5e1a37c86dadaf0a48", "MD5测试失败")

  Log:DEBUG("测试sha128 :" .. crypt.sha1(text, true))
  assert(crypt.sha1(text, true) == "1e2f566cbda0a9c855240bf21b8bae030404cad7", "SHA128测试失败")

  Log:DEBUG("测试sha224 :" .. crypt.sha224(text, true))
  assert(crypt.sha224(text, true) == "47e386607ca91384c4ccca3dfd3da211aaf618b7a043bac2aa138495", "SHA224测试失败")

  Log:DEBUG("测试sha256 :" .. crypt.sha256(text, true))
  assert(crypt.sha256(text, true) == "e39594b63146c3f089bc12e1421cb3fe2fb9e4925908a995989e635d9bd1b096", "SHA256测试失败")

  Log:DEBUG("测试sha384 :" .. crypt.sha384(text, true))
  assert(crypt.sha384(text, true) == "18f26760edbc390cd61834e3100fbf88a14f2fe7b4dfdb11d2d5aea92388274163d5f4ae0cd9662b8a88e148d3b358f4", "SHA384测试失败")

  Log:DEBUG("测试sha512 :" .. crypt.sha512(text, true))
  assert(crypt.sha512(text, true) == "434042f8e8a262ffa53cb2ac1366aa4647c66464e9db8442338f0398cf400d7f966b360f0d12f1670fba01f2a0e900a3295143162ec5a215cf2d6b321294d02e", "SHA512测试失败")

  print("----------*** MD5/SHA128/SHA256/SHA512 测试完毕 ***----------\n")
end

local function test_hmac()

  print("----------*** 开始测试HMAC(MD5/SHA128/SHA256/SHA512) ***----------")

  local text = "123456789admin"
  local key = "admin"

  Log:DEBUG("hmac_md5 :" .. crypt.hmac_md5(key, text, true))
  assert(crypt.hmac_md5(key, text, true) == "fbe0f8e2cfb44139cfdf7162d6b9e709", "HMAC_MD5测试失败")

  Log:DEBUG("hmac_sha128 :" .. crypt.hmac_sha1(key, text, true))
  assert(crypt.hmac_sha1(key, text, true) == "197c3254b4c935717b7d7ca38fbdb642d22a63f9", "HMAC_SHA128测试失败")

  Log:DEBUG("hmac_sha256 :" .. crypt.hmac_sha256(key, text, true))
  assert(crypt.hmac_sha256(key, text, true) == "824902bf7fc037243b6cf0444a4887d21779526b0937b9f76b8ac23dafa0eb45", "HMAC_SHA256测试失败")

  Log:DEBUG("hmac_sha512 :" .. crypt.hmac_sha512(key, text, true))
  assert(crypt.hmac_sha512(key, text, true) == "346b81fb7771816ad1206d996de063859e8225d09a74776ded859d1e3e388b34aae09636c5c60b2ad7d88f5518483cc3d952753573b856aab4b96531a3cb4094", "HMAC_SHA512测试失败")

    -- 测试hmac64编码
  Log:DEBUG("hmac64", crypt.hmac64("12345678", "abcdefgh", true))

  -- 测试hmac64_md5编码
  Log:DEBUG("hmac64_md5", crypt.hmac64_md5("12345678", "abcdefgh", true))

  -- 测试hmac_hash编码
  Log:DEBUG("hmac_hash", crypt.hmac_hash("12345678", "abcdefgh", true))

  print("----------*** HMAC(MD5/SHA128/SHA256/SHA512) 测试完毕 ***----------\n")

end

local function test_des( ... )

  print("----------*** 开始测试 desencode/desdecode ***----------")

  local text = [[{"code":200,"data":[1,2,3,4,5,6,7,8,9,10]}]]

  local key = "12345678"

  -- 测试desencode编码
  Log:DEBUG("测试desencode", crypt.desencode(key, text, true))
  -- 测试desdecode编码
  Log:DEBUG("测试desdecode", crypt.desdecode(key, crypt.desencode(key, text)) == text)

  print("----------*** desencode/desdecode 测试完毕 ***----------\n")


end

local function test_other( ... )
  print("----------*** 开始测试 hashkey/randomkey ***----------")
  -- 测试randomkey编码
  Log:DEBUG("测试randomkey", crypt.randomkey(true))

  -- 测试hashkey编码
  Log:DEBUG("测试hashkey", crypt.hashkey("admin", true))

  print("----------*** hashkey/randomkey 测试完毕 ***----------\n")
end


local function test_xor_str( ... )

  print("----------*** 开始测试 xor_str ***----------")
  
  local rawData = "admin00000"
  local key = "1234567890-----"

  local xor = crypt.xor_str(rawData, key)

  local raw = crypt.xor_str(xor, key)

  assert(raw == rawData, "转换失败")

  Log:DEBUG( "xor data = " .. crypt.hexencode(xor), "raw data = " .. raw)

  print("----------*** xor_str 测试完成 ***----------\n")

end

local function test_b64()

  print("----------*** 开始测试 base64 ***----------")

  local rawData = "123456789"

  Log:DEBUG("测试base64:" ..  crypt.base64encode(rawData), "原始数据为:" .. rawData)

  assert(rawData == crypt.base64decode(crypt.base64encode(rawData)))

  print("----------*** base64 测试完毕 ***----------\n")

end

local function test_aes()

  print("----------*** 开始测试 aes_cbc/aes_ecb ***----------")
  
  local text = [[{"code":200,"msg":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]}]]
  local key_128 = "abcdefghabcdefgh"
  local iv = "98765432100admin"

  local function test_aes_128_bit()
    -- ECB
    local ecb_encryptData = crypt.aes_128_ecb_encrypt(key_128, text, iv)
    local ecb_rawData = crypt.aes_128_ecb_decrypt(key_128, ecb_encryptData, iv)
    Log:DEBUG("测试aes_128_ecb_encrypt: " .. crypt.hexencode(ecb_encryptData))
    assert(ecb_rawData == text, "aes加密/解密失败")

    -- CBC
    local cbc_encryptData = crypt.aes_128_cbc_encrypt(key_128, text, iv)
    local cbc_rawData = crypt.aes_128_cbc_decrypt(key_128, cbc_encryptData, iv)
    Log:DEBUG("测试aes_128_cbc_encrypt: " .. crypt.hexencode(cbc_encryptData))
    assert(cbc_rawData == text, "aes加密/解密失败")
  end


  local function test_aes_192_bit()
    key_192 = "abcdefghabcdefghabcdefgh"
    -- ECB
    local ecb_encryptData = crypt.aes_192_ecb_encrypt(key_192, text, iv)
    local ecb_rawData = crypt.aes_192_ecb_decrypt(key_192, ecb_encryptData, iv)
    Log:DEBUG("测试aes_192_ecb_encrypt: " .. crypt.hexencode(ecb_encryptData))
    assert(ecb_rawData == text, "aes加密/解密失败")

    -- CBC
    local cbc_encryptData = crypt.aes_192_cbc_encrypt(key_192, text, iv)
    local cbc_rawData = crypt.aes_192_cbc_decrypt(key_192, cbc_encryptData, iv)
    Log:DEBUG("测试aes_192_cbc_encrypt: " .. crypt.hexencode(cbc_encryptData))
    assert(cbc_rawData == text, "aes加密/解密失败")
  end

  local function test_aes_256_bit()
    key_256 = "abcdefghabcdefghabcdefghabcdefgh"
    -- ECB
    local ecb_encryptData = crypt.aes_256_ecb_encrypt(key_256, text, iv)
    local ecb_rawData = crypt.aes_256_ecb_decrypt(key_256, ecb_encryptData, iv)
    Log:DEBUG("测试aes_256_ecb_encrypt: " .. crypt.hexencode(ecb_encryptData))
    assert(ecb_rawData == text, "aes加密/解密失败")

    -- CBC
    local cbc_encryptData = crypt.aes_256_cbc_encrypt(key_256, text, iv)
    local cbc_rawData = crypt.aes_256_cbc_decrypt(key_256, cbc_encryptData, iv)
    Log:DEBUG("测试aes_256_cbc_encrypt: " .. crypt.hexencode(cbc_encryptData))
    assert(cbc_rawData == text, "aes加密/解密失败")
  end

  test_aes_128_bit()

  test_aes_192_bit()

  test_aes_256_bit()

  print("----------*** aes_cbc/aes_ecb 测试完毕 ***----------\n")

end

local function test_rsa()


  local function test_rsa_1024 ( ... )
    -- 生成公钥/私钥方法:

    -- 1. 使用openssl命令生成1024位私钥: openssl genrsa -out private1024.pem 1024

    -- 2. 使用openssl命令根据1024位私钥生成公钥: openssl rsa -in private1024.pem -out public1024.pem -pubout

    local publick_key_path = "public1024.pem"
    local private_key_path = "private1024.pem"

    local text = [[{"code":200,"data":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,26,26,27,28,29,30,31,32,33,34,35]}]]

    local encData = crypt.rsa_public_key_encode(text, publick_key_path, true)
    -- print(encData)
    local decData = crypt.rsa_private_key_decode(encData, private_key_path, true)

    assert(decData == text, "rsa 1024 公钥加密 -> 私钥解密 失败." .. decData)


    local encData = crypt.rsa_private_key_encode(text, private_key_path, true)
    -- print(encData)
    local decData = crypt.rsa_public_key_decode(encData, publick_key_path, true)

    assert(decData == text, "rsa 1024 私钥加密 -> 公钥解密 失败.")

  end

  local function test_rsa_2048( ... )
      -- 生成公钥/私钥方法:

      -- 1. 使用openssl命令生成2048位私钥: openssl genrsa -out private2048.pem 2048

      -- 2. 使用openssl命令根据2048位私钥生成公钥: openssl rsa -in private2048.pem -out public2048.pem -pubout

      local publick_key_path = "public2048.pem"
      local private_key_path = "private2048.pem"

      local text = [[{"code":200,"data":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,26,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40]}]]

      local encData = crypt.rsa_public_key_encode(text, publick_key_path, true)
      -- print(encData)
      local decData = crypt.rsa_private_key_decode(encData, private_key_path, true)
      -- print(decData)
      assert(decData == text, "rsa 2048 公钥加密 -> 私钥解密 失败." .. decData)


      local encData = crypt.rsa_private_key_encode(text, private_key_path, true)
      -- print(encData)
      local decData = crypt.rsa_public_key_decode(encData, publick_key_path, true)
      -- print(decData)
      assert(decData == text, "rsa 2048 私钥加密 -> 公钥解密 失败.")

  end

  local function test_rsa_4096( ... )
      -- 生成公钥/私钥方法:

      -- 1. 使用openssl命令生成4096位私钥: openssl genrsa -out private4096.pem 4096

      -- 2. 使用openssl命令根据4096位私钥生成公钥: openssl rsa -in private4096.pem -out public4096.pem -pubout

      local publick_key_path = "public4096.pem"
      local private_key_path = "private4096.pem"

      local text = [[{"code":200,"data":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,26,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,]}]]

      local encData = crypt.rsa_public_key_encode(text, publick_key_path, true)
      -- print(encData)
      local decData = crypt.rsa_private_key_decode(encData, private_key_path, true)
      -- print(decData)
      assert(decData == text, "rsa 4096 公钥加密 -> 私钥解密 失败." .. decData)


      local encData = crypt.rsa_private_key_encode(text, private_key_path, true)
      -- print(encData)
      local decData = crypt.rsa_public_key_decode(encData, publick_key_path, true)
      -- print(decData)
      assert(decData == text, "rsa 4096 私钥加密 -> 公钥解密 失败.")

  end

  local function test_rsa_sign_and_rsa_verify(...)

    local text = [[{"code":200,"data":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,26,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40]}]]

    local public_1024 = "public1024.pem"
    local private_1024 = "private1024.pem"
    
    local public_2048 = "public2048.pem"
    local private_2048 = "private2048.pem"

    local public_4096 = "public4096.pem"
    local private_4096 = "private4096.pem"

    local hex = true -- 是结果hex输出

    local sign_1024 = crypt.rsa_sign(text, private_1024, "md5", hex)
    print("md5 with rsa: 1024", sign_1024, crypt.rsa_verify(text, public_1024, sign_1024, "md5", hex))
    local sign_1024 = crypt.rsa_sign(text, private_1024, "sha128", hex)
    print("sha128 with rsa: 1024", sign_1024, crypt.rsa_verify(text, public_1024, sign_1024, "sha128", hex))
    local sign_1024 = crypt.rsa_sign(text, private_1024, "sha256", hex)
    print("sha256 with rsa: 1024", sign_1024, crypt.rsa_verify(text, public_1024, sign_1024, "sha256", hex))
    local sign_1024 = crypt.rsa_sign(text, private_1024, "sha512", hex)
    print("sha512 with rsa: 1024, ", sign_1024, crypt.rsa_verify(text, public_1024, sign_1024, "sha512", hex))

    local sign_2048 = crypt.rsa_sign(text, private_2048, "md5", hex)
    print("md5 with rsa: 2048", sign_2048, crypt.rsa_verify(text, public_2048, sign_2048, "md5", hex))
    local sign_2048 = crypt.rsa_sign(text, private_2048, "sha128", hex)
    print("sha128 with rsa: 2048", sign_2048, crypt.rsa_verify(text, public_2048, sign_2048, "sha128", hex))
    local sign_2048 = crypt.rsa_sign(text, private_2048, "sha256", hex)
    print("sha256 with rsa: 2048", sign_2048, crypt.rsa_verify(text, public_2048, sign_2048, "sha256", hex))
    local sign_2048 = crypt.rsa_sign(text, private_2048, "sha512", hex)
    print("sha512 with rsa: 2048", sign_2048, crypt.rsa_verify(text, public_2048, sign_2048, "sha512", hex))


    local sign_4096 = crypt.rsa_sign(text, private_4096, "md5", hex)
    print("md5 with rsa: 4096", sign_4096, crypt.rsa_verify(text, public_4096, sign_4096, "md5", hex))
    local sign_4096 = crypt.rsa_sign(text, private_4096, "sha128", hex)
    print("sha128 with rsa: 4096", sign_4096, crypt.rsa_verify(text, public_4096, sign_4096, "sha128", hex))
    local sign_4096 = crypt.rsa_sign(text, private_4096, "sha256", hex)
    print("sha256 with rsa: 4096", sign_4096, crypt.rsa_verify(text, public_4096, sign_4096, "sha256", hex))
    local sign_4096 = crypt.rsa_sign(text, private_4096, "sha512", hex)
    print("sha512 with rsa: 4096", sign_4096, crypt.rsa_verify(text, public_4096, sign_4096, "sha512", hex))

  end

  print("----------*** 开始测试 rsa public/private encode/decode ***----------")

  test_rsa_1024()

  test_rsa_2048()

  test_rsa_4096()

  test_rsa_sign_and_rsa_verify()

  print("----------*** rsa public/private encode/decode 测试完成 ***----------\n")

end

local function test_uuid( ... )

  print("----------*** 开始测试 uuid 生成 ***----------")

  Log:DEBUG("生成的UUID为: " .. crypt.uuid())

  print("----------*** uuid 测试完成 ***----------\n")
end

local function main()

  local examples = {

    -- test_xor_str,

    -- test_hex,
   
    -- test_crc,

    -- test_url,

    -- test_b64,

    -- test_sha,

    -- test_hmac,

    -- test_des,
    
    -- test_strxor,

    -- test_aes,

    -- test_other,

    test_rsa,

    -- test_uuid,

  }

  for _, f in ipairs(examples) do

    f()

  end

  Log:DEBUG("总共完成了" .. #examples .. "个测试用例.")

end

main()