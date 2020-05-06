require "utils"

local sys = require "sys"

local elasticsearch = require "elasticsearch"

local es = elasticsearch:new {
  domain = "http://localhost:9200" -- domain参数一定要以http/https://开头, 并且结尾不能加上/
}

local function test_get_status_info( ... )
  -- -- 获取节点信息
  -- local ok, ret = es:status()
  -- print(ok) var_dump(ret)

  -- -- 获取当前节点状态
  -- local ok, ret = es:nodes_status()
  -- print(ok) var_dump(ret)

  -- -- 获取集群监控状态
  -- local ok, ret = es:cluster_health()
  -- print(ok) var_dump(ret)
end


local function test_create_and_delete_index()
  -- -- 创建索引
  -- local ok, ret = es:create_index("humans")
  -- print(ok) var_dump(ret)

  -- -- 删除索引
  -- local ok, ret = es:delete_index("humans")
  -- print(ok) var_dump(ret)

  -- 批量删除索引
  -- local ok, ret = es:delete_specify_index({"humans", "humans"})
  -- print(ok) var_dump(ret)

  -- -- 删除所有索引(慎用)
  -- local ok, ret = es:delete_all_index()
  -- print(ok) var_dump(ret)
end


local function test_insert_and_get_and_delete_document()
  -- -- 插入文档(自动生成ID)
  -- local ok, ret = es:add_document("humans", "chinese", {name = "CandyMi", age = 29})
  -- print(ok) var_dump(ret)

  -- 插入指定ID的文档
  -- local ok, ret = es:add_id_document("humans", "chinese", 1, {name = "車先生", age = 29, role = "father"})
  -- print("为index[humans]types[chinese]创建id为[1]document:", ok) var_dump(ret)

  -- -- 查询指定ID文档(仅显示source信息)
  -- local ok, ret = es:get_document_lite("humans", "chinese", 1, {"name", "age"})
  -- print("查询index[humans]types[chinese]内id为[1]document", ok) var_dump(ret)

  -- -- 查询指定ID文档(显示所有document信息)
  -- local ok, ret = es:get_document_extra("humans", "chinese", 1, {"name", "age"})
  -- print("查询index[humans]types[chinese]内的所有文档", ok) var_dump(ret)

  -- -- 批量查询文档
  -- local ok, ret = es:mget_document ({
  --   { id = 1, index = "humans", type = "chinese" },
  --   { id = 1, index = "humans", type = "chinese" },
  --   { id = 1, index = "humans", type = "chinese" },
  -- }, {"name", "age"})
  -- print("批量查询指定id的文档", ok) var_dump(ret)

  -- -- 删除指定ID的文档
  -- local ok, ret = es:delete_document("humans", "chinese", 1)
  -- print(ok) var_dump(ret)
end

local function test_update_document()
  -- -- 完整更新文档
  -- local ok, ret = es:update_document("humans", "chinese", 5, {name = "TZ太太", age = 33})
  -- print(ok) var_dump(ret)

  -- -- 局部更新文档
  -- local ok, ret = es:update_document_columns("humans", "chinese", 5, {name = "TZ先生", age = 1})
  -- print(ok) var_dump(ret)
end

local function test_search_document()
  -- local documents = {
  --   [1] = {name = "車爪鱼", age = 23, role = "daughter"},
  --   [2] = {name = "車哥哥", age = 25, role = "Son"},
  --   [3] = {name = "車太太", age = 27, role = "mother"},
  --   [4] = {name = "車先生", age = 29, role = "father"},
  -- }

  -- for id, document in ipairs(documents) do
  --   local ts = sys.now()
  --   document.create_at = os.date("%Y年-%m月-%d日 %H时%M分%S秒 ", ts // 1) .. string.format("%.03f", ts - ts // 1) 
  --   local ok, ret = es:add_id_document("humans", "chinese", id, document)
  --   print(ok) var_dump(ret)
  -- end

  -- -- 按照年龄降序显示上述内容
  -- local ok, ret = es:search_document("humans", "chinese", nil, { { age = { order =  "desc" } } }, nil, nil)
  -- print(ok) var_dump(ret)
end


-- -- 测试获取es服务器状态
-- test_get_status_info()

-- -- 测试创建、删除索引
-- test_create_and_delete_index()

-- 测试插入、获取、删除文档
-- test_insert_and_get_and_delete_document()
