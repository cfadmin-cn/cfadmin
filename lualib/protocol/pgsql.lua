--[[
  LICENSE: BSD
  Author: CandyMi[https://github.com/candymi]
]]

local tcp = require "internal.TCP"

local crypt = require "crypt"
local md5 = crypt.md5

local sys = require "sys"
local new_tab = sys.new_tab

local null = null
local tostring = tostring
local tonumber = tonumber

local fmt = string.format
local toint = math.tointeger
local tconcat = table.concat

local string = string
local strsub  = string.sub
local strbyte = string.byte
local strchar = string.char
local strpack = string.pack
local strunpack = string.unpack
local strgmatch = string.gmatch

local RESP_ERROR = 0
local RESP_OK = 1
local RESP_READY = 2
local RESP_STATUS = 3
local RESP_STATUS_END = 4
local RESP_AUTHMD5 = 5
local RESP_COLUMN = 7
local RESP_ROW = 8
local RESP_CMD_COMPLETION = 9

local OP_QUERY = strbyte("Q")
local OP_TERMINATE = strbyte("X")

local RESPONSES = {
  [strbyte('R')] = RESP_OK,
  [strbyte("Z")] = RESP_READY,
  [strbyte('E')] = RESP_ERROR,
  [strbyte("S")] = RESP_STATUS,
  [strbyte("K")] = RESP_STATUS_END,
  [strbyte('T')] = RESP_COLUMN,
  [strbyte('D')] = RESP_ROW,
  [strbyte('C')] = RESP_CMD_COMPLETION,
}

local converters = new_tab(32, 0)

converters[16] = function (s) -- bool
  if s == null then
    return null
  end
  return (s == "t") and true or false
end

-- converters[17] = tostring -- bytea
-- converters[18] = tostring -- char
-- converters[19] = tostring -- name

converters[20] = toint -- int64
converters[21] = toint -- int16
converters[23] = toint -- int32

-- converters[25] = tostring -- text

converters[600] = function (s) -- point
  if s == null then
    return null
  end
  local point = new_tab(2, 0)
  for v in strgmatch(s, "[%-%d]+") do
    point[#point+1] = toint(v)
  end
  return point
end

converters[601] = function (s) -- lseg : [(1,2),(3,4)]
  if s == null then
    return null
  end
  local lseg = new_tab(16, 0)
  for v1, v2 in strgmatch(s, "([%-%d]+),([%-%d]+)") do
    lseg[#lseg+1] = { toint(v1), toint(v2) }
  end
  return lseg
end

converters[602] = function (s) -- path : ((1,2),(3,4))
  if s == null then
    return null
  end
  local path = new_tab(16, 0)
  for v1, v2 in strgmatch(s, "([%-%d]+),([%-%d]+)") do
    path[#path+1] = { toint(v1), toint(v2) }
  end
  return path
end

converters[603] = function (s) -- box : (1,2),(3,4)
  if s == null then
    return null
  end
  local box = new_tab(16, 0)
  for v1, v2 in strgmatch(s, "([%-%d]+),([%-%d]+)") do
    box[#box+1] = { toint(v1), toint(v2) }
  end
  return box
end

converters[604] = function (s) -- polygon : ((1,2),(3,4))
  if s == null then
    return null
  end
  local polygon = new_tab(16, 0)
  for v1, v2 in strgmatch(s, "([%-%d]+),([%-%d]+)") do
    polygon[#polygon+1] = { toint(v1), toint(v2) }
  end
  return polygon
end

converters[628] = function (s) -- line : (1,2)
  if s == null then
    return null
  end
  local line = new_tab(2, 0)
  for v in strgmatch(s, "[%-%d]+") do
    line[#line+1] = toint(v)
  end
  return line
end

converters[700] = tonumber -- float4
converters[701] = tonumber -- float8

-- converters[790] = function  (s) -- money
--   if s == null then
--     return null
--   end
--   return tonumber(strsub(s, 2))
-- end

-- converters[1043] = tostring -- varchar

--[[
local os_time = os.time
converters[1114] = function (s) -- timestamp
  if s == null then
    return null
  end
  local year, month, day, hour, min, sec = s:match("(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)")
  return os_time { year = year, month = month, day = day, hour = hour, min = min, sec = sec }
end
--]]

converters[1700] = tonumber -- numeric

-- 将结果转换为合适的类型
local function convert (tid, value)
  -- print(tid, value)
  local f = converters[tid]
  if type(f) ~= 'function' then
    return value
  end
  local v = f(value)
  if tid == 16 then -- 如果是bool类型
    return v
  end
  return v or null
end

local function get_error_message(msg)
  local severity, text, code, message, file, line, routine = string.unpack(">zzzzzzz", msg)
  return strsub(severity, 2), strsub(text, 2), strsub(code, 2), strsub(message, 2), strsub(file, 2), strsub(line, 2), strsub(routine, 2)
end

local function get_error_message_fmt(msg)
  local _, etype, code, message = get_error_message(msg)
  return nil, fmt("[%s] : {'%s', '%s'}", code, etype, message)
end

local function get_error_message_tab(msg)
  local severity, text, code, message, file, line, routine = string.unpack(">zzzzzzz", msg)
  return {
    severity = severity,
    text = text,
    code = code,
    message = message,
    file = file,
    line = line,
    routine = routine
  }
end

local function read_opcode_and_len (self)
  local opstr = self:read(1)
  if not opstr then
    return nil, "client read: server close this session."
  end
  local opcode = RESPONSES[strbyte(opstr)]
  local len_byte, err = self:read(4)
  if not len_byte then
    return nil, "client read: server close this session."
  end
  local len = strunpack(">I4", len_byte)
  if not len then
    return nil, "An unrecognized message type was received."
  end
  return opcode, len
end

local function read_head (self)
  local opcode, len = read_opcode_and_len(self)
  return opcode, len, self:read(4)
end

local function get_query_error_msg (self, data)
  local _, etype, code, message = get_error_message(data)
  local msg = fmt("[%s] : {'%s', '%s'}", code, etype, message)
  local opcode, len = read_opcode_and_len(self)
  if opcode ~= RESP_READY then
    return nil, len
  end
  local _ = self:read(len - 4)
  return nil, msg
end

local function read_column_data (self, data_len)
  local row_data = self:read(data_len)
  if not row_data then
    return nil, "client read: server close this session. "
  end
  local len, index = strunpack(">I2", row_data)
  local columns = new_tab(len, 0)
  for i = 1, len do
    local column_name, pos = strunpack(">z", row_data, index)
    -- print(column_name, pos)
    local column_table_oid, pos = strunpack(">I4", row_data, pos)
    -- print(column_table_oid, pos)
    local column_index, pos = strunpack(">I2", row_data, pos)
    -- print(column_index, pos)
    local column_type_oid, pos = strunpack(">I4", row_data, pos)
    -- print(column_type_oid, pos)
    local column_length, pos = strunpack(">I2", row_data, pos)
    -- print(column_length, pos)
    local column_type_modifier, pos = strunpack(">i4", row_data, pos)
    -- print(column_type_modifier, pos)
    local column_format, pos = strunpack(">I2", row_data, pos)
    -- print(column_format, pos)
    index = pos
    columns[#columns+1] = {
      column_name = column_name,
      column_type_oid = column_type_oid,
      -- column_index = column_index,
      -- column_length = column_length,
      -- column_format = column_format,
      -- column_table_oid = column_table_oid,
      -- column_type_modifier = column_type_modifier,
    }
  end
  return columns
end

local function read_row_data (self)
  local opcode, len = read_opcode_and_len(self)
  if not opcode then
    return nil, "server close this session."
  end
  if opcode == RESP_CMD_COMPLETION then
    return opcode, len
  end
  local row_data = self:read(len - 4)
  if not row_data then
    return nil, "server close this session."
  end
  local index = 3
  local count = strunpack(">I2", row_data)
  local row = new_tab(count, 0)
  for i = 1, count do
    local raw_len, pos = strunpack(">i4", row_data, index)
    -- print(raw_len)
    if raw_len > -1 then
      row[#row + 1] = row_data:sub(pos, pos + raw_len - 1)
      index = pos + raw_len
    else
      row[#row + 1] = null
      index = pos
    end
  end
  return row
end

local function read_response (self)
  local results = {}
  while 1 do
    local opcode, len = read_opcode_and_len(self)
    if not opcode then
      self.state = "closed"
      return nil, "1. server close this session."
    end
    if opcode == RESP_ERROR then
      return get_query_error_msg(self, self:read(len - 4):sub(5))
    end
    local result
    if opcode == RESP_STATUS then
      local kv = self:read(len - 4)
      if not kv then
        self.state = "closed"
        return nil, "2. server close this session."
      end
      local k, v = strunpack("zz", kv)
      if not result then
        result = { ok = true, [k] = v }
      else
        result[k] = v
      end
      result['ok'] = true
      result['action'] = "SET"
      result['status'] = "Idle"
      results[#results + 1] = result
      local opcode, len = read_opcode_and_len(self)
      if not opcode then
        self.state = "closed"
        return nil, "3. server close this session."
      end
      if opcode == RESP_CMD_COMPLETION then
        local _ = self:read(len - 4)
      end
    elseif opcode == RESP_CMD_COMPLETION then
      local tab = new_tab(3, 0)
      local content = self:read(len - 4)
      if not content then
        self.state = "closed"
        return nil, "4. server close this session."
      end
      for v in strgmatch(content, "[^ \x00]+") do
        tab[#tab+1] = v
      end
      if not result then
        result = new_tab(0, 5)
      end
      local action = tab[1]
      result['ok'] = true
      result['status'] = "Idle"
      result['action'] = action
      if action == "INSERT" then
        result['oid'] = toint(tab[2])
        result['affected_rows'] = toint(tab[3])
      elseif action == "UPDATE" or action == "DELETE" then
        result['affected_rows'] = toint(tab[2])
      else
        result["rows"] = toint(tab[2])
      end
      results[#results + 1] = result
      -- var_dump(results)
    elseif opcode == RESP_READY then
      local v = self:read(len - 4)
      if not v then
        self.state = "closed"
        return nil, "5. server close this session."
      end
      -- if v == "T" then
      --   results[#results].transaction = true
      -- else
      --   results[#results].transaction = false
      -- end
      break
    elseif opcode == RESP_COLUMN then
      local columns, err = read_column_data(self, len - 4)
      if not columns then
        self.state = "closed"
        return nil, err
      end
      -- var_dump(columns)
      local row, len
      local rows = new_tab(128, 0)
      while 1 do
        row, len = read_row_data(self)
        if type(row) == 'table' then
          rows[#rows + 1] = row
        elseif type(row) == 'number' then
          break
        else
          self.state = "closed"
          return nil, "6. server close this session."
        end
      end
      -- var_dump(rows)
      result = new_tab(#rows, 0)
      for _, row in ipairs(rows) do
        local tab = {}
        for index, column in ipairs(columns) do
          tab[column.column_name] = convert(column.column_type_oid, row[index])
        end
        result[#result + 1] = tab
      end
      results[#results+1] = result
      if row == RESP_CMD_COMPLETION then
        local v = self:read(len - 4)
        if not v then
          self.state = "closed"
          return nil, "7. server close this session."
        end
      end
    end
  end
  return #results == 1 and results[1] or results
end

-- AUTH_MD5
local function auth_md5(auth_user, auth_password, auth_salt)
  return "md5" .. md5(md5(auth_password .. auth_user, true) .. auth_salt, true)
end

-- 设置客户端连接参数
local function set_conn_param(key, value)
  return strpack("zz", key, value)
end

local class = require "class"

local pgsql = class("pgsql")

function pgsql:ctor(opt)
  self.sock = tcp:new()
  self.host = opt.host or "localhost"
  self.port = opt.port or 3306
  self.database = opt.database or "postgres"
  self.username = opt.username or "postgres"
  self.password = opt.password or "postgres"
  self.charset = opt.charset or "UTF8"
  self.application_name = opt.application_name or "cfadmin"
end

function pgsql:read(bytes)
  local sock = self.sock
  local buffers = new_tab(32, 0)
  while 1 do
    local data = sock:recv(bytes)
    if not data then
      return nil, "server close this session."
    end
    buffers[#buffers+1] = data
    bytes = bytes - #data
    if bytes <= 0 then
      break
    end
  end
  return tconcat(buffers)
end

function pgsql:write(data)
  return self.sock:send(data)
end

function pgsql:startup ()
  local connect_params = tconcat {
    strpack(">I2I2", 3, 0),                                     -- 使用3.0交互协议
    set_conn_param("user", self.username),                      -- 设置客户端登录名
    set_conn_param("database", self.database),                  -- 设置客户端数据库
    set_conn_param("client_encoding", self.charset),            -- 设置客户端字符集
    set_conn_param("application_name", self.application_name),  -- 设置客户端应用名
    "\x00",
  }
  return strpack(">I4", #connect_params + 4) .. connect_params
end

function pgsql:authmd5 (data)
  return strpack(">BI4z", strbyte("p"), 40, auth_md5(self.username, self.password, data))
end

function pgsql:connect()

  local ok, err = self.sock:connect(self.host, self.port)
  if not ok then
    return nil, err
  end

  -- 发送启动协议
  self:write(self:startup())

  local opcode, len, auth_type = read_head(self)
  if opcode ~= RESP_OK or not auth_type then
    return nil, "1. Malformed response packets."
  end
  if opcode == RESP_ERROR then
    return get_error_message_fmt(auth_type .. self:read(len - 8) )
  end

  auth_type = strunpack(">I4", auth_type)
  if auth_type == RESP_AUTHMD5 then
    self:write(self:authmd5(self:read(len - 8)))
    opcode, len, status = read_head(self)
    if not opcode or not status then
      return nil, "2. Malformed response packets."
    end
    if opcode == RESP_ERROR then
      return get_error_message_fmt(status .. self:read(len - 8) )
    end
  end

  -- 获取服务器配置信息
  local server = new_tab(0, 16)
  while 1 do
    local opcode, len = read_opcode_and_len(self)
    if opcode == RESP_STATUS then
      local k, v = strunpack("zz", self:read(len - 4))
      server[k] = v == 'on' and true or v
    elseif opcode == RESP_STATUS_END then
      server["pid"] = strunpack(">I4", self:read(4))
      server["key"] = strunpack(">I4", self:read(4))
    elseif opcode == RESP_READY then
      server["status"] = "Idle"
      self:read(len - 4) -- 读取并丢弃无用的数据
      break
    elseif opcode == RESP_ERROR then
      return get_error_message_fmt(self:read(len - 4) )
    else
      return nil, "3. Malformed response packets."
    end
  end

  self.state = "connected"
  self.server = server
  return server
end

function pgsql:query (sql)
  if type(sql) ~= 'string' or sql == '' then
    return nil, "Invalid SQL."
  end
  self:write(strpack(">BI4z", OP_QUERY, #sql + 5, sql))
  return read_response(self)
end

local escape_map = {
    ['\0'] = "\\0",
    ['\b'] = "\\b",
    ['\n'] = "\\n",
    ['\r'] = "\\r",
    ['\t'] = "\\t",
    ['\26'] = "\\Z",
    ['\\'] = "\\\\",
    ["'"] = "\\'",
    ['"'] = '\\"',
}

function pgsql.quote_to_str (sql)
  return fmt("%s", string.gsub(sql, "[\0\b\n\r\t\26\\\'\"]", escape_map))
end

function pgsql:set_timeout(timeout)
  if self.sock and tonumber(timeout) then
    self.sock._timeout = timeout
  end
end

function pgsql:close()
  if self.state == "connected" then
    self.state = "closed"
    self:write(strpack(">BI4", OP_TERMINATE, 4))
  end
  if self.sock then
    self.sock:close()
    self.sock = nil
  end
end

return pgsql
