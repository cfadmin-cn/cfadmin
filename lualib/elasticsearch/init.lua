local httpc = require "httpc"

local new_tab = require "sys".new_tab

local json  = require "json"
local json_decode = json.decode
local json_encode = json.encode

local type = type
local ipairs = ipairs
local assert = assert
local tostring = tostring
local sub = string.sub
local fmt = string.format
local find = string.find
local lower = string.lower
local toint = math.tointeger

-- 检查ID是否需要转换
local function convert_id(id)
  if toint(id) then
    return fmt("%.f", id)
  end
  return tostring(id)
end

-- 检查domain是否有效
local function check_domain_valide(domain)
  if not find(domain, "http[s]?://(.+)[:]?[%d]?") then
    return nil, "Invalid domain."
  end
  if sub(domain, -1) == "/" then
    return nil, "domain is not allowed to end with [/]."
  end
  return domain
end

-- 检查index是否有效
local function check_index_valide(index)
  if type(index) ~= 'string' or index == "" then
    return nil, "Invalid Index."
  end
  if find(index, "^%_") or find(index, "/") then
    return nil, "'Index' cannot start with '_' or contain special characters [/]."
  end
  return index
end

-- 检查index是否有效
local function check_types_valide(types)
  if type(types) ~= 'string' or types == "" then
    return nil, "Invalid Types."
  end
  if find(types, "^%_") or find(types, "/") then
    return nil, "'Types' cannot start with '_' or contain special characters [/]."
  end
  return types
end

local class = require "class"

local Elasticsearch = class("Elasticsearch")

function Elasticsearch:ctor(opt)
  self.domain = assert(check_domain_valide(opt.domain))
end

-- 获取Elasticsearch状态信息
function Elasticsearch:status()
  local code, response = httpc.get(self.domain .. "/")
  if code ~= 200 then
    return false, code and json_decode(response) or response
  end
  return true, json_decode(response)
end

-- 获取所有Node信息
function Elasticsearch:nodes_status()
  local code, response = httpc.get(self.domain .. "/_nodes/stats")
  if code ~= 200 then
    return false, code and json_decode(response) or response
  end
  return code and code == 200 or false, json_decode(response)
end

-- 获取集群状态
function Elasticsearch:cluster_health()
  local code, response = httpc.get(self.domain .. "/_cluster/health")
  if code ~= 200 then
    return false, code and json_decode(response) or response
  end
  return code and code == 200 or false, json_decode(response)
end

--[[

创建索引

  第一个参数为需要创建的索引名称;

  第二个参数为创建的索引的配置(可选, 不填写在按照es默认配置创建索引, 否则需要按照指定规则填充table);

返回值:

  此方法在网络连接失败、索引已经存在、配置(如果有)编写正确的时候才会返回flase, 其他情况下将会返回true;
--]]
function Elasticsearch:create_index(index, config)
  local index = assert(check_index_valide(index))
  local code, response = httpc.put(self.domain .. "/" .. lower(index), {{"Content-Type", "application/json"}}, type(config) == 'table' and json_encode(config) or nil)
  if code ~= 200 then
    return false, code and json_decode(response) or response
  end
  return code and code == 200 or false, json_decode(response)
end

--[[

删除单个指定索引

  index 参数为需要删除的字符串索引名称;

返回值:

  此方法在网络连接失败、索引不存在时才会返回flase, 其他情况下将会返回true;

--]]
function Elasticsearch:delete_index(index)
  local index = assert(check_index_valide(index))
  local code, response = httpc.delete(self.domain .. "/" .. lower(index), {{"Content-Type", "application/json"}})
  if code ~= 200 then
    return false, code and json_decode(response) or response
  end
  return code and code == 200 or false, json_decode(response)
end

--[[

同时删除多个指定索引

  indexs 参数视为一个索引字符串数组, 数组内的每个字符串都会被当做一个已存在的索引;

返回值

  此方法在网络连接失败、indexs内的索引不存在时才会返回flase, 其他情况下将会返回true;

--]]
function Elasticsearch:delete_specify_index(indexs)
  local indexs = assert(type(indexs) == 'table' and #indexs > 0 and table.concat(indexs, ",") or nil, "[delete_specify_index error] : array need a table and len must > 0.")
  local code, response = httpc.delete(self.domain .. "/" .. lower(indexs), {{"Content-Type", "application/json"}})
  if code ~= 200 then
    return false, code and json_decode(response) or response
  end
  return code and code == 200 or false, json_decode(response)
end

--[[

删除所有索引(慎用)

  此方法用来删除Elasticesearch内的所有索引, 除非您确认需要清空es所有内容. 否则在其他任何清空下都不要使用它;

  此方法没有任何参数, 返回200则表示true; 但即使es已经为空时多次调用始终会成功, 所以一般网络连接失败的时候才会为false;

--]] 
function Elasticsearch:delete_all_index()
  local code, response = httpc.delete(self.domain .. "/_all", {{"Content-Type", "application/json"}})
  if code ~= 200 then
    return false, code and json_decode(response) or response
  end
  return code and code == 200 or false, json_decode(response)
end

-- 获取指定ID文档内容(仅返回source内容)
function Elasticsearch:get_document_lite(index, types, id, columns)
  assert(id and ((type(id) == 'string' or type(id) == 'number') and id ~= ''), "[get_document_lite error]: Invalide id.")
  local index, err1 = check_index_valide(index)
  local types, err2 = check_types_valide(types)
  local code, response = httpc.get(self.domain .. "/" .. lower(assert(index, "[get_document_lite index error]: " .. (err1 or "") )) .. "/" .. lower(assert(types, "[get_document_lite types error]: " .. (err2 or ""))) .. "/" .. id .. "/_source" .. ((type(columns) == "table" and #columns > 0) and "?_source=" .. table.concat(columns, ",") or ""))
  if code ~= 200 then
    return false, code and json_decode(response) or response
  end
  return code and code == 200 or false, json_decode(response)
end

-- 获取指定ID文档内容(返回文档与相关属性)
function Elasticsearch:get_document_extra(index, types, id, columns)
  assert(id and ((type(id) == 'string' or type(id) == 'number') and id ~= ''), "[get_document_extra error]: Invalide id.")
  local index, err1 = check_index_valide(index)
  local types, err2 = check_types_valide(types)
  local code, response = httpc.get(self.domain .. "/" .. lower(assert(index, "[get_document_extra index error]: " .. (err1 or ""))) .. "/" .. lower(assert(types, "[get_document_extra types error]: " .. (err2 or ""))) .. "/" .. id .. ((type(columns) == "table" and #columns > 0) and "?_source=" .. table.concat(columns, ",") or ""))
  if code ~= 200 then
    return false, code and json_decode(response) or response
  end
  return code and code == 200 or false, json_decode(response)
end

--[[

批量获取指定文档内容

  array    参数为对象数组, 数组内对象表示法为: { index = 索引名称, type = 类型名称, id = 文档id };

  columns  参数为指定返回内容数组(可选), 如果有内容则仅返回数组内的field所对应的document {key : value}.

返回值:

  此方法仅在连接失败的时候会返回flase, 在传递错误的参数时会抛出异常, 其他情况下将会返回true;

--]]
function Elasticsearch:mget_document(array, columns)
  assert(type(array) == 'table' and #array > 0, "[mget_document index error]: array need a table and len must > 0.")
  local docs = new_tab(#array, 0)
  for i, item in ipairs(array) do
    assert(type(item) == "table" and check_index_valide(item.index) and check_types_valide(item.type) and ((type(item.id) == 'string' or type(item.id) == 'number') and item.id ~= ''), "[mget_document error] : array index[" .. i .. "] object error.")
    docs[#docs+1] = { _index = item.index, _type = item.type, _id = convert_id(item.id) }
  end
  local code, response = httpc.json(self.domain .. "/_mget" .. ((type(columns) == "table" and #columns > 0) and "?_source=" .. table.concat(columns, ",") or ""), nil, json_encode { docs = docs })
  if not code then
    return false, code and json_decode(response) or response
  end
  return code and code == 200 or false, json_decode(response)
end

--[[

创建文档

  index     参数为索引名称, 默认情况下不存在此索引会自动创建; (如果系统不允许自动创建, 会返回错误)

  types     参数为类型名称, 默认情况下自动创建; (如果系统不允许自动创建, 会返回错误)

  document  一个可被json序列化的table;

返回值:

  此方法在连接失败的时候会返回flase, 其他情况下则会返回true; 

  请注意: es会为此文档随机生成id为20个字节的字符串, 所以它在大部分情况下都会成功.

--]]
function Elasticsearch:add_document(index, types, document)
  local index, err1 = check_index_valide(index)
  local types, err2 = check_types_valide(types)
  local document = assert(json_encode(document), "Invalid document.")
  local code, response = httpc.json(self.domain .. "/" .. lower(assert(index, "[add_document index error]: "  .. (err1 or ""))) .. "/" .. lower(assert(types, "[add_document types error]: " .. (err2 or ""))), nil, document)
  if code ~= 200 and code ~= 201 then
    return false, code and json_decode(response) or response
  end
  return true, json_decode(response)
end

--[[

创建/更新指定ID的文档

  index     参数为索引名称, 默认情况下不存在此索引会自动创建; (如果系统不允许自动创建, 会返回错误)

  types     参数为类型名称, 默认情况下自动创建; (如果系统不允许自动创建, 会返回错误)

  id        参数指定文档ID, 它可以为一个递增的数字或者字符串;

  document  一个可被json序列化的table;

返回值:

  此方法在连接失败、插入失败(已存在)的时候会返回flase, 其他情况下则会返回true;

  请注意: 将文档添加到一个已存在的ID上的行为等同于更新文档, 所以此操作总会是成功的;

--]]
function Elasticsearch:add_id_document(index, types, id, document)
  assert(id and ((type(id) == 'string' or type(id) == 'number') and id ~= ''), "[add_id_document error]: Invalide id.")
  local index, err1 = check_index_valide(index)
  local types, err2 = check_types_valide(types)
  local document = assert(json_encode(document), "[add_id_document error]: Invalid document.")
  local code, response = httpc.json(self.domain .. "/" .. lower(assert(index, "[add_id_document index error]: " .. (err1 or "") )) .. "/" .. lower(assert(types, "[add_id_document types error]: " .. (err2 or ""))) .. "/" .. convert_id(id), nil, document)
  if code ~= 200 and code ~= 201 then
    return false, code and json_decode(response) or response
  end
  return true, json_decode(response)
end

--[[
完整更新文档

  index     索引名称, 不能以[_]开头、不能包含[/]、所有字符串必须为小写;

  types     类型名称, 不能以[_]开头、不能包含[/]、所有字符串必须为小写;

  id        必须是一个有效的字符串或者正整数;

  document  一个可被json序列化的table;

返回值:

  第一个返回值在网络连接失败、HTTP code非200/201的时候将为false, 其他情况下则会返回true;

  请注意: 完整的文档更新将会在id不存在的时候插入一条新数据, 所以此操作总会是成功的;

--]]
function Elasticsearch:update_document(index, types, id, document)
  assert(id and ((type(id) == 'string' or type(id) == 'number') and id ~= ''), "[update_document error]: Invalide id.")
  local index, err1 = check_index_valide(index)
  local types, err2 = check_types_valide(types)
  local document = assert(type(document) == 'table' and document, "[update_document error]: Invalid document.")
  local code, response = httpc.json(self.domain .. "/" .. lower(assert(index, "[add_id_document index error]: " .. (err1 or "") )) .. "/" .. lower(assert(types, "[add_id_document types error]: " .. (err2 or ""))) .. "/" .. convert_id(id), nil, json_encode(document))
  if code ~= 200 and code ~= 201 then
    return false, code and json_decode(response) or response
  end
  return true, json_decode(response)
end

--[[
局部更新文档

  index     索引名称, 不能以[_]开头、不能包含[/]、所有字符串必须为小写;

  types     类型名称, 不能以[_]开头、不能包含[/]、所有字符串必须为小写;

  id        必须是一个有效的字符串或者正整数;

  columns   一个可被json序列化的table;

返回值:

  第一个返回值在网络连接失败、HTTP code非200的时候将为false, 其他情况下则会返回true;

  请注意: 局部更新的行为就是真正的更新行为, 它会在ID映射的文档不存在的时候返回一个false;

--]]
function Elasticsearch:update_document_columns(index, types, id, columns)
  assert(id and ((type(id) == 'string' or type(id) == 'number') and id ~= ''), "[update_document_columns error]: Invalide id.")
  local index, err1 = check_index_valide(index)
  local types, err2 = check_types_valide(types)
  local columns = assert(type(columns) == 'table' and columns, "[update_document_columns error]: Invalid columns.")
  local code, response = httpc.json(self.domain .. "/" .. lower(assert(index, "[add_id_document index error]: " .. (err1 or "") )) .. "/" .. lower(assert(types, "[add_id_document types error]: " .. (err2 or ""))) .. "/" .. convert_id(id) .. "/_update", nil, json_encode { doc = columns })
  if code ~= 200 then
    return false, code and json_decode(response) or response
  end
  return true, json_decode(response)
end

--[[

删除指定ID的文档  

  index 索引名称, 不能以[_]开头、不能包含[/]、所有字符串必须为小写;

  types 类型名称, 不能以[_]开头、不能包含[/]、所有字符串必须为小写;

  id    必须是一个有效的字符串或者正整数;

返回值: 

  第一个返回值在网络连接失败、HTTP code非200、删除不存在的ID等等时候将为false;

  第二个返回值为string类型表示连接失败. 请求成功、操作失败则为一个table;

--]]
function Elasticsearch:delete_document(index, types, id)
  assert(id and ((type(id) == 'string' or type(id) == 'number') and id ~= ''), "[delete_document error]: Invalide id.")
  local index, err1 = check_index_valide(index)
  local types, err2 = check_types_valide(types)
  local code, response = httpc.delete(self.domain .. "/" .. lower(assert(index, "[delete_document index error]: " .. (err1 or ""))) .. "/" .. lower(assert(types, "[add_document types error]: " .. (err2 or ""))) .. "/" .. convert_id(id))
  if not code then
    return false, code and json_decode(response) or response
  end
  return code and code == 200 or false, json_decode(response)
end

--[[

搜索文档:

  index 索引名称, 不能以[_]开头、不能包含[/]、所有字符串必须为小写;

  types 类型名称, 不能以[_]开头、不能包含[/]、所有字符串必须为小写;

  opt 参数必须是一个非数组table或者nil, 指定它则有以下三个可选属性:

    opt.from    指定搜索文档的开始位置, 行为类似于 LIMIT X, Y中的X;
    opt.size    指定搜索文档的条目数量, 行为类似于 LIMIT X, Y中的Y;
    opt.source  指定搜索文档返回的内容, 它不是一个字符串数组的时候将会出错;

  sort 参数是排序相关性的DLS表达式语句, 如果不需要排序传递nil即可;

  aggs 参数是表达聚合表达式的DLS表达式语句, 如果不需要聚合传递nil即可;

  query 参数是一个es自定义查询DSL, 合理的表达式可以完成更多的复合查询;

返回值:

  第一个返回值在网络连接失败、HTTP code非200、索引不存在、表达式错误等等时候都会为false;

  第二个返回值为string类型表示连接失败. 请求成功或操作失败, 第二个参数必然为一个table;

--]]
function Elasticsearch:search_document(index, types, opt, sort, aggs, query)
  local index, err1 = check_index_valide(index)
  local types, err2 = check_types_valide(types)
  local opt = (type(opt) ~= 'table' or #opt > 0) and {} or opt
  local sort = type(sort) == 'table' and #sort > 0 and sort or nil
  local code, response = httpc.json(self.domain .. "/" .. lower(assert(index, "[search_limit index error]: " .. (err1 or ""))) .. "/" .. lower(assert(types, "[search_limit types error]: " .. (err2 or ""))) .. "/_search?_source=" .. (type(opt.source) == 'table' and #opt.source > 0 and table.concat(opt.source, ",") or ''), nil, json_encode {
      from = (toint(opt.from) and toint(opt.from) >= 0) and toint(opt.from) or nil, size = (toint(opt.size) and toint(opt.size) > 0) and toint(opt.size) or nil,
      sort = sort, aggs = type(aggs) == 'table' and aggs or nil, query = type(query) ~= 'table' and { match_all = {} } or query,
    })
  if code ~= 200 then
    return false, code and json_decode(response) or response
  end
  return code and code == 200 or false, json_decode(response)
end

return Elasticsearch