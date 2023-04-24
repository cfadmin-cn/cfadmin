local json = require "json"
local json_encode = json.encode

local crypt = require "crypt"
local hashkey = crypt.hashkey
local desencode = crypt.desencode
local desdecode = crypt.desdecode
local hmac_sha256 = crypt.hmac_sha256
local hmac_sha384 = crypt.hmac_sha384
local hmac_sha512 = crypt.hmac_sha512
local base64urlencode = crypt.base64urlencode
local base64urldecode = crypt.base64urldecode

local type = type
local pcall = pcall
local assert = assert

local match = string.match

local concat = table.concat

-- 支持的签名算法
local algorithms = { HS256 = hmac_sha256, HS384 = hmac_sha384, HS512 = hmac_sha512 }

-- 签名算法
local function sign(secret, text, algorithm)
  return (algorithms[algorithm] or hmac_sha256)(secret, text)
end

---comment 使用`encode`编码, 使用`decode`解码
local jwt = { version = 0.1, algorithms = { HS256 = "HS256", HS384 = "HS384", HS512 = "HS512" } }

---comment jwt 序列化
---@param text string      @字符串类型的数据载荷
---@param secret string    @HASH摘要签名与对称加密使用的秘钥
---@param algorithm string @指定签名算法: [`HS256`, `HS384`, `HS512`]
---@return string | nil    @符合规范的json web token字符串或者nil
---@return string?         @出错后的错误信息
function jwt.encode(text, secret, algorithm)
  assert(type(text) == 'string' and text ~= '' and type(secret) == 'string' and secret ~= '', "Invalid json web token encode parameter.")
  -- HEADER
  local ok, header = pcall(json_encode, { alg = jwt.algorithms[algorithm] or "HS256", typ = "JWT" })
  if not ok then
    return nil, header
  end
  header = base64urlencode(header)
  -- PAYLOAD
  local payload = base64urlencode(desencode(hashkey(secret), text))
  -- SIGNATURE
  local signature = base64urlencode(sign(hashkey(secret), concat({header, payload}, "."), algorithm))
  return concat({header, payload, signature}, ".")
end

---comment jwt 反序列化
---@param token string     @待序列化的合法json web token字符串
---@param secret string    @摘要签名与对称解密使用的秘钥
---@param algorithm string @指定签名算法: [`HS256`, `HS384`, `HS512`]
---@return string | nil    @编码前的数据载荷或nil
---@return string?         @出错后的错误信息
function jwt.decode(token, secret, algorithm)
  assert(type(token) == 'string' and token ~= '' and type(secret) == 'string' and secret ~= '', "Invalid json web token decode parameter.")
  local header, payload, signature = match(token or "", "([^.]+)%.([^.]+)%.([^.]+)")
  if not header or not payload or not signature then
    return nil, "Invalid json web token format."
  end
  if base64urlencode(sign(hashkey(secret), concat({header, payload}, "."), algorithm)) ~= signature then
    return nil, "Invalid json web token signature."
  end
  -- base64解码
  local debase_ok, info = pcall(base64urldecode, payload)
  if not debase_ok then
    return nil, info
  end
  -- des对称解密
  local decode_ok, rawpayload = pcall(desdecode, hashkey(secret), info)
  if not decode_ok then
    return nil, rawpayload
  end
  return rawpayload
end

return jwt