local LOG = require "logging"
local cf = require "cf"
local DB = require "DB"

local db = DB:new {
	host = 'localhost',
	port = 3306,
	database = 'mysql',
	username = 'root',
	password = '123456789',
	max = 1,
}

local ok = db:connect()
if not ok then
	return LOG:DEBUG("连接mysql失败")
end
LOG:DEBUG("连接成功")

--[[
    /* 复制下面语句到任意管理工具即可导入测试表进行测试 */

    SET NAMES utf8;
    SET FOREIGN_KEY_CHECKS = 0;
		CREATE DATABASE IF NOT EXISTS `test` DEFAULT CHARSET utf8 COLLATE utf8_general_ci;

    CREATE TABLE IF NOT EXISTS `test`.`user` (
      `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
      `name` varchar(255) CHARACTER SET utf8mb4 NOT NULL,
      `user` varchar(255) CHARACTER SET utf8mb4 NOT NULL,
      `passwd` varchar(255) CHARACTER SET utf8mb4 NOT NULL,
      PRIMARY KEY (`id`)
    ) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

    SET FOREIGN_KEY_CHECKS = 1;
--]]

-- 测试普通数据库语句
cf.fork(function ( ... )
    local ret, err = db:query("show variables like 'wait_timeout'")
    if not ret then
       return LOG:DEBUG(err)
    end
    LOG:DEBUG(ret)
end)

-- 测试预编译语句
cf.fork(function ( ... )
	local ret, err = db:execute([[SELECT version() AS version]])
	if not ret then
		return LOG:DEBUG(err)
	end
	LOG:DEBUG(ret)
end)

-- 测试开启事务
cf.fork(function ()
  local status, err = db:transaction(function (session)
    LOG:WARN(session:query("show databases"))
    LOG:WARN(session:execute("show tables"))

    -- return session:rollback()
    return session:commit()
  end)
  LOG:DEBUG(status, err)
end)
