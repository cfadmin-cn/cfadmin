--[[
  LICENSE: BSD
  Author: CandyMi[https://github.com/candymi]
]]

local tcp = require "internal.TCP"

local crypt = require "crypt"
local hexencode = crypt.hexencode

local sys = require "sys"
local now = sys.now
local new_tab = sys.new_tab
local hostname = sys.hostname

local null = null
local type = type
local pcall = pcall
local error = error
local strpack = string.pack
local strunpack = string.unpack

local strchar = string.char
local strbyte = string.byte

local fmt = string.format
local strgsub = string.gsub
local strsub = string.sub

local toint = math.tointeger
local ceil = math.ceil
local random = math.random

local os_date = os.date
local os_time = os.time

local tabconcat = table.concat

-- TDS公共头部类型

local PTYPE_QUERY = 0x01 -- 回应包类型

local PTYPE_RESPONSE = 0x04 -- 回应包类型

local PTYPE_LOGIN = 0x10 -- TDS-7.0 登录类型

-- TDS控制TOKEN类型

local ORDER_TOKEN = 0xA9

local ERROR_TOKEN = 0xAA

local INFO_TOKEN = 0xAB

local ACK_TOKEN = 0xAD

local ENVCHANGE_TOKEN = 0xE3

local COLMETADATA_TOKEN = 0x81

local COLMETAROW_TOKEN = 0xD1

local COLMETAROW_TOKEN = 0xD1

local DONE_TOKEN = 0xFD

-- TDS ENVCHANGE 字段表
local TDS_ENV = {
  "Database",
  "Language",
  "Character_set",
  "Packet_size",
  "Unicode_sorting_local_id",
  "Unicode_sorting_comparison_flags",
  "SQL_Collation",
  "Begin_Transaction (described in [MSDN-BEGIN])",
  "Commit_Transaction (described in [MSDN-COMMIT])",
  "Rollback_Transaction",
  "Enlist_DTC_Transaction",
  "Defect_Transaction",
  "Real_Time_Log_Shipping",
  "Promote_Transaction",
  "Transaction_Manager_Address",
  "Transaction_ended",
  "Acknowledgement",
  "BackInfo",
  "Routing",
}

-- TDS字符集之间的转换兼容函数

-- 引入libiconv库实现 USC-2LE 与 UTF8 之间的转换
local liconv, liconv_to, liconv_from
local ok, liconv_info = pcall(require, "liconv")
if ok then
  liconv = liconv_info
  liconv_to, liconv_from = liconv.to, liconv.from
end

local function iconv_to (str, opcode)
  return liconv and liconv_to(opcode, str) or str
end

local function iconv_from (str, opcode)
  return liconv and liconv_from(opcode, str) or str
end

local function to_usc2le (s)
  return strpack("z", s)
end

local function from_usc2le (s)
  local tab = new_tab(#s / 2, 0)
  for index = 1, #s, 2 do
    tab[#tab+1] = strchar(strbyte(s, index))
  end
  return tabconcat(tab)
end

local function TO_UCS2LE (s)
  return liconv and iconv_to(s, "UCS-2LE") or strgsub(s, ".", to_usc2le)
end

local function FROM_UCS2LE(s)
  return liconv and iconv_from(s, "UCS-2LE") or from_usc2le(s)
end

--[[
加密算法原理:
  1. 对每个字符同时进行高/低位位移(4位);
  2. 将位移后的结果高位与低位进行"或"运算;
  3. 再将之后的运算结果异或0xA5(10100101);
  4. 最终的结果按位"与"0xFF取范围0~255;
C 函数原型:
uint8_t* tds7_crypt_pass(const uint8_t *clear_pass, int len, uint8_t *crypt_pass) {
  for (int i = 0; i < len; i++)
    crypt_pass[i] = ((clear_pass[i] << 4) | (clear_pass[i] >> 4)) ^ 0xA5;
  return crypt_pass;
}
--]]
local function password_encrypt(password)
  return strgsub(password, ".", function (ch)
    return strchar(((strbyte(ch) << 4 | strbyte(ch) >> 4) ~ 0xA5 ) & 0xff)
  end)
end

-- TDS数据类型(N的位置不固定是因为官方文档命名的问题)
local TYPE_BITN = 0x68       -- (104) BITN
local TYPE_BIT = 0x32        -- (50) BIT

local TYPE_INTN = 0x26       -- (38) INTN
local TYPE_INT1 = 0x30       -- (48) INT1
local TYPE_INT2 = 0x34       -- (54) INT2
local TYPE_INT4 = 0x38       -- (56) INT4
local TYPE_INT8 = 0x7F       -- (127) INT8

local TYPE_FLOAT32 = 0x3B    -- (59) Float32
local TYPE_FLOAT64 = 0x3E    -- (62) Float64
local TYPE_DECIMAL = 0x6A    -- (106) Decimal
local TYPE_NUMERIC = 0x6C    -- (108) Numeric
local TYPE_FLOATN = 0x6D     -- (109) float32/64

local TYPE_MONEY8 = 0x3C     -- (60)  Money
local TYPE_MONEY4 = 0x7A     -- (122) SmallMoney
local TYPE_MONEYN = 0x6E     -- (110) NMoney

local TYPE_BIGBIN = 0xAD     -- (173) NBINARY
local TYPE_CHAR = 0xAF       -- (175) Char
local TYPE_VARCHAR = 0xA7    -- (167) VarChar
local TYPE_NVARCHAR = 0xE7   -- (231) NVarChar
local TYPE_NCHAR = 0xEF      -- (239) NChar
local TYPE_TEXT = 0x23       -- (35) TEXT
local TYPE_NTEXT = 0x63      -- (99) NTEXT

local TYPE_DATETIMEN = 0x6F  -- (111) DATETIME

local TYPE_GEO = 0x22   -- (34) GEO

local TYPE_GUID = 0x24  -- (36) GUID

local TYPE_HIER = 0xA5 -- (165) Hierarchyid

-- TDS Field转换方法
local FTYPE_TAB = {}

FTYPE_TAB[TYPE_HIER] = function (packet, pos)
  return pos + 2
end

FTYPE_TAB[TYPE_GUID] = function (packet, pos)
  return pos + 1
end

FTYPE_TAB[TYPE_GEO] = function (packet, pos)
  local large_type_size, table_name_len
  large_type_size, table_name_len, pos = strunpack("<I4I2", packet, pos)
  return pos + table_name_len * 2
end

FTYPE_TAB[TYPE_BITN] = function (packet, pos)
  return pos + 1
end

FTYPE_TAB[TYPE_BIT] = function (packet, pos)
  return pos
end

FTYPE_TAB[TYPE_INTN] = function (packet, pos)
  return pos + 1
end

FTYPE_TAB[TYPE_INT1] = function (packet, pos)
  return pos
end

FTYPE_TAB[TYPE_INT2] = function (packet, pos)
  return pos
end

FTYPE_TAB[TYPE_INT4] = function (packet, pos)
  return pos
end

FTYPE_TAB[TYPE_INT8] = function (packet, pos)
  return pos
end

FTYPE_TAB[TYPE_BIGBIN] = function (packet, pos)
  return pos + 2
end

FTYPE_TAB[TYPE_CHAR] = function (packet, pos)
  -- local large_type_size, collate_codepage, collate_flags, collate_charset_id
  -- large_type_size, collate_codepage, collate_flags, collate_charset_id, pos = strunpack("<I2I2I2B", packet, pos)
  -- return pos
  return pos + 7
end

FTYPE_TAB[TYPE_NCHAR] = function (packet, pos)
  -- local large_type_size, collate_codepage, collate_flags, collate_charset_id
  -- large_type_size, collate_codepage, collate_flags, collate_charset_id, pos = strunpack("<I2I2I2B", packet, pos)
  -- return pos
  return pos + 7
end

FTYPE_TAB[TYPE_VARCHAR] = function (packet, pos)
  -- local large_type_size, collate_codepage, collate_flags, collate_charset_id
  -- large_type_size, collate_codepage, collate_flags, collate_charset_id, pos = strunpack("<I2I2I2B", packet, pos)
  -- return pos
  return pos + 7
end

FTYPE_TAB[TYPE_NVARCHAR] = function (packet, pos)
  -- local large_type_size, collate_codepage, collate_flags, collate_charset_id
  -- large_type_size, collate_codepage, collate_flags, collate_charset_id, pos = strunpack("<I2I2I2B", packet, pos)
  -- return pos
  return pos + 7
end

FTYPE_TAB[TYPE_TEXT] = function (packet, pos)
  local large_type_size, collate_codepage, collate_flags, collate_charset_id, table_name_len
  large_type_size, collate_codepage, collate_flags, collate_charset_id, pos = strunpack("<I4I2I2B", packet, pos)
  table_name_len, pos = strunpack("<I2", packet, pos)
  return pos + table_name_len * 2
end

FTYPE_TAB[TYPE_NTEXT] = function (packet, pos)
  local large_type_size, collate_codepage, collate_flags, collate_charset_id, table_name_len
  large_type_size, collate_codepage, collate_flags, collate_charset_id, pos = strunpack("<I4I2I2B", packet, pos)
  table_name_len, pos = strunpack("<I2", packet, pos)
  return pos + table_name_len * 2
end

FTYPE_TAB[TYPE_FLOAT32] = function (packet, pos)
  return pos
end

FTYPE_TAB[TYPE_FLOAT64] = function (packet, pos)
  return pos
end

FTYPE_TAB[TYPE_DECIMAL] = function (packet, pos)
  local type_size, precision, scale
  type_size, precision, scale, pos = strunpack("<BBB", packet, pos)
  return pos, precision, scale
end

FTYPE_TAB[TYPE_NUMERIC] = function (packet, pos)
  local type_size, precision, scale
  type_size, precision, scale, pos = strunpack("<BBB", packet, pos)
  return pos, precision, scale
end

FTYPE_TAB[TYPE_FLOATN] = function (packet, pos)
  return pos + 1
end

FTYPE_TAB[TYPE_MONEYN] = function (packet, pos)
  return pos + 1
end

FTYPE_TAB[TYPE_MONEY4] = function (packet, pos)
  return pos
end

FTYPE_TAB[TYPE_MONEY8] = function (packet, pos)
  return pos
end

FTYPE_TAB[TYPE_DATETIMEN] = function (packet, pos)
  return pos + 1
end

-- TDS Rows内容转换方法
local RTYPE_TAB = {}

RTYPE_TAB[TYPE_HIER] = function (packet, pos)
  local len
  len, pos = strunpack("<I2", packet, pos)
  if len == 0xFFFF then
    return null, pos
  end
  return "0x" .. hexencode(strsub(packet, pos, pos + len - 1):reverse()), pos + len
end

RTYPE_TAB[TYPE_GEO] = function (packet, pos)
  local len
  len, pos = strunpack("<B", packet, pos)
  if len == 0 then
    return null, pos
  end
  pos = pos + len + 8
  len, pos = strunpack("<I4", packet, pos)
  return "0x" .. hexencode(strsub(packet, pos, pos + len - 1):reverse()), pos + len
end

RTYPE_TAB[TYPE_GUID] = function (packet, pos)
  local len
  len, pos = strunpack("<B", packet, pos)
  if len == 0 then
    return null, pos
  end
  return tabconcat({
    fmt("%02X", strunpack("<I4", packet, pos)),
    fmt("%02X", strunpack("<I2", packet, pos + 4)),
    fmt("%02X", strunpack("<I2", packet, pos + 6)),
    fmt("%02X", strunpack(">I2", packet, pos + 8)),
    fmt("%02X", strunpack(">I6", packet, pos + 10))
  }, "-"), pos + 16
end

RTYPE_TAB[TYPE_BIT] = function (packet, pos)
  local value
  value, pos = strunpack("<B", packet, pos)
  return value == 1 and true or false, pos
end

RTYPE_TAB[TYPE_BITN] = function (packet, pos)
  local len, value
  len, pos = strunpack("<B", packet, pos)
  if len == 0 then
    return null, pos
  end
  value, pos = strunpack("<B", packet, pos)
  return value == 1 and true or false, pos
end

RTYPE_TAB[TYPE_INTN] = function (packet, pos)
  local len, value
  len, pos = strunpack("<B", packet, pos)
  if len == 1 then
    value, pos = strunpack("<i1", packet, pos)
  elseif len == 2 then
    value, pos = strunpack("<i2", packet, pos)
  elseif len == 4 then
    value, pos = strunpack("<i4", packet, pos)
  elseif len == 8 then
    value, pos = strunpack("<i8", packet, pos)
  else
    return null, pos
  end
  return value, pos
end

RTYPE_TAB[TYPE_INT1] = function (packet, pos)
  return strunpack("<i1", packet, pos)
end

RTYPE_TAB[TYPE_INT2] = function (packet, pos)
  return strunpack("<i2", packet, pos)
end

RTYPE_TAB[TYPE_INT4] = function (packet, pos)
  return strunpack("<i4", packet, pos)
end

RTYPE_TAB[TYPE_INT8] = function (packet, pos)
  return strunpack("<i8", packet, pos)
end

RTYPE_TAB[TYPE_BIGBIN] = function (packet, pos)
  local len
  len, pos = strunpack("<i2", packet, pos)
  if len == 0xFFFF then
    return null, pos
  end
  return strsub(packet, pos, pos + len - 1), pos + len
end

RTYPE_TAB[TYPE_CHAR] = function (packet, pos)
  local len
  len, pos = strunpack("<i2", packet, pos)
  return iconv_from(strsub(packet, pos, pos + len - 1), "GBK"), pos + len
end

RTYPE_TAB[TYPE_NCHAR] = function (packet, pos)
  local len
  len, pos = strunpack("<i2", packet, pos)
  return iconv_from(strsub(packet, pos, pos + len - 1), "UCS-2LE"), pos + len
end

RTYPE_TAB[TYPE_VARCHAR] = function (packet, pos)
  local len
  len, pos = strunpack("<i2", packet, pos)
  return iconv_from(strsub(packet, pos, pos + len - 1), "GBK"), pos + len
end

RTYPE_TAB[TYPE_NVARCHAR] = function (packet, pos)
  local len
  len, pos = strunpack("<i2", packet, pos)
  return iconv_from(strsub(packet, pos, pos + len - 1), "UCS-2LE"), pos + len
end

RTYPE_TAB[TYPE_TEXT] = function (packet, pos)
  local ptr_len, text_len
  ptr_len, pos = strunpack("<B", packet, pos)
  text_len, pos = strunpack("<I4", packet, pos + ptr_len + 8)
  return iconv_from(strsub(packet, pos, pos + text_len - 1), "GBK"), pos + text_len
end

RTYPE_TAB[TYPE_NTEXT] = function (packet, pos)
  local ptr_len, text_len
  ptr_len, pos = strunpack("<B", packet, pos)
  text_len, pos = strunpack("<I4", packet, pos + ptr_len + 8)
  return iconv_from(strsub(packet, pos, pos + text_len - 1), "UCS-2LE"), pos + text_len
end

RTYPE_TAB[TYPE_FLOAT32] = function (packet, pos)
  -- 精度: 小数点后6位
  return strunpack("<f", packet, pos) * 1e6 // 1 * 1e-6, pos + 4
end

RTYPE_TAB[TYPE_FLOAT64] = function (packet, pos)
  -- 精度: 小数点后20位
  return strunpack("<n", packet, pos)
end

RTYPE_TAB[TYPE_DECIMAL] = function (packet, pos, precision, scale)
  local len, sign, value
  len, pos = strunpack("<B", packet, pos)
  if len == 0 then
    return null, pos
  end
  sign, value, pos = strunpack("<Bi4", packet, pos)
  return value * (0.1 ^ scale) * (sign == 0x00 and -1 or 1), pos
end

RTYPE_TAB[TYPE_NUMERIC] = function (packet, pos, precision, scale)
  local len, sign, value
  len, pos = strunpack("<B", packet, pos)
  if len == 0 then
    return null, pos
  end
  sign, value, pos = strunpack("<Bi4", packet, pos)
  return value * (0.1 ^ scale) * (sign == 0x00 and -1 or 1), pos
end

RTYPE_TAB[TYPE_FLOATN] = function (packet, pos)
  local len, value
  len, pos = strunpack("<B", packet, pos)
  if len == 4 then
    value, pos = strunpack("<f", packet, pos)
    value = value * 1e3 // 1 * 1e-3
  elseif len == 8 then
    value, pos = strunpack("<n", packet, pos)
  else
    return null, pos
  end
  return value, pos
end

RTYPE_TAB[TYPE_MONEYN] = function (packet, pos)
  local len, value
  len, pos = strunpack("<B", packet, pos)
  if len == 4 then
    value, pos = strunpack("<i4", packet, pos)
    value = value * (0.1 ^ 4)
  elseif len == 8 then
    -- 请不要使用MONEY类型
    value, pos = strunpack("<n", packet, pos)
  else
    return null, pos
  end
  return value, pos
end

RTYPE_TAB[TYPE_MONEY4] = function (packet, pos)
  local value
  value, pos = strunpack("<i4", packet, pos)
  return  value * (0.1 ^ 4), pos
end

RTYPE_TAB[TYPE_MONEY8] = function (packet, pos)
  -- 请不要使用MONEY类型
  return strunpack("<n", packet, pos)
end

-- MSSQL要求起始时间必须为1900-1-1, 所以必须用算法求出当前日期的偏移值(这个偏移值必须再 + 343)
-- local DATETIME_OFFSET = os_time { year = 1900, month = 1, day = 1, hour = 0, min = 0, sec = 0 } + 343
local DATETIME_OFFSET = -2209017600

RTYPE_TAB[TYPE_DATETIMEN] = function (packet, pos)
  local len, value
  len, pos = strunpack("<B", packet, pos)
  if len == 4 then
    local v1, v2
    v1, v2, pos = strunpack("<I2I2", packet, pos)
    value = os_date("%F %X", v1 * 86400 + DATETIME_OFFSET + v2 * 60)
  elseif len == 8 then
    local v1, v2
    v1, v2, pos = strunpack("<I4I4", packet, pos)
    value = tabconcat {os_date("%F %X", v1 * 86400 + DATETIME_OFFSET + v2 / 300 // 1), fmt(".%03u", ((v2 / 300 * 1e3 - v2 / 300 // 1 * 1e3 ) + 0.5) // 1)}
  else
    return null, pos
  end
  return value, pos
end

--[[
公共协议头部:
  OPCODE  -  包类型(uint8)
  STATUS  -  包状态(uint8)
  LENGTH  -  包长度(uint16)
  CHANNEL -  此版本未使用, 所以默认为0(uint16)
  PACKNO  -  包序号(uint8)
  WINDOW  -  此版本未使用, 所以默认为0(uint8)
--]]
local function tds_pack_header(OP_CODE, STATUS, LENGTH, CHANNEL, PACKNO, WINDOW)
  return strpack(">BBI2I2BB", OP_CODE, STATUS, LENGTH, CHANNEL, PACKNO, WINDOW)
end

local function tds_unpack_header(packet)
  return strunpack(">BBI2I2BB", packet)
end

local function tds_login7( self )

  local HOSTNAME = hostname()
  -- print(HOSTNAME, #HOSTNAME)

  local APP_NAME = "cfadmin"
  -- print(APP_NAME, #APP_NAME)

  local LOCALE = "us_english"
  -- print(LOCALE, #LOCALE)

  local SERVER_NAME = self.host
  local DATABASE = self.database
  local USERNAME = self.username
  local PASSWORD = self.password

  local msg = {
    -- LOGIN 7 默认头部信息
    strpack("<I4", 0x71000001),                        -- TDS Version (7.1.1)
    strpack("<I4", self.max_packet_size ),             -- Packet Size (32767)
    strpack(">BBI2", 7, 1, 1),                         -- Client Version (7.1.1)
    strpack("<I4", math.random(100000, now() // 1)),   -- Client PID (uint32)
    strpack("<I4", 0),                                 -- Connection ID, Deafult 0  (uint32)
    strpack("<BB", 0xE0, 0x03),                        -- Option Flags 1 And 2. (uint8 And uint8)
    strpack("<B", self.TSQL, 0),                       -- SQL Type Flags, 0 = DEFAULT SQL, 1 = T-SQL (uint32)
    strpack("<B", 0),                                  -- Reserved Flags, Deafult 0  (uint32)
    strpack("<I4", 0xffffff88),                        -- Time Zone, Deafult 0xffffff88  (uint32)
    strpack("<I4", 0x00000436),                        -- Collation, Deafult 0x00000436  (uint32)
  }

  -- LOGIN 7 内容偏移值与长度
  local position = 86

  -- 客户端主机名
  msg[#msg+1] = strpack("<I2I2", position, #HOSTNAME)
  position = position + #HOSTNAME * 2

  -- 客户端登录账户
  msg[#msg+1] = strpack("<I2I2", position, #USERNAME)
  position = position + #USERNAME * 2

  -- 客户端登录密码
  msg[#msg+1] = strpack("<I2I2", position, #PASSWORD)
  position = position + #PASSWORD * 2

  -- 客户端应用名称
  msg[#msg+1] = strpack("<I2I2", position, #APP_NAME)
  position = position + #APP_NAME * 2

  -- 客户端服务名称
  msg[#msg+1] = strpack("<I2I2", position, #SERVER_NAME)
  position = position + #SERVER_NAME * 2

  -- 客户端远程账户与密码
  msg[#msg+1] = strpack("<I2I2", 0, 0)
  position = position + 0

  -- 客户端链接库名称
  msg[#msg+1] = strpack("<I2I2", position, 0)
  position = position + 0

  -- 客户端语言名称
  msg[#msg+1] = strpack("<I2I2", position, #LOCALE)
  position = position + #LOCALE * 2

  -- 客户端数据库名称
  msg[#msg+1] = strpack("<I2I2", position, #DATABASE)
  position = position + #DATABASE * 2

  -- 客户端MAC地址
  msg[#msg+1] = strpack("<BBBBBB", 0, 0, 0, 0, 0, 0)
  -- position = position + 6

  -- 客户端认证部分
  msg[#msg+1] = strpack("<I2I2", position, 0)
  position = position + 0

  -- 客户端指定DATA位置
  msg[#msg+1] = strpack("<I2I2", position, 0)
  position = position + 0

  msg[#msg+1] = TO_UCS2LE(HOSTNAME)

  msg[#msg+1] = TO_UCS2LE(USERNAME)

  msg[#msg+1] = password_encrypt(TO_UCS2LE(PASSWORD)) -- TO_UCS2LE(PASSWORD)

  msg[#msg+1] = TO_UCS2LE(APP_NAME)

  msg[#msg+1] = TO_UCS2LE(SERVER_NAME)

  msg[#msg+1] = TO_UCS2LE(LOCALE)

  msg[#msg+1] = TO_UCS2LE(DATABASE)

  local message = tabconcat(msg)

  return tabconcat {
    tds_pack_header(PTYPE_LOGIN, 0x1, #message + 12, 0, 0, 0),
    strpack("<I4", #message + 4),
    message,
  }
end

local function tds_read_head (self)
  return self:read(8)
end

local function tds_read_body (self, LENGTH)
  return self:read(LENGTH - 8)
end

local function tds_get_errorinfo(packet, p)
  local pkg_len, errorno, state, severity, pos = strunpack("<I2I4BB", packet, p or 2)
  local msg_len, pos = strunpack("<I2", packet, pos)
  -- print(pkg_len, errorno, state, severity, msg_len)
  local error_msg = FROM_UCS2LE(strsub(packet, pos, pos + msg_len * 2 - 1))
  local msg_len, pos = strunpack("<B", packet, pos + msg_len * 2)
  local server_name = FROM_UCS2LE(strsub(packet, pos, pos + msg_len * 2 - 1))
  local _, _, pos = strunpack("<BI2", packet, pos + msg_len * 2)
  return fmt("ERROR: {server_name = \"%s\", errno = \"%u\", errmsg = \"%s\"}", server_name, errorno, error_msg), pos
end

local function tds_get_meta_data(packet, length, pos)
  local fields = new_tab(length, 0)
  for i = 1, length do
    -- 字段属性
    local field_length, user_type, field_flags, field_type, precision, scale
    user_type, field_flags, field_type, pos = strunpack("<I2I2B", packet, pos)
    -- print(user_type, field_flags, field_type, pos)
    local f = FTYPE_TAB[field_type]
    if type(f) == 'function' then
      pos, precision, scale = f(packet, pos)
    else
      error("Error: Unknown field type [" .. field_type .. "] ")
    end
    local field_name = "?field_" .. i .. "?"
    field_length, pos = strunpack("<B", packet, pos)
    if field_length > 0 then
      field_name = FROM_UCS2LE(strsub(packet, pos, pos + field_length * 2 - 1))
      pos = pos + field_length * 2
    end
    fields[#fields+1] = { field_name = field_name, field_type = field_type, precision = precision, scale = scale }
  end
  return fields, pos
end

local function tds_get_row_data (packet, pos, fields)
  -- var_dump(fields)
  local rows = new_tab(#fields, 0)
  local value
  for index = 1, #fields do
    local field = fields[index]
    local f = RTYPE_TAB[field.field_type]
    -- print(pos)
    if type(f) == 'function' then
      value, pos = f(packet, pos, field.precision, field.scale)
    else
      error("Error: Unknown data type [" .. field.field_type .. "] ")
    end
    -- print(field.field_type, value, pos)
    rows[#rows+1] = value
  end
  return rows, pos
end

local function tds_done_to_tab(tab, status, operation, row_count)
  -- 这个值应该被忽略
  tab["DONE_OPERATION"] = operation
  -- 是否是最终的数据包
  tab["DONE_FINAL"] = status & 0x01 == 0x00 and true or false
  -- 是否还有其他数据包
  tab["DONE_MORE"] = status & 0x01 == 0x01 and true or false
  -- 是否是一个错误数据包
  tab["DONE_ERROR"] = status & 0x01 == 0x01 and true or false
  -- 是否正在处理一个事务
  tab["DONE_TRANSACTION"] = status & 0x04 == 0x04 and true or false
  -- TODO
  tab["DONE_COUNT"] = status & 0x10 == 0x10 and row_count or 0
  -- TODO
  tab["DONE_ATTN"] = status & 0x20 == 0x20 and true or false
end

local function tds_get_done (packet, pos)
  return strunpack("<I2I2I4", packet, pos)
end

local function tds_read_response(self, before_packets)
  local packet = tds_read_head(self)
  if not packet then
    self.state = nil
    return nil, "The server disconnected before receiving the response header."
  end

  local OPCODE, STATUS, LENGTH, CHANNEL, PACKNO, WINDOW  = tds_unpack_header(packet)
  if OPCODE ~= PTYPE_RESPONSE then
    self.state = nil
    return nil, "A protocol type not supported by TDS-7.0 was received."
  end
  local packet = tds_read_body(self, LENGTH)
  if not packet then
    self.state = nil
    return nil, "The server disconnected before receiving the response data."
  end

  -- print(LENGTH, #packet)
  if before_packets then
    before_packets[#before_packets+1] = packet
    if STATUS & 0x1 ~= 0x01 then
      return tds_read_response(self, before_packets)
    else
      packet = tabconcat(before_packets)
    end
  else
    if STATUS & 0x1 ~= 0x01 then
      return tds_read_response(self, { packet })
    end
  end

  local result = new_tab(32, 8)
  local pos = 1
  local fields, token_type, order, more_result, meta_field
  while 1 do
    token_type, pos = strunpack("<B", packet, pos)
    if token_type == COLMETADATA_TOKEN then
      local length
      length, pos = strunpack("<I2", packet, pos)
      fields, pos = tds_get_meta_data(packet, length, pos)
      meta_field = true
    elseif token_type == ERROR_TOKEN then
      local error_msg
      error_msg, pos = tds_get_errorinfo(packet, pos)
      if strunpack("<B", packet, pos) == INFO_TOKEN then
        local _, len
        _, len, pos = strunpack("<BI2", packet, pos)
        pos = pos + len
      end
      if strunpack("<B", packet, pos) == DONE_TOKEN then
        tds_get_done(packet, pos)
      end
      return nil, error_msg
    elseif token_type == COLMETAROW_TOKEN then
      local rows
      local len = #fields
      local tab = new_tab(0, len)
      rows, pos = tds_get_row_data(packet, pos, fields)
      for index = 1, #rows do
        tab[fields[index].field_name] = rows[index]
      end
      result[#result+1] = tab
    elseif token_type == DONE_TOKEN then
      local status, operation, row_count
      status, operation, row_count, pos = tds_get_done(packet, pos)
      if not meta_field then
        tds_done_to_tab(result, status, operation, row_count)
        result["order"] = order
      end
      meta_field = false
      -- 设置MORE_RESULT标志位
      if not more_result then
        more_result = new_tab(3, 0)
      end
      more_result[#more_result + 1] = result
      result = new_tab(32, 8)
      -- 如果后面还有数据, 则需要改变返回结构
      -- print(status & 0x01)
      if status & 0x01 ~= 0x01 then
        result = more_result or result
        -- 如果只有一条数据, 就直接返回那条数据结构
        if #result == 1 then
          result = result[1]
        end
        break
      end
    elseif token_type == ORDER_TOKEN then
      local token_len, token_name_index
      token_len, token_name_index, pos = strunpack("<I2I2", packet, pos)
      local field = fields[token_name_index]
      order = { token_len = token_len, token_name = field and field.field_name }
      -- var_dump(order)
    end
  end
  return result
end

--[[
TDS 7.1.1支持2种查询格式
    1. TDS Header + Raw SQL
    2. TDS Header + Data Stream headers + Raw SQL
--]]
local function tds_query_and_response (self, sql)
  -- 此处为格式 1
  -- local tds_data = TO_UCS2LE(sql)
  -- 此处为格式 2
  local tds_data = strpack("<I4I4I2I4I4I4", 22, 18, 2, 0, 0, 1) .. TO_UCS2LE(sql)

  -- 支持分包
  if self.max_packet_size >= #tds_data then
    self:write(tds_pack_header(PTYPE_QUERY, 0x01, #tds_data + 8, 0, 1, 0) .. tds_data)
  else
    local fin = 0x00
    while 1 do
      local body = strsub(tds_data, 1, self.max_packet_size)
      if #tds_data <= self.max_packet_size then
        fin = 0x01
      end
      self:write(tds_pack_header(PTYPE_QUERY, fin, #body + 8, 0, 1, 0) .. body)
      if fin == 0x01 then
        break
      end
      tds_data = strsub(tds_data, self.max_packet_size + 1, -1)
    end
  end
  return tds_read_response(self)
end

local class = require "class"

local mssql = class("mssql")

function mssql:ctor(opt)
  self.sock = tcp:new()
  self.host = opt.host or "localhost"
  self.port = opt.port or 1433
  self.TSQL = opt.TSQL == 1 and 1 or 0
  self.max_packet_size = opt.max_packet_size or 10240
  self.database = opt.database or "master"
  self.username = opt.username or "sa"
  self.password = opt.password
  -- self.state = "connected"
end

function mssql:read( bytes )
  local buffers = new_tab(32, 0)
  local sock = self.sock
  while 1 do
    local data
    if sock.ssl then
      data = sock:ssl_recv(bytes)
    else
      data = sock:recv(bytes)
    end
    if not data then
      return nil, "server close this session."
    end
    buffers[#buffers+1] = data
    bytes = bytes - #data
    if bytes <= 0 then
      break
    end
  end
  return tabconcat(buffers)
end

function mssql:write(data)
  return self.sock:send(data)
end

function mssql:connect( ... )
  if not self.sock then
    return nil, "Connection failed: please recreate the socket object."
  end

  local ok, err = self.sock:connect(self.host, self.port)
  if not ok then
    return nil, err
  end

  -- 发送TDS-7.0登录协议
  self:write(tds_login7(self))

  local packet = tds_read_head(self)
  if not packet then
    return nil, "1. After sending the LOGIN data, the server disconnected."
  end

  local OPCODE, STATUS, LENGTH, CHANNEL, PACKNO, WINDOW  = tds_unpack_header(packet)
  if OPCODE ~= PTYPE_RESPONSE then
    return nil, "A protocol type not supported by TDS-7.0 was received."
  end

  local packet = tds_read_body(self, LENGTH)
  if not packet then
    return nil, "2. After sending the LOGIN data, the server disconnected."
  end

  local sever = new_tab(0, 6)
  local pos = 1
  while 1 do
    local token_type
    token_type, pos = strunpack("<B", packet, pos)
    -- 登录失败
    if token_type == ERROR_TOKEN then
      return nil, tds_get_errorinfo(packet)
    end
    if token_type ~= INFO_TOKEN and token_type ~= ENVCHANGE_TOKEN and token_type ~= ACK_TOKEN and token_type ~= DONE_TOKEN then
      return nil, "Unsupported login response type, please check the MSSQL server version."
    end
    if token_type == ENVCHANGE_TOKEN then
      local len, env_type
      local new_value, new_len, old_value, old_len, collate_codepage, collate_flags, collate_charset_id
      len, pos = strunpack("<I2", packet, pos)
      env_type, pos = strunpack("<B", packet, pos)
      new_len, pos = strunpack("<B", packet, pos)
      local type_name = TDS_ENV[env_type] or "Unknown Type"
      if new_len > 0 then
        if env_type ~= 0x07 then
          new_value = FROM_UCS2LE(strsub(packet, pos, pos + new_len * 2 - 1))
          pos = pos + new_len * 2
        else
          collate_codepage, collate_flags, collate_charset_id, pos = strunpack("<I2I2B", packet, pos)
        end
      end
      old_len, pos = strunpack("<B", packet, pos)
      if old_len > 0 then
        old_value = FROM_UCS2LE(strsub(packet, pos, pos + old_len * 2 - 1))
        pos = pos + old_len * 2
      end
      sever[type_name] = {
        new_value = new_value,
        old_value = old_value,
        collate_codepage = collate_codepage,
        collate_flags = collate_flags,
        collate_charset_id = collate_charset_id
      }
      -- return sever
    elseif token_type == INFO_TOKEN then
      local info
      info, pos = tds_get_errorinfo(packet, pos)
    elseif token_type == ACK_TOKEN then
      local len, interface, tds_version, server_name_len, server_name, server_version_max1, server_version_max2, server_version_min
      len, pos = strunpack("<I2", packet, pos)
      interface, tds_version, server_name_len, pos = strunpack("<BI4B", packet, pos)
      -- print(len, interface, tds_version)
      server_name = FROM_UCS2LE(strsub(packet, pos, pos + server_name_len * 2 - 1))
      pos = pos + server_name_len * 2
      server_version_max1, server_version_max2, server_version_min, pos = strunpack("<BBI2", packet, pos)
      -- print(server_version_max1, server_version_max2, server_version_min, pos)
      sever["server_name"] = server_name
      sever["server_version"] = fmt("%u.%u.%u", server_version_max1, server_version_max2, server_version_min)
      -- return sever
    elseif token_type == DONE_TOKEN then
      local status, operation, count
      status, operation, count = strunpack("<I2I2I4", packet, pos)
      sever["status"] = status
      sever["operation"] = operation
      sever["row_count"] = count
      break
    end
    -- var_dump(sever)
  end
  -- var_dump(sever)
  self.max_packet_size = (sever.Packet_size and toint(sever.Packet_size.new_value) or toint(self.max_packet_size)) - 8
  self.sever = sever
  self.state = "connected"
  return true
end

function mssql:query (sql)
  if type(sql) ~= 'string' or sql == '' then
    return nil, "Fatal error: invalid SQL statement or parameter."
  end
  return tds_query_and_response(self, sql)
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

function mssql.quote_to_str (sql)
  return fmt("%s", string.gsub(sql, "[\0\b\n\r\t\26\\\'\"]", escape_map))
end

function mssql:set_timeout(timeout)
  if self.sock and tonumber(timeout) then
    self.sock._timeout = timeout
  end
end

function mssql:close ()
  if self.sock then
    self.sock:close()
    self.sock = nil
  end
end

return mssql
