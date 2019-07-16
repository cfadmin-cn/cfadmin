local lmsgpack = require "lmsgpack.safe"
local lmsgpack_encode = lmsgpack.pack
local lmsgpack_decode = lmsgpack.unpack

local msgpack = {}

-- 序列化
function msgpack.encode (...)
  return lmsgpack_encode(...)
end

-- 反序列化
function msgpack.decode (...)
  return lmsgpack_decode(...)
end

-- 序列化
function msgpack.pack (...)
  return lmsgpack_encode(...)
end

-- 反序列化
function msgpack.unpack (...)
  return lmsgpack_decode(...)
end


return msgpack
