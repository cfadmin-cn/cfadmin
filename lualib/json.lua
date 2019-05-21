local cjson = require "cjson"

local cjson_encode = cjson.encode
local cjson_decode = cjson.decode
local cjson_array_mt = cjson.array_mt

-- this lib fork from resty cjson, only modified some compatible codes
-- more details please check it.
cjson.decode_array_with_array_mt(true)

local CJSON = {
    null = null,
    _VERSION = cjson._VERSION,
    array_mt = cjson.array_mt,
    empty_array = cjson.empty_array,
    empty_array_mt = cjson.empty_array_mt,
    encode_max_depth = cjson.encode_max_depth,
    decode_max_depth = cjson.decode_max_depth,
    decode_array_with_array_mt = cjson.decode_array_with_array_mt,
    encode_empty_table_as_object = cjson.encode_empty_table_as_object,
}

-- 设置稀疏数组用null填充
function CJSON.sparse_array_to_null(array)
    return setmetatable(array, cjson.array_mt)
end

function CJSON.encode (...)
  local ok, data = pcall(cjson_encode, ...)
  if ok then
    return data
  end
end

function CJSON.decode (...)
  local ok, data = pcall(cjson_decode, ...)
  if ok then
    return data
  end
end

return CJSON
