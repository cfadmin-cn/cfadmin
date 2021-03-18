local CRYPT = require "lcrypt"
local desencode = CRYPT.desencode
local desdecode = CRYPT.desdecode
local des_encrypt = CRYPT.des_encrypt
local des_decrypt = CRYPT.des_decrypt
local base64encode = CRYPT.base64encode
local base64decode = CRYPT.base64decode
local hexdecode = CRYPT.hexdecode
local hexencode = CRYPT.hexencode

local DES = {}

function DES.desencode (key, text, hex)
  local hash = desencode(key, text)
  if hash and hex then
    return hexencode(hash)
  end
  return hash
end

function DES.desdecode (key, text, hex)
  if hex then
    text = hexdecode(text)
  end
  return desdecode(key, text)
end

function DES.desx_encrypt(key, text, iv, b64)
  local hash = des_encrypt(0, key, text, iv)
  if b64 then
    hash = base64encode(hash)
  end
  return hash
end

function DES.desx_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64decode(cipher)
  end
  return des_decrypt(0, key, cipher, iv)
end

function DES.desx_cbc_encrypt(key, text, iv, b64)
  return DES.desx_encrypt(key, text, iv, b64)
end

function DES.desx_cbc_decrypt(key, cipher, iv, b64)
  return DES.desx_decrypt(key, cipher, iv, b64)
end

function DES.des_cbc_encrypt(key, text, iv, b64)
  local hash = des_encrypt(1, key, text, iv)
  if b64 then
    hash = base64encode(hash)
  end
  return hash
end

function DES.des_cbc_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64encode(cipher)
  end
  return des_decrypt(1, key, cipher, iv)
end

function DES.des_ecb_encrypt(key, text, iv, b64)
  local hash = des_encrypt(2, key, text, iv)
  if b64 then
    hash = base64encode(hash)
  end
  return hash
end

function DES.des_ecb_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64encode(cipher)
  end
  return des_decrypt(2, key, cipher, iv)
end

function DES.des_cfb_encrypt(key, text, iv, b64)
  local hash = des_encrypt(3, key, text, iv)
  if b64 then
    hash = base64encode(hash)
  end
  return hash
end

function DES.des_cfb_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64encode(cipher)
  end
  return des_decrypt(3, key, cipher, iv)
end

function DES.des_ofb_encrypt(key, text, iv, b64)
  local hash = des_encrypt(4, key, text, iv)
  if b64 then
    hash = base64encode(hash)
  end
  return hash
end

function DES.des_ofb_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64encode(cipher)
  end
  return des_decrypt(4, key, cipher, iv)
end

function DES.des_ede_encrypt(key, text, iv, b64)
  local hash = des_encrypt(5, key, text, iv)
  if b64 then
    hash = base64encode(hash)
  end
  return hash
end

function DES.des_ede_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64encode(cipher)
  end
  return des_decrypt(5, key, cipher, iv)
end

function DES.des_ede3_encrypt(key, text, iv, b64)
  local hash = des_encrypt(6, key, text, iv)
  if b64 then
    hash = base64encode(hash)
  end
  return hash
end

function DES.des_ede3_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64encode(cipher)
  end
  return des_decrypt(6, key, cipher, iv)
end

function DES.des_ede_ecb_encrypt(key, text, iv, b64)
  local hash = des_encrypt(7, key, text, iv)
  if b64 then
    hash = base64encode(hash)
  end
  return hash
end

function DES.des_ede_ecb_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64encode(cipher)
  end
  return des_decrypt(7, key, cipher, iv)
end

function DES.des_ede3_ecb_encrypt(key, text, iv, b64)
  local hash = des_encrypt(8, key, text, iv)
  if b64 then
    hash = base64encode(hash)
  end
  return hash
end

function DES.des_ede3_ecb_decrypt(key, cipher, iv, b64)
  if b64 then
    cipher = base64encode(cipher)
  end
  return des_decrypt(8, key, cipher, iv)
end

-- 初始化函数
return function (t)
  for k, v in pairs(DES) do
    t[k] = v
  end
  return DES
end