require "utils"
local es = require "es"

---@type ElasticSearch
local o = es {
  domain = "http://localhost:9200",
  -- 如果需要验证
  username = "elastic", password = "PV+nXLk8z*ypGBxmO55d",
}

assert(o:connect())

-- 插入数据
print(o:insert("test", { name = "車先生1", sex = 'male',   age = 9 }, 1))
print(o:insert("test", { name = "車太太1", sex = 'female', age = 7 }, 2))
print(o:insert("test", { name = "車先生2", sex = 'male',   age = 9 }, 3))
print(o:insert("test", { name = "車太太2", sex = 'female', age = 7 }, 4))
print(o:insert("test", { name = "車爪嘟",  sex = 'female', age = 1 }, 5))

-- 修改数据
print(o:update("test", { doc = { age = 29 } }, 3))
print(o:update("test", { doc = { age = 27 } }, 4))

-- 删除数据
print(o:delete("test", 1))
print(o:delete("test", 2))
print(o:delete_by_query("test", { query = { match_all = { } } }))

-- 普通查询
var_dump(o:query("test", { --[[ 查询规则 ]] }))
-- SQL查询
var_dump(o:sql({ query = "select * from test", --[[ 其它查询规则 ]] }))