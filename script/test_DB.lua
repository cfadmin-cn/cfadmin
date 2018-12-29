local DB = require "DB"
require "utils"

local ok = DB.init("mysql://localhost:3306/test", "root", "zhugeng")
if not ok then
    return print("连接mysql 失败")
end

-- 一个简单的DB插入示例
local ret, err = DB.insert("user",
    {  -- 要插入的表字段
        'name',
        'user',
        'passwd',
    },
    {  -- 要插入的数据(list)
        {'candy',  'admin', 'admin'},
        {'cf/0.1', 'root',  'zhugeng'}
    })
if not ret then
    return print(err)
end
var_dump(ret)

-- 一个简单的DB使用查询示例
local ret, err = DB.select(
    {
        'id', 'name', 'user', 'passwd'
    },                -- fields
    'user',           -- table
    {
        {"id", "=", "2"},
    },      -- conditions
    {"id"},    -- orderby
    "DESC", -- sort
    {0, 100}    -- limit
)

if not ret then
    return print(err)
end

var_dump(ret)


-- DB更新查询示例
local ret, err = DB.update('user',
    {
        {'name', '=', 'admin'},
        {'user', '=', 'root'},
        {'passwd', '=', 'admin'},
    },
    {
        {'id', '=', '2'},
        -- {'name', "in", {'root', 'admin'}} 
        -- {'name', "between", {'1', '100'}} 
    }
)
if not ret then
    return print(err)
end
var_dump(ret)
