local cf = require "cf"
local httpc = require "httpc"

local json = require "json"
local json_decode = json.decode
local json_encode = json.encode

local type = type

local tabconcat = table.concat

---comment 返回`HTTP`请求响应
---@param self        ElasticSearch        @`ElasticSearch`对象
---@param http_method string               @`HTTP`方法
---@param path        string               @`HTTP`路径
---@return table?                          @成功返回`table`, 出错返回`false`
---@return string?                         @成功返`table`, 失败返回错误信息
local function search_request(self, http_method, path, ...)
  local code, body = httpc[http_method](self._domain .. path, ...)
  if type(code) == 'nil' then
    cf.sleep(0.1)
    return search_request(self, http_method, path, ...)
  end
  ---@cast body string
  return json_decode(body)
end

local class = require "class"

---@class ElasticSearch : META
local ElasticSearch = class("Lua.ElasticSearch")

function ElasticSearch:ctor(opt)
  if type(opt) ~= 'table' then
    error("[es error]: Invalid ElasticSearch configure.")
  end
  if type(opt.domain) ~= 'string' or opt.domain == '' then
    error("[es error]: need domain.", 2)
  end
  -- 如果有设置集群认证模式
  self:set_authorization(opt.username, opt.password)
  self._sql     = type(opt.sql) == 'string' and opt.sql or nil
  self._pool    = opt.pool -- 使用连接池
  self._domain  = opt.domain
end

function ElasticSearch:set_authorization(username, password)
  self._authorization = { {"Content-Type", "application/json"} }
  if username and password then
    local key, value = httpc.basic_authorization(username, password)
    self._authorization[#self._authorization+1] = {key, value}
  end
end

function ElasticSearch:connect()
  return self:login()
end

function ElasticSearch:login()
  local code, body = httpc.get(self._domain .. '/', self._authorization, {}, 5)
  if code ~= 200 then
    return false, '[es error]: login failed.'
  end
  ---@cast body string
  local tab = json_decode(body)
  if tab and tab.version.distribution ~= 'opensearch' and tab.version.number then
    self._ver = math.tointeger(tab.version.number:match("(%d+)"))
  end
  -- var_dump(tab)
  return true
end

---comment 查看索引设置
---@param index      string | table  @索引名
function ElasticSearch:get_setting(index)
  if type(index) ~= 'string' then
    if type(index) ~= 'table' or #index < 1 then
      return false, "[es error]: index was invalid."
    end
    index = tabconcat(index, ',')
  end
  return search_request(self, 'get', '/' .. index .. '/_settings', self._authorization)
end

---comment 修改索引设置
---@param index      string   @索引名
---@param document   table    @规则文档
function ElasticSearch:set_setting(index, document)
  if type(index) ~= 'string' then
    return false, "[es error]: index was invalid."
  end
  if type(document) ~= 'table' then
    return false, "[es error]: document was invalid."
  end
  return search_request(self, 'put', '/' .. index .. '/_settings', self._authorization, json_encode(document))
end

---comment 主动关闭分页用的游标(`cursor`)
---@param cursor string  @游标(`cursor`)
function ElasticSearch:nocursor(cursor)
  if type(cursor) ~= 'string' or cursor == '' then
    return false, "[es error]: `cursor` was invalid."
  end
  local url = self._sql
  if not url then
    if self._ver then
      if self._ver >= 7 then
        url = '/_sql/close'
      else
        url = '/_xpack/sql/close'
      end
    else
      url = '/_plugins/_sql/close' -- OpenSearch
    end
  else
    url = url .. '/close'
  end
  return search_request(self, 'post', url, self._authorization, json_encode{cursor = cursor})
end

---comment 使用`SQL`的语法查询文档
---@param document table     @指定的查询文档,如`{"query":"select * from test"}`
---@param fields   table?    @(可选)字段类型(返回游标的搜索时需要指定)
---@param nowrap   boolean?  @(可选)指定为`true`则返回原始内容与结构.
function ElasticSearch:sql(document, fields, nowrap)
  if type(document) ~= 'table' then
    return false, "[es error]: document was invalid."
  end
  local url = self._sql
  if not url then
    if self._ver then
      if self._ver >= 7 then
        url = '/_sql?format=json'
      else
        url = '/_xpack/sql?format=json'
      end
    else
      url = '/_plugins/_sql' -- OpenSearch
    end
  end
  local tab, errinfo = search_request(self, 'post', url, self._authorization, json_encode(document))
  if not tab then
    return false, errinfo
  end
  -- 返回原始内容
  if nowrap then
    return tab
  end
  local rows, columns = tab.rows or tab.datarows, tab.columns or tab.schema or fields
  if not rows or not columns then
    return tab
  end
  -- 最终返回内容同关系型数据结构
  local results = { }
  if #columns < 1 then
    return results
  end
  for i = 1, #rows do
    local item = {}
    local row = rows[i]
    for j = 1, #row do
      item[columns[j].alias or columns[j].name] = row[j]
    end
    results[i] = item
  end
  if tab.cursor then
    return results, { cursor = tab.cursor, fields = columns }
  end
  return results
end

---comment 查询文档
---@param index      string | table  @索引名
---@param document   table           @查询文档
function ElasticSearch:query(index, document)
  if type(index) == 'table' then
    index = tabconcat(index, ',')
  elseif type(index) ~= 'string' then
    return false, "[es error]: `index` was invalid."
  end
  local query
  if type(document) == 'table' then
    local errinfo
    query, errinfo = json_encode(document)
    if not query then
      return false, errinfo
    end
  end
  return search_request(self, 'post', '/' .. index .. '/_search', self._authorization, query or '{}')
end

---comment 更新文档
---@param index      string | table    @索引名
---@param document   table             @自定义文档(支持脚本)
---@param id         string | integer  @指定文档`ID`
function ElasticSearch:update(index, document, id)
  if type(index) == 'table' then
    index = tabconcat(index, ',')
  elseif type(index) ~= 'string' then
    return false, "[es error]: `index` was invalid."
  end
  local url = '/' .. index .. '/_update/' .. id
  if self._ver and self._ver < 7 then
    url = '/' .. index .. '/_doc/' .. id .. '/_update'
  end
  return search_request(self, 'post', url, self._authorization, json_encode(document))
end

---comment 条件更新文档
---@param index      string | table  @索引名
---@param query      table           @更新规则
function ElasticSearch:update_by_query(index, query)
  if type(index) == 'table' then
    index = tabconcat(index, ',')
  elseif type(index) ~= 'string' then
    return false, "[es error]: `index` was invalid."
  end
  return search_request(self, 'post', '/' .. index .. '/_update_by_query', self._authorization, json_encode(query))
end

---comment 删除文档
---@param index     string            @索引名
---@param id        string | integer  @指定文档`ID`
function ElasticSearch:delete(index, id)
  if type(index) ~= 'string' then
    return false, "[es error]: `index` was invalid."
  end
  if not id then
    return false, "[es error]: `_id` was invalid."
  end
  return search_request(self, 'delete', '/' .. index .. '/_doc/' .. id, self._authorization)
end

---comment 条件删除文档
---@param index      string | table  @索引名
---@param query      table           @删除规则
function ElasticSearch:delete_by_query(index, query)
  if type(index) == 'table' then
    index = tabconcat(index, ',')
  elseif type(index) ~= 'string' then
    return false, "[es error]: `index` was invalid."
  end
  return search_request(self, 'post', '/' .. index .. '/_delete_by_query', self._authorization, json_encode(query))
end

---comment 插入文档
---@param index      string    @索引名
---@param document   table     @文档内容
---@param id string | integer? @指定文档`ID`(可选)
function ElasticSearch:insert(index, document, id)
  if type(index) ~= 'string' then
    return false, '[es error]: Invalid `insert` index'
  end
  if type(document) ~= 'table' then
    return false, '[es error]: Invalid `insert` document'
  end
  return search_request(self, 'post', '/' .. index .. '/_doc/' .. (id or ''), self._authorization, json_encode(document))
end

---comment `ElasticSearch`批量操作
---@param index   string  @指定索引名
---@param body    table   @指定操作类型
function ElasticSearch:bulk(index, body)
  if type(index) ~= 'string' then
    error('es error: `index` was invalid.', 2)
  end
  if type(body) ~= 'table' or (#body & 0x02 == 0) then
    error('es error: `body` was invalid.', 2)
  end
  local query = { }
  for i = 1, #body, 2 do
    -- local action, document = body[i], body[i+1]
    query[#query+1] = tabconcat { json_encode(body[i]), '\n', json_encode(body[i+1]), '\n' }
  end
  return search_request(self, 'post', '/_bulk', self._authorization, tabconcat(query))
end

---@class ElasticSearch.Indices.Action.info
---@field index             string|table?    @指定索引
---@field alias             string?          @指定别名
---@field filter            table?           @指定过滤器
---@field indices           string[]?        @索引数组
---@field aliases           string[]?        @别名数组
---@field is_write_index    boolean?         @指定索引写入

---@class ElasticSearch.Indices.Actions
---@field add     ElasticSearch.Indices.Action.info?  @增加别名
---@field remove  ElasticSearch.Indices.Action.info?  @删除别名

---comment `ElasticSearch`的别名操作
---@param actions ElasticSearch.Indices.Actions[]  @指定操作
function ElasticSearch:alias(actions)
  if type(actions) ~= 'table' then
    error('[es error]: `actions` was invalid', 2)
  end
  return search_request(self, 'post', '/_aliases', self._authorization, json_encode { actions = actions })
end

---@class ElasticSearch.Indices.GetQuery
---@field source       boolean?                    @返回结果是否包含`_source`字段
---@field refresh      boolean?                    @查询前是否先刷新相关分片数据
---@field version      integer?                    @查询指定版本号的数据
---@field preference   string?                     @指定查询的`preference`分片的数据
---@field includes table | string | string[]?      @指定`_source`字段内的结果名称

---comment 根据`ID`查询指定文档
---@param index     string                          @索引名称
---@param id        integer | string                @文档`ID`
---@param opt       ElasticSearch.Indices.GetQuery? @查询参数
function ElasticSearch:get(index, id, opt)
  if type(opt) ~= 'table' then
    opt = { }
  end

  local mode = '/_doc/'
  if type(opt['source']) ~= 'nil' then
    mode = '/_source/'
  end

  local args = { }

  if type(opt['includes']) == 'table' then
    local includes = opt['includes']
    ---@cast includes table
    args[#args+1] = { '_source_includes', tabconcat(includes, ',') }
  elseif type(opt['includes']) == 'string' then
    args[#args+1] = { '_source_includes', opt['includes'] }
  end

  if type(opt['refresh']) ~= 'nil' then
    args[#args+1] = { 'refresh', opt['refresh'] and 'true' or 'false' }
  end

  return search_request(self, 'get', '/' .. index .. mode .. id, self._authorization, args)
end

---comment 刷新一个或多个索引
---@param index string | string[]  @索引名称
function ElasticSearch:flush(index)
  if type(index) == 'table' then
    index = tabconcat(index, ',')
  elseif type(index) ~= 'string' then
    error('[es error]: `indices` was invalid', 2)
  end
  return search_request(self, 'post', '/' .. index .. '/_flush/', self._authorization)
end

---comment 获取一个或多个索引统计信息
---@param index string | string[]  @索引名称
function ElasticSearch:count(index)
  if type(index) == 'table' then
    index = tabconcat(index, ',')
  elseif type(index) ~= 'string' then
    error('[es error]: `indices` was invalid', 2)
  end
  return search_request(self, 'post', '/' .. index .. '/_count/', self._authorization)
end

---comment 使用默认分词器对指定文本`text`进行分词, 也可以通过传递`analyzer`参数来指定分词器
---@param text     string    @分词的文本
---@param analyzer string?   @分词器名称
function ElasticSearch:analyze(text, analyzer)
  if type(text) ~= 'string' then
    error('[es error]: `text` was invalid', 2)
  end
  if analyzer and type(analyzer) ~= 'string' then
    error('[es error]: `analyzer` was invalid', 2)
  end
  return search_request(self, 'post', '/_analyze', self._authorization, { analyzer = analyzer, text = text })
end

---comment 创建`Ingest pipeline`
---@param id       string   @`pipeline ID`
---@param document table    @`pipeline`配置
function ElasticSearch:create_pipeline(id, document)
  if type(id) ~= 'string' then
    error('[es error]: `pipeline id` was invalid', 2)
  end
  if type(document) ~= 'table' then
    error('[es error]: `document` was invalid', 2)
  end
  return search_request(self, 'put', '/_ingest/pipeline/' .. id, self._authorization, document)
end

---comment 删除`Ingest pipeline`
---@param id       string   @`pipeline ID`(传入`*`可以删除所有)
function ElasticSearch:remove_pipeline(id)
  if type(id) ~= 'string' then
    error('[es error]: `pipeline id` was invalid', 2)
  end
  return search_request(self, 'delete', '/_ingest/pipeline/' .. id, self._authorization)
end

return ElasticSearch