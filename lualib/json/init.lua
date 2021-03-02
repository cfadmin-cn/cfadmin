local cjson = require "cjson"

local setmetatable = setmetatable

local cjson_array_mt = cjson.array_mt

-- this lib fork from resty cjson, only modified some compatible codes
-- more details please check it.

cjson.decode_array_with_array_mt(true)

-- 默认允许稀疏数组
cjson.encode_sparse_array(true)

local json = {
    null = null,
    _VERSION = cjson._VERSION,
    array_mt = cjson_array_mt,
    empty_array = cjson.empty_array,
    empty_array_mt = cjson.empty_array_mt,
    encode_max_depth = cjson.encode_max_depth,
    encode_sparse_array = cjson.encode_sparse_array,
    decode_max_depth = cjson.decode_max_depth,
    decode_array_with_array_mt = cjson.decode_array_with_array_mt,
    encode_empty_table_as_object = cjson.encode_empty_table_as_object,
}

cjson = require "cjson.safe"
local cjson_encode = cjson.encode
local cjson_decode = cjson.decode

-- 设置稀疏数组用null填充
function json.sparse_array_to_null(array)
    return setmetatable(array, cjson_array_mt)
end

---comment json序列化
---@param tab table             @可序列化的`lua table`
---@return string               @合法的`json`字符串
function json.encode (tab)
  return cjson_encode(tab)
end

---comment json反序列化
---@param json string           @合法的json字符串
---@return table                @`lua table`
function json.decode (json)
  return cjson_decode(json)
end

return json
