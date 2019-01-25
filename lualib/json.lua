local cjson = require "cjson"

-- this lib fork from resty cjson, only modified some compatible codes
-- more details please check it.
cjson.decode_array_with_array_mt(true)

local CJSON = {
    null = null,
    _VERSION = cjson._VERSION,
    encode = cjson.encode,
    decode = cjson.decode,
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

return CJSON