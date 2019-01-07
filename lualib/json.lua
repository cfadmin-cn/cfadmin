local cjson = require "cjson"
-- 让json默认解析收都用原表保存数据, 这也可以保证一个表的序列化与反序列化不会出现2种结果
-- cjson默认没有开启. 这里手动开启一下, 有需要的情况下K呀手动关闭
cjson.decode_array_with_array_mt(true)

local CJSON = {
    array_mt = cjson.array_mt,
}

-- table 转 json
function CJSON.encode(obj)
    return cjson.encode(obj)
end

-- json 转 table
function CJSON.decode(string)
    return cjson.decode(string)
end

-- 稀疏数组用null填充
function CJSON.sparse_array_to_null(array)
    return setmetatable(array, cjson.array_mt)
end

function CJSON.decode_array_with_array_mt(enable)
    return cjson.decode_array_with_array_mt(enable)
end

return CJSON