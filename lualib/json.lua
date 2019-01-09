local cjson = require "cjson"

-- 让json默认解析收都用原表保存数据, 这也可以保证一个表的序列化与反序列化不会出现2种结果
-- cjson默认没有开启. 这里手动开启一下, 有需要的情况下可以手动关闭
cjson.decode_array_with_array_mt(true)

local CJSON = {
    null = null,
    encode = cjson.encode,
    decode = cjson.decode,
    _VERSION = cjson._VERSION,
    encode_max_depth = cjson.encode_max_depth,
    decode_max_depth = cjson.decode_max_depth,
    array_mt = cjson.array_mt,
    empty_array = cjson.empty_array,
    empty_array_mt = cjson.empty_array_mt,
}

-- 设置稀疏数组用null填充
function CJSON.sparse_array_to_null(array)
    return setmetatable(array, cjson.array_mt)
end

function CJSON.decode_array_with_array_mt(enable)
    return cjson.decode_array_with_array_mt(enable)
end

return CJSON
