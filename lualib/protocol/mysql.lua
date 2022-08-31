--[[
  LICENSE: BSD
  Author: CandyMi[https://github.com/candymi]
]]

local stream = require "stream"
local tcp = require "internal.TCP"
local crypt = require "crypt"
local sha1 = crypt.sha1
local sha2 = crypt.sha256
local xor_str = crypt.xor_str
local randomkey = crypt.randomkey_ex
local rsa_oaep_pkey_encode = crypt.rsa_public_key_oaep_padding_encode

local sub = string.sub
local strgsub = string.gsub
local strformat = string.format
local strbyte = string.byte
local strchar = string.char
local strrep = string.rep
local strunpack = string.unpack
local strpack = string.pack
local assert = assert
local tonumber = tonumber
local toint = math.tointeger
local mtype = math.type

local tpack = table.pack
local insert = table.insert
local concat = table.concat

local null = null
local type = type
local ipairs = ipairs
local tostring = tostring
local io_open = io.open
local io_remove = os.remove

local sys = require "sys"
local new_tab = sys.new_tab

-- 多结果集
local SERVER_MORE_RESULTS = 0x08

-- 请求成功
local RESP_OK = 0x00
-- 数据尾部
local RESP_EOF = 0xFE
-- 发生错误
local RESP_ERROR = 0xFF

-- 退出
local CMD_QUIT = 0x01

-- 查询
local CMD_QUERY = 0x03

-- 编译
local COM_STMT_PREPARE = 0x16
-- 执行
local COM_STMT_EXECUTE = 0x17

local CURSOR_TYPE_NO_CURSOR = 0x00

-- 类型转换函数
local converts = new_tab(32, 0)

local function toNumber (data)
  if data == null then
    return null
  end
  return tonumber(data)
end

for index = 0x00, 0x05 do
  converts[index] = toNumber
end

converts[0x08] = toNumber

converts[0x09] = toNumber

converts[0x0D] = toNumber

converts[0xF6] = toNumber

local CHARSET_MAP = {
    _default  = 0,
    big5      = 1,
    dec8      = 3,
    cp850     = 4,
    hp8       = 6,
    koi8r     = 7,
    latin1    = 8,
    latin2    = 9,
    swe7      = 10,
    ascii     = 11,
    ujis      = 12,
    sjis      = 13,
    hebrew    = 16,
    tis620    = 18,
    euckr     = 19,
    koi8u     = 22,
    gb2312    = 24,
    greek     = 25,
    cp1250    = 26,
    gbk       = 28,
    latin5    = 30,
    armscii8  = 32,
    utf8      = 33,
    ucs2      = 35,
    cp866     = 36,
    keybcs2   = 37,
    macce     = 38,
    macroman  = 39,
    cp852     = 40,
    latin7    = 41,
    utf8mb4   = 45,
    cp1251    = 51,
    utf16     = 54,
    utf16le   = 56,
    cp1256    = 57,
    cp1257    = 59,
    utf32     = 60,
    binary    = 63,
    geostd8   = 92,
    cp932     = 95,
    eucjpms   = 97,
    gb18030   = 248
}

local function sock_write (self, data)
  return self.sock:send(data)
end

local function sock_read (self, bytes)
  return self.sock:readbytes(bytes)
end

-- mysql_native认证
local function mysql_native_password(password, scramble)
  if type(password) ~= 'string' or password == "" then
    return ""
  end
  local stage1 = sha1(password)
  local stage2 = sha1(scramble .. sha1(stage1))
  return xor_str(stage2, stage1)
end

-- mysql_sha256认证
local function mysql_sha256_password(password, scramble)
  if type(password) ~= 'string' or password == "" then
    return ""
  end
  local stage1 = sha2(password)
  local stage2 = sha2(sha2(stage1) .. scramble)
  return xor_str(stage1, stage2)
end

-- caching_sha2认证
local function caching_sha2_password(password, scramble)
  return mysql_sha256_password(password, scramble)
end

-- RSA扩展公钥认证
local function rsa_encode(public_key, password, scramble)
  local filename = randomkey(8, true) .. '.pem'
  local f = assert(io_open(filename, 'a'), "Can't Create public_key file to complate handshake.")
  f:write(public_key):flush()
  f:close()
  return rsa_oaep_pkey_encode(xor_str(password, scramble), filename), io_remove(filename)
end

local function get_mysql_error_packet (packet)
  local errcode, sqlstate, msg, pos
  errcode, pos = strunpack("<I2", packet, 1)
  sqlstate = sub(packet, pos + 1, pos + 5)
  msg = sub(packet, pos + 6)
  return strformat("{errcode = \"%s\", sqlstate = \"%s\", info = \"%s\"}", errcode, sqlstate, msg)
end

local function read_head (self)
  local packet, err = sock_read(self, 4)
  if not packet then
    return nil, err
  end
  return strunpack("<I3", packet)
end

local function read_status (self)
  local packet, err = sock_read(self, 1)
  if not packet then
    return nil, err
  end
  return strunpack("<B", packet)
end

local function read_body (self, len)
  local packet, err = sock_read(self, len)
  if not packet then
    return nil, err
  end
  return packet, 1
end

local function read_packet (self)
  local len, err = read_head(self)
  if not len then
    return nil, err
  end
  local packet, err = read_body(self, len)
  if not packet then
    return nil, err
  end
  return packet
end

local function get_lenenc_str (packet, pos)
  local bit, len
  bit, pos = strunpack("<B", packet, pos)
  -- 251 ~ 2^16
  if bit == 0xFC then
    len, pos = strunpack("<I2", packet, pos)
    return sub(packet, pos, pos + len - 1), pos + len
  end
  -- 2^16 ~ 2^24
  if bit == 0xFD then
    len, pos = strunpack("<I3", packet, pos)
    return sub(packet, pos, pos + len - 1), pos + len
  end
  -- 2^24 ~ 2^64
  if bit == 0xFE then
    len, pos = strunpack("<I8", packet, pos)
    return sub(packet, pos, pos + len - 1), pos + len
  end
  -- NULL
  if bit == 0xFB then
    return null, pos
  end
  return sub(packet, pos, pos + bit - 1), pos + bit
end

local function get_lenenc_int (packet, pos)
  local bit
  bit, pos = strunpack("<B", packet, pos)
  if bit == 0xFC then
    return strunpack("<I2", packet, pos)
  end
  if bit == 0xFD then
    return strunpack("<I3", packet, pos)
  end
  if bit == 0xFE then
    return strunpack("<I8", packet, pos)
  end
  if bit == 0x00 then
    return 0, pos
  end
  return bit, pos
end

local function get_field (self)
  local len, err = read_head(self)
  if not len then
    return nil, err
  end
  local packet, pos = read_body(self, len)
  if not packet then
    return nil, pos
  end
  local catalog, database, table, otable, name, oname, charset, length, type, flags, decimals, _
  catalog, pos = get_lenenc_str(packet, pos)
  -- print("catlog", catlog)
  database, pos = get_lenenc_str(packet, pos)
  -- print("database", database)
  table, pos = get_lenenc_str(packet, pos)
  -- print("table", table)
  otable, pos = get_lenenc_str(packet, pos)
  -- print("otable", otable)
  name, pos = get_lenenc_str(packet, pos)
  -- print("name", name)
  oname, pos = get_lenenc_str(packet, pos)
  -- print("oname", oname)
  _, charset, pos = strunpack("<BI2", packet, pos)
  -- print("charset :", charset)
  length, pos = strunpack("<I4", packet, pos)
  -- print("length :", length)
  type, pos = strunpack("<B", packet, pos)
  -- print("type :", type)
  flags, pos = strunpack("<I2", packet, pos)
  -- print("flags :", flags)
  decimals, pos = strunpack("<B", packet, pos)
  -- print("decimals :", decimals)
  return { field_name = name, field_type = type, field_len = length, is_signed = flags & 0x20 == 0 or false }
end

local function get_rows (packet, quantity)
  local row = new_tab(quantity, 0)
  local row_info, pos = nil, 1
  for i = 1, quantity do
    row_info, pos = get_lenenc_str(packet, pos)
    row[i] = row_info
  end
  return row
end

local function _from_length_coded_bin(data, pos)
  local first = strbyte(data, pos)
  if not first then
    return nil, pos
  end
  if first >= 0 and first <= 250 then
    return first, pos + 1
  end
  if first == 251 then
    return nil, pos + 1
  end
  if first == 252 then
    pos = pos + 1
    return strunpack("<I2", data, pos)
    -- return _get_byte2(data, pos)
  end
  if first == 253 then
    pos = pos + 1
    return strunpack("<I3", data, pos)
    -- return _get_byte3(data, pos)
  end
  if first == 254 then
    pos = pos + 1
    return strunpack("<I8", data, pos)
    -- return _get_byte8(data, pos)
  end
  return false, pos + 1
end

local function _from_length_coded_str(data, pos)
  local len
  len, pos = _from_length_coded_bin(data, pos)
  if len == nil then
    return nil, pos
  end
  return sub(data, pos, pos + len - 1), pos + len
end

local function _get_datetime(data, pos)
  local len, year, month, day, hour, minute, second
  local value
  len, pos = _from_length_coded_bin(data, pos)
  if len == 7 then
    year, month, day, hour, minute, second, pos = string.unpack("<I2BBBBB", data, pos)
    value = strformat("%04d-%02d-%02d %02d:%02d:%02d", year, month, day, hour, minute, second)
  else
    value = "2017-09-09 20:08:09"
    --unsupported format
    pos = pos + len
  end
  return value, pos
end

local function _get_decimal(data, pos)
  local num
  num, pos = _from_length_coded_str(data, pos)
  return tonumber(num), pos
end

local binary_parser = {
  [0x00] = _get_decimal,
  [0x01] = function (data, pos, is_signed)
    local fmt = is_signed and "<i1" or "<I1"
    return strunpack(fmt, data, pos)
  end,
  [0x02] = function (data, pos, is_signed)
    local fmt = is_signed and "<i2" or "<I2"
    return strunpack(fmt, data, pos)
  end,
  [0x03] = function (data, pos, is_signed)
    local fmt = is_signed and "<i4" or "<I4"
    return strunpack(fmt, data, pos)
  end,
  [0x04] = function(data, pos)
    return strunpack("<f", data, pos)
  end,
  [0x05] = function(data, pos)
    return strunpack("<d", data, pos)
  end,
  [0x07] = _get_datetime,
  [0x08] = function (data, pos, is_signed)
    local fmt = is_signed and "<i8" or "<I8"
    return strunpack(fmt, data, pos)
  end,
  [0x09] = function (data, pos, is_signed)
    local fmt = is_signed and "<i3" or "<I3"
    return strunpack(fmt, data, pos)
  end,
  [0x0a] = function (data, pos)
    local year, month, day, _
    _, year, month, day, pos = strunpack("<BI2BB", data, pos)
    return strformat("%04u-%02u-%02u", year, month, day), pos
  end,
  [0x0c] = _get_datetime,
  [0x0f] = _from_length_coded_str,
  [0x10] = _from_length_coded_str,
  [0xf5] = _from_length_coded_str,
  [0xf6] = _get_decimal,
  [0xf9] = _from_length_coded_str,
  [0xfa] = _from_length_coded_str,
  [0xfb] = _from_length_coded_str,
  [0xfc] = _from_length_coded_str,
  [0xfd] = _from_length_coded_str,
  [0xfe] = _from_length_coded_str
}

local function get_bin_rows(data, cols)
  local ncols = #cols
  -- 空位图,前两个bit系统保留 (列数量 + 7 + 2) / 8
  local null_count = (ncols + 9) // 8
  local pos = 2 + null_count

  --空字段表
  local null_fields = {}
  local field_index = 1
  local byte
  for i = 2, pos - 1 do
    byte = strbyte(data, i)
    for j = 0, 7 do
      if field_index > 2 then
        null_fields[field_index - 2] = byte & (1 << j) ~= 0 and true or false
      end
      field_index = field_index + 1
    end
  end

  local parser
  local row = new_tab(0, ncols)
  for i = 1, ncols do
    local col = cols[i]
    -- var_dump(col)
    if not null_fields[i] then
      parser = binary_parser[col.field_type]
      if not parser then
        error("error! field key[" .. col.field_name .."] unsupported type " .. col.field_type)
      end
      row[col.field_name], pos = parser(data, pos, col.is_signed)
    else
      row[col.field_name] = null
    end
  end
  return row
end

local function get_eof_packet (packet)
  local pos = 1
  local warning_count, status_flags
  warning_count, pos = strunpack("<I2", packet, pos)
  status_flags, pos = strunpack("<I2", packet, pos)
  -- print(warning_count, status_flags)
  return { warning_count = warning_count, status_flags = status_flags }
end

local function get_eof (self, len)
  local packet = read_body(self, len)
  if not packet then
    return nil, "mysql server closed when client sended query packet."
  end
  return get_eof_packet(packet)
end

local function get_ok(packet, length)
  local pos = 1
  local affected_rows, last_insertid
  affected_rows, pos = get_lenenc_int(packet, pos)
  -- print("affected_rows", affected_rows, pos)
  last_insertid, pos = get_lenenc_int(packet, pos)
  -- print("last_insertid", last_insertid, pos)
  if not toint(last_insertid) or toint(last_insertid) <= 0 then
    last_insertid = nil
  end
  local server_status, pos = strunpack("<I2", packet, pos)
  local server_warnings, pos = strunpack("<I2", packet, pos)
  local message = nil
  if length and length > pos then
    message, pos = strunpack("s1", packet, pos)
  end
  return {
    auto_commit = server_status & 0x02 == 0x02 and true or false, transaction = server_status & 0x01 == 0x01 and true or false,
    last_insertid = last_insertid, affected_rows = affected_rows, server_warnings = server_warnings, message = message
  }, server_status & SERVER_MORE_RESULTS == SERVER_MORE_RESULTS
end

local function read_response (self, results)
  local packet = read_packet(self)
  if not packet then
    self.state = nil
    return nil, "1. mysql server closed when client sended query packet."
  end
  local status = strbyte(packet, 1)
  if status == RESP_ERROR then
    return nil, get_mysql_error_packet(packet:sub(2))
  end
  if status == RESP_OK then
    local tab, again = get_ok(packet:sub(2), #packet - 1)
    if again then -- 如果是`多结果集的数据
      if type(results) == 'table' then
        results[#results+1] = tab
        return read_response(self, results)
      end
      return read_response(self, { tab })
    end
    if type(results) == 'table' then
      results[#results+1] = tab
      tab = results
    end
    return tab
  end

  local fields = new_tab(status, 0)
  for index = 1, status do
    local field, err = get_field(self)
    if not field then
      self.state = nil
      return nil, err
    end
    fields[index] = field
  end

  local again = false
  local len = read_head(self)
  if not len then
    self.state = nil
    return nil, "2. mysql server closed when client sended query packet."
  end
  local status, err = read_status(self)
  if not status then
    self.state = nil
    return nil, err
  end
  local sever = get_eof(self, len - 1)
  if sever.status_flags & SERVER_MORE_RESULTS == SERVER_MORE_RESULTS then
    again = true
  end

  local rows = new_tab(32, 0)
  while 1 do
    packet, err = read_packet(self)
    if not packet then
      self.state = nil
      return nil, err
    end
    local b = strbyte(packet, 1)
    if b == RESP_EOF and #packet < 9 then
      local sever = get_eof_packet(packet)
      if sever.status_flags & SERVER_MORE_RESULTS == SERVER_MORE_RESULTS then
        again = true
      end
      break
    end
    if b == RESP_ERROR then
      return nil, get_mysql_error_packet(packet:sub(2))
    end
    rows[#rows+1] = get_rows(packet, #fields)
  end

  local result = new_tab(#rows, 0)
  for _, row in ipairs(rows) do
    local tab = new_tab(0, #fields)
    for index, item in ipairs(row) do
      local field = fields[index]
      local call = converts[field.field_type]
      if not call then
        -- print("not call")
        tab[field.field_name] = item
      else
        -- print(field.field_type, field.field_name, item, call(item), item == null)
        tab[field.field_name] = call(item)
      end
    end
    result[#result+1] = tab
  end

  if again then
    if type(results) == 'table' and #results > 0 then
      results[#results+1] = result
      return read_response(self, results)
    else
      return read_response(self, { result })
    end
  end

  if results then
    results[#results+1] = result
  end
  return results or result
end

local function send_packet (self, request)
  self.packet_no = self.packet_no + 1
  return sock_write(self, strpack("<I3B", #request, self.packet_no & 255) .. request)
end

local function get_ignore_field(self, num)
  if num > 0 then
    for _ = 1, num do
      local len = read_head(self)
      if not len then
        return false
      end
      sock_read(self, len)
    end
    local len = read_head(self)
    if not sock_read(self, len) then
      return false
    end
  end
  return true
end

local function read_prepare_response(self)
  local packet = read_packet(self)
  if not packet then
    self.state = nil
    return nil, "1. mysql server closed when client sended query packet."
  end
  -- 预编译status只有OK或ERROR
  local status = strbyte(packet, 1)
  if status == RESP_ERROR then
    return nil, get_mysql_error_packet(packet:sub(2))
  end
  if status ~= RESP_OK then
    return nil, "2. Invalid mysql prepare protocol."
  end
  local info = {}
  info.sid, info.fields, info.params, info.warnings = strunpack("<I4I2I2BI2", packet:sub(2))
  if not get_ignore_field(self, info.fields) or not get_ignore_field(self, info.params) then
    self.state = nil
    return nil, "3. mysql server closed when client get response."
  end
  return info
end

local function read_execute_reponse(self)
  local packet = read_packet(self)
  if not packet then
    self.state = nil
    return nil, "1. mysql server closed when client sended query packet."
  end
  local err
  local status = strbyte(packet, 1)
  if status == RESP_ERROR then
    return nil, get_mysql_error_packet(packet:sub(2))
  end
  -- 如果直接返回成功
  if status == RESP_OK then
    return get_ok(packet:sub(2), #packet - 1), nil
  end

  local fields = new_tab(status, 0)
  for index = 1, status do
    local field, err = get_field(self)
    if not field then
      self.state = nil
      return nil, err
    end
    fields[index] = field
  end

  local len = read_head(self)
  if not len then
    self.state = nil
    return nil, "2. mysql server closed when client sended query packet."
  end
  status, err = read_status(self)
  if not status then
    self.state = nil
    return nil, err
  end

  get_eof(self, len - 1)
  -- if sever.status_flags & SERVER_MORE_RESULTS == SERVER_MORE_RESULTS then
  --   again = true
  -- end
  -- var_dump(sever)

  local rows = new_tab(32, 0)
  while 1 do
    packet, err = read_packet(self)
    if not packet then
      self.state = nil
      return nil, err
    end
    local b = strbyte(packet, 1)
    if b == RESP_EOF and #packet < 9 then
      get_eof_packet(packet)
      -- if sever.status_flags & SERVER_MORE_RESULTS == SERVER_MORE_RESULTS then
      --   again = true
      -- end
      break
    end
    if b == RESP_ERROR then
      return nil, get_mysql_error_packet(packet:sub(2))
    end
    rows[#rows+1] = get_bin_rows(packet, fields)
  end
  -- var_dump(rows)
  return rows
end

local function mysql_login (self)

  if self.unixdomain then
    if not self.sock:connect_ex(self.unixdomain or "") then
      return nil, "MySQL Server [" .. tostring(self.unixdomain) .. "] Connect failed."
    end
  elseif self.host and self.port then
    if not self.sock:connect(self.host, self.port) then
      return nil, "MySQL Server TCP Connect failed."
    end
  else
    return nil, "MySQL Server driver Invalid Configure."
  end

  -- Socket Stream Wrapper.
  self.sock = stream(self.sock)

  local len, err, packet
  len, err = read_head(self)
  if not len then
    return nil, err
  end

  packet, err = read_body(self, len)
  if not packet then
    return nil, err
  end

  local protocol, version, tid, salt, salt_len, auth_plugin, pos
  protocol, pos = strunpack("<B", packet, pos)
  if protocol == 0xff then
    return false, strformat('{errcode = %d, info = "%s"}', strunpack("<I2", packet, pos), packet:sub(pos + 1))
  end
  version, tid, pos = strunpack("<zI4", packet, pos)

  salt, pos = strunpack("<z", packet, pos)
  -- print("salt part 1: ", crypt.hexencode(salt))
  -- 这里我们直接忽略服务器权能、状态、字符集
  pos = pos + 7
  -- 拿到salt总长度
  salt_len, pos = strunpack("<B", packet, pos)
  if #salt + 1 < salt_len then
    local salt_part
    salt_part, pos = strunpack("<z", packet, pos + 10)
    salt = salt .. salt_part
    -- print("salt: ", crypt.hexencode(salt))
  end
  -- 检查auth_plugin后决定使用什么验证方式
  auth_plugin, pos = strunpack("<z", packet, pos)
  -- print("auth_plugin: ", auth_plugin)

  local client_flags = 260047
  local token, req
  if auth_plugin == "caching_sha2_password" then
    client_flags = client_flags | 0x80000 | 0x200000
    token = caching_sha2_password(self.password, salt)
    req = strpack("<I4I4Bc23zs1zz", client_flags, self.max_packet_size, CHARSET_MAP[self.charset] or 33, strrep("\0", 23), self.username, token, self.database, "caching_sha2_password")
  else
    token = mysql_native_password(self.password, salt)
    req = strpack("<I4I4Bc23zs1z", client_flags, self.max_packet_size, CHARSET_MAP[self.charset] or 33, strrep("\0", 23), self.username, token, self.database)
  end

  local ok = send_packet(self, req)
  if not ok then
    return nil, "mysql client send packet was failed."
  end

  local packet, err = read_packet(self)
  if not packet then
    return nil, "mysql server closed when client sended login packet."
  end

  local status, method = strbyte(packet, 1), strbyte(packet, 2)


  -- Already Auth Success.
  if status == 0x01 and method == 0x03 then
    packet, err = read_packet(self)
    if not packet then
      return nil, err
    end
    status, method = strbyte(packet, 1), strbyte(packet, 2)
  elseif status ~= RESP_ERROR then
    -- specify auth method switch algorithm : caching_sha2_password / mysql_native_password
    -- 1. Auth Plugin Need caching_sha2_password
    if status == 0x01 and method == 0x04 then
      self.packet_no = self.packet_no + 1
      send_packet(self, '\x02')
      local public_key, err = read_packet(self)
      if not public_key then
        return nil, err
      end
      self.packet_no = self.packet_no + 1
      send_packet(self, rsa_encode(public_key:sub(2, -2), self.password .. "\x00", salt))
      packet, err = read_packet(self)
      if not packet then
        return nil, err
      end
    end

    -- 2. Auth Plugin Need mysql_native_password
    if status == 0xFE then
      local auth_plugin, pos = strunpack("z", packet, 2)
      if auth_plugin == "mysql_native_password" then
        self.packet_no = self.packet_no + 1
        send_packet(self, mysql_native_password(self.password, strunpack("<z", packet, pos)))
      elseif auth_plugin == "sha256_password" then
        self.packet_no = self.packet_no + 1
        send_packet(self, '\x01')
        local public_key, err = read_packet(self)
        if not public_key then
          return nil, err
        end
        self.packet_no = self.packet_no + 1
        send_packet(self, rsa_encode(public_key:sub(2, -2), self.password .. "\x00", strunpack("<z", packet, pos)))
      else
        return nil, "1. MySQL Authentication protocol not supported: " .. (auth_plugin or "unknown")
      end
      packet, err = read_packet(self)
      if not packet then
        return nil, err
      end
    end

    status, method = strbyte(packet, 1), strbyte(packet, 2)
  end

  -- Server Send Error Response.
  if status == RESP_ERROR then
    return nil, get_mysql_error_packet(packet:sub(2))
  end

  -- 不支持的协议.
  if status ~= RESP_OK then
    return nil, "2. MySQL Authentication protocol not supported."
  end

  self.sever = { protocol = protocol, version = version, tid = tid, auth_plugin = auth_plugin, status = get_ok(packet:sub(2), #packet - 1) }
  self.state = "connected"
  -- var_dump(self.sever)
  return true
end

local function _set_length_coded_bin(buf)
  local n = #buf
  if n < 251 then
    return strpack("s1", buf)
  end

  if n < 65536 then
    return strpack("<Bs2", 0xfc, buf)
  end

  if n < 16777216 then
    return strpack("<Bs3", 0xfd, buf)
  end

  return strpack("<Bs8", 0xfe, buf)
end

local fmap = {
  ['number'] = function(v)
    if mtype(v) == "float" then
      return '\x05\x00', strpack("<d", v)
    else
      return '\x08\x00', strpack("<i8", v)
    end
  end,
  ['string'] = function(v)
    return '\x0f\x00', _set_length_coded_bin(v)
  end,
  ['boolean'] = function(v)
    return '\x01\x00', v and '\x01' or '\x00'
  end,
  ['nil'] = function(_)
    return '\x06\x00', ''
  end,
  ['userdata'] = function (_)
    return '\x06\x00', ''
  end
}

local function mysql_execute(self, opt, ...)
  local args = tpack(...)
  local argn = args.n
  if argn ~= opt.params then
    return nil, "There is a mismatch in the number of arguments."
  end
  local sql = strpack("<BI4BI4", COM_STMT_EXECUTE, opt.sid, CURSOR_TYPE_NO_CURSOR, 0x01)
  if argn > 0 then
    local field_index = 1
    local null_map = ""
    local null_count = (argn + 7) // 8
    -- null-bitmap 必须检查正确.
    for _ = 1, null_count do
      local nbyte = 0
      for offset = 0, 7 do
        if field_index <= argn then
          local v = args[field_index]
          nbyte = nbyte | (((v == nil or type(v) == 'userdata') and 1 or 0) << offset)
        end
        field_index = field_index + 1
      end
      null_map = null_map .. strchar(nbyte)
    end
    local tb_idx, vb_idx = 1, 1
    local types_buf, values_buf = new_tab(16, 0), new_tab(16, 0)
    for i = 1, argn, 1 do
      local v = args[i]
      local f = fmap[type(v)]
      if not f then
        error("invalid parameter type :" .. type(v))
      end
      types_buf[tb_idx], values_buf[vb_idx] = f(v)
      tb_idx, vb_idx = tb_idx + 1, vb_idx + 1
    end
    sql = concat{sql, null_map, '\x01', concat(types_buf), concat(values_buf)}
  end
  send_packet(self, sql)
  return read_execute_reponse(self)
end

local function mysql_prepare(self, stmt)
  send_packet(self, strpack("<B", COM_STMT_PREPARE) .. stmt)
  return read_prepare_response(self)
end

local function mysql_query (self, sql)
  send_packet(self, strpack("<B", CMD_QUERY) .. sql)
  return read_response(self)
end

local class = require "class"

local mysql = class("mysql")

function mysql:ctor (opt)
  self.sock = tcp:new()
  self.host = opt.host or "localhost"
  self.port = opt.port or 3306
  self.unixdomain = opt.unixdomain
  self.max_packet_size = 16777215
  self.charset = opt.charset or 33
  self.database = opt.database or "mysql"
  self.username = opt.username or "root"
  self.password = opt.password or "root"
  self.packet_no = 0
  self.stmts = {}
  -- self.state = "connected"
end

function mysql:connect ()
  local sock = self.sock
  if not sock then
    return nil, "not initialized"
  end
  return mysql_login(self)
end

function mysql:write (data)
  return self.sock:send(data)
end

function mysql:query (sql)
  self.packet_no = -1
  return mysql_query(self, sql)
end

function mysql:execute(stmt, ...)
  local info, errinfo = self.stmts[stmt], nil
  if not info then
    self.packet_no = -1
    info, errinfo = mysql_prepare(self, stmt)
    if not info then
      return false, errinfo
    end
    self.stmts[stmt] = info
  end
  self.packet_no = -1
  return mysql_execute(self, info, ...)
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

function mysql.quote_sql_str (sql)
  return strformat("%s", strgsub(sql, "[\0\b\n\r\t\26\\\'\"]", escape_map))
end

function mysql:set_timeout(timeout)
  if self.sock and tonumber(timeout) then
    self.sock:timeout(timeout)
  end
end

function mysql:close()
  local sock = self.sock
  if not sock then
    return
  end
  if self.state then
    sock:send(strpack("<I3BB", 1, 0, CMD_QUIT))
  end
  self.sock = nil
  self.state = nil
  return sock:close()
end

return mysql
