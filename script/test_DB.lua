local DB = require "DB"
local co = require "internal.Co"
require "utils"

local ok, err = DB.init({
    host = "localhost",
    port = 3306,
    database = "test",
    user = "root",
    password = "123456789"
    })
if not ok then
    return print("连接mysql 失败: "..err)
end

--[[
    复制下面语句到任意管理工具即可导入测试表进行测试

    SET NAMES utf8;
    SET FOREIGN_KEY_CHECKS = 0;

    -- ----------------------------
    --  Table structure for `user`
    -- ----------------------------
    DROP TABLE IF EXISTS `user`;
    CREATE TABLE `user` (
      `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
      `name` varchar(255) NOT NULL,
      `user` varchar(255) NOT NULL,
      `passwd` varchar(255) NOT NULL,
      PRIMARY KEY (`id`)
    ) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4;

    SET FOREIGN_KEY_CHECKS = 1;

--]]

-- 插入语句示例
co.spwan(function ( ... )
    local ret, err = DB.insert("user")
        :fields({"name", "user", "passwd"})
        :values({
            {"candy", "root", "123456789"},
            {"水果糖", "admin", "123456789"},
        })
        :execute()

    if not ret then
       return  print(err)
    end

    var_dump(ret)
end)

-- 查询语句示例
co.spwan(function ( ... )
    local ret, err = DB.select({"id", "name", "user", "passwd"})
        :from({"user"})
        :where({
            {"id", "!=", "0"},
            "AND",
            {"id", ">=", "1"},
            "OR",
            {"user", "!=", "admin"},
            "AND",
            {"user", "=", "admin"},
            "OR",
            {"user", "IS", "NOT", "NULL"},
            "AND",
            {"user", "IS", "NULL"},
            "AND",
            {"user", "IN", {1, 2, 3, 4, 5}},
            "AND",
            {"user", "NOT", "IN", {1, 2, 3, 4, 5}},
            "AND",
            {"user", "BETWEEN", {1, 100}},
            "AND",
            {"user", "NOT", "BETWEEN", {1, 100}},
        })
        :groupby('id')      -- groupby({"name", "user"})
        :orderby("id")      -- orderby({"name", "user"})
        :asc()              -- or desc()
        :limit(1)           -- limit("1") limit(1, 100)
        :execute()          -- 所有语句最后必须指定这个方法才会真正执行

    if not ret then
       return  print(err)
    end

    var_dump(ret)
end)

-- 更新语句示例
co.spwan(function ( ... )
    local ret, err = DB.update("user")
        :set({
            {"name", "=", "管理员"},
            {"user", "=", "Administrator"},
            {"passwd", "=", "Administrator"},
        })
        :where({
            {"id", "<=", 1},
        })
        :limit(1)
        :execute()

    if not ret then
       return  print(err)
    end

    var_dump(ret)
end)

-- 删除语句示例
co.spwan(function ( ... )
    local ret, err = DB.delete("user")
        :where({
            {"id", ">", 1},
        })
        :orderby("id")
        :limit(1)
        :execute()

    if not ret then
       return  print(err)
    end

    var_dump(ret)
end)


co.spwan(function ( ... )
    local ret, err = DB.query("show variables like 'wait_timeout'")
    if not ret then
       return print(err)
    end

    var_dump(ret)
end)