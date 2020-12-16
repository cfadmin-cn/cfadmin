local cjson = require "cjson"

local pcall = pcall
local setmetatable = setmetatable

local cjson_array_mt = cjson.array_mt

-- this lib fork from resty cjson, only modified some compatible codes
-- more details please check it.

cjson.decode_array_with_array_mt(true)

-- 默认允许稀疏数组
cjson.encode_sparse_array(true)

local CJSON = {
    null = null,
    _VERSION = cjson._VERSION,
    array_mt = cjson.array_mt,
    empty_array = cjson.empty_array,
    empty_array_mt = cjson.empty_array_mt,
    encode_max_depth = cjson.encode_max_depth,
    encode_sparse_array = cjson.encode_sparse_array,
    decode_max_depth = cjson.decode_max_depth,
    decode_array_with_array_mt = cjson.decode_array_with_array_mt,
    encode_empty_table_as_object = cjson.encode_empty_table_as_object,
}

local cjson = require "cjson.safe"
local cjson_encode = cjson.encode
local cjson_decode = cjson.decode

-- 设置稀疏数组用null填充
function CJSON.sparse_array_to_null(array)
    return setmetatable(array, cjson.array_mt)
end

-- json序列化
function CJSON.encode (...)
  return cjson_encode(...)
end

-- json反序列化
function CJSON.decode (...)
  return cjson_decode(...)
end

return CJSON
