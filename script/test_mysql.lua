-- 测试MySQL
local mysql = require "protocol.mysql"
local config = {
    host = "localhost",
    port = 3306,
    database = "mysql",
    user = "root",
    password = "123456789"
}

-- 创建->查询->销毁100次mysql连接
local times = 100
for i = 1, times do
    local db, err = mysql:new()
    if not db then
        return
    end
    local ok, err, errno, sqlstate = db:connect(config)
    if not ok then
        return print("连接失败.", i, err)
    end
    local resp, err = db:query("select * from user")
    if not resp then
        return print('查询失败', err)
    end
    db:close()
end
print("创建并销毁"..tostring(times).."次MySQL连接成功")


-- 保存mysql连接池 -> 销毁连接池
local pool = {}
for i = 1, times do
    local db, err = mysql:new()
    if not db then
        return
    end
    local ok, err, errno, sqlstate = db:connect(config)
    if not ok then
        return print("连接失败.", i, err)
    end
    local resp, err = db:query("select * from user")
    if not resp then
        return print('查询失败', err)
    end
    pool[#pool+1] = db
end
print('创建'..tostring(times)..'MySQL连接成功')
for _, db in ipairs(pool) do
    db:close()
end 
pool = nil
print('销毁MySQL连接')
print("测试完成")