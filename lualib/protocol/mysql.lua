--[[
  LICENSE: BSD
  Author: CandyMi[https://github.com/candymi]
]]

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
local strrep = string.rep
local strunpack = string.unpack
local strpack = string.pack
local assert = assert
local tonumber = tonumber
local toint = math.tointeger
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
  local sock = self.sock
	local buffer = sock:recv(bytes)
	if not buffer then
		return
	end
	if #buffer == bytes then
		return buffer
	end
	bytes = bytes - #buffer
	local buffers = {buffer}
  local sock_recv = sock.recv
	while 1 do
		buffer = sock_recv(sock, bytes)
		if not buffer then
			return
		end
    bytes = bytes - #buffer
    insert(buffers, buffer)
		if bytes == 0 then
			return concat(buffers)
		end
	end
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
  return { field_name = name, field_type = type, field_len = length }
end

local function get_rows (packet, quantity)
  local row = new_tab(quantity, 0)
  local row_info, pos = nil, 1
  for i = 1, quantity do
    row_info, pos = get_lenenc_str(packet, pos)
    row[#row+1] = row_info
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
  local packet, err = read_body(self, len)
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
  local packet, err = read_packet(self)
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
    fields[#fields+1] = field
  end

  local again = false
  local len, err = read_head(self)
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
    local packet, err = read_packet(self)
    if not packet then
      self.state = nil
      return nil, err
    end
    if strbyte(packet, 1) == RESP_EOF and #packet < 9 then
      local sever = get_eof_packet(packet)
      if sever.status_flags & SERVER_MORE_RESULTS == SERVER_MORE_RESULTS then
        again = true
      end
      break
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

  local len, err = read_head(self)
  if not len then
    return nil, err
  end

  local packet, err = read_body(self, len)
  if not packet then
    return nil, err
  end

  local protocol, version, tid, salt, salt_len, auth_plugin, pos
  protocol, version, tid, pos = strunpack("<BzI4", packet, pos)
  -- print(protocol, version, tid, pos)

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
    self.sock._timeout = timeout
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