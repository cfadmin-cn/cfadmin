local tcp = require "internal.TCP"
local crypt = require "crypt"
local sha1 = crypt.sha1
local sha2 = crypt.sha256
local xor_str = crypt.xor_str
local randomkey = crypt.randomkey_ex
local rsa_oaep_pkey_encode = crypt.rsa_public_key_oaep_padding_encode

local sub = string.sub
local find = string.find
local strgsub = string.gsub
local strformat = string.format
local strbyte = string.byte
local strchar = string.char
local strrep = string.rep
local strunpack = string.unpack
local strpack = string.pack
local setmetatable = setmetatable
local assert = assert
local select = select
local tonumber = tonumber
local toint = math.tointeger
local concat = table.concat

local null = null
local type = type
local pairs = pairs
local io_open = io.open
local io_remove = os.remove

local new_tab = require("sys").new_tab

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

local class = require "class"

local MySQL = class("MySQL")

local STATE_CONNECTED = 1
local STATE_COMMAND_SENT = 2

local COM_QUIT = 0x01
local COM_QUERY = 0x03

local COM_STMT_PREPARE = 0x16
local COM_STMT_EXECUTE = 0x17

local AUTH_SWITCH_OK = '\x01\x03'
local AUTH_SWITCH_CONTINUE = '\x01\x04'

local CURSOR_TYPE_NO_CURSOR = 0x00

local SERVER_MORE_RESULTS_EXISTS = 8

-- 16MB - 1, the default max allowed packet size used by libmysqlclient
local FULL_PACKET_SIZE = 16777215

-- mysql field value type converters
local converters = new_tab(0, 9)

for i = 0x01, 0x05 do
    -- tiny, short, long, float, double
    converters[i] = tonumber
end
converters[0x00] = tonumber  -- decimal
-- converters[0x08] = tonumber  -- long long
converters[0x09] = tonumber  -- int24
converters[0x0d] = tonumber  -- year
converters[0xf6] = tonumber  -- newdecimal

local function _get_byte1(data, i)
    return strbyte(data, i), i + 1
end

local function _get_byte2(data, i)
    return strunpack("<I2",data,i)
end

local function _get_byte3(data, i)
    return strunpack("<I3",data,i)
end

local function _get_byte4(data, i)
    return strunpack("<I4",data,i)
end

local function _get_byte8(data, i)
    return strunpack("<I8",data,i)
end

local function _set_byte2(n)
    return strpack("<I2", n)
end

local function _set_byte3(n)
    return strpack("<I3", n)
end

local function _set_byte4(n)
    return strpack("<I4", n)
end

local function _set_byte8(n)
    return strpack("<I8", n)
end

local function _set_double(n)
    return strpack("<d", n)
end

local function _from_cstring(data, i)
    return strunpack("z", data, i)
end

local function _dumphex(bytes)
    return strgsub(bytes, ".", function(x) return strformat("%02x ", strbyte(x)) end)
end

-- 原生密码认证
local function mysq_native_password(password, scramble)
    if not password or password == "" then
        return ""
    end
    local stage1 = sha1(password)
    local stage2 = sha1(scramble .. sha1(stage1))
    return xor_str(stage2, stage1)
end

-- 缓存sha2密码认证
local function caching_sha2_password(password, scramble)
    if not password or password == "" then
        return ""
    end
    local stage1 = sha2(password)
    local stage2 = sha2(sha2(stage1) .. scramble)
    return xor_str(stage1, stage2)
end

-- 扩展公钥认证
local function rsa_encode(public_key, password, scramble)
    local filename = randomkey(8, true) .. 'pem'
    local f = assert(io_open(filename, 'a'), "Can't Create public_key file to complate handshake.")
    f:write(public_key):flush()
    f:close()
    return rsa_oaep_pkey_encode(xor_str(password, scramble), filename), io_remove(filename)
end

local function _send_packet(self, req, size)
    local sock = self.sock

    self.packet_no = self.packet_no + 1

    local packet = _set_byte3(size) .. strchar(self.packet_no & 255) .. req

    return sock:send(packet)
end

local function sock_recv(sock, byte)
    local buffers = new_tab(32, 0)
    while 1 do
      local buf = sock:recv(byte)
      if not buf then
        return nil, "MySQL Server closed."
      end
      buffers[#buffers+1] = buf
      byte = byte - #buf
      if byte == 0 then
        return concat(buffers)
      end
    end
end


local function _recv_packet(self)
    local sock = self.sock

    local data, err = sock_recv(sock, 4) -- packet header
    if not data then
        self.state = nil
        return nil, nil, "failed to receive packet header: "..(err or "nil")
    end

    --print("packet header: ", _dump(data))

    local len, pos = _get_byte3(data, 1)

    --print("packet length: ", len)

    if len == 0 then
        return nil, nil, "empty packet"
    end

    -- if len > self._max_packet_size then
    --     return nil, nil, "packet size too big: " .. len
    -- end

    local num = strbyte(data, pos)

    --print("recv packet: packet no: ", num)

    self.packet_no = num

    local data, err = sock_recv(sock, len)
    if not data then
        self.state = nil
        return nil, nil, "failed to read packet content: "..(err or "nil")
    end

    local field_count, typ = strbyte(data, 1)
    if field_count == 0x00 then
        typ = "OK"
    elseif field_count == 0xff then
        typ = "ERR"
    elseif field_count == 0xfe then
        typ = "EOF"
    else
        typ = "DATA"
    end

    return data, typ
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
        return null, pos + 1
    end

    if first == 252 then
        pos = pos + 1
        return _get_byte2(data, pos)
    end

    if first == 253 then
        pos = pos + 1
        return _get_byte3(data, pos)
    end

    if first == 254 then
        pos = pos + 1
        return _get_byte8(data, pos)
    end

    return nil, pos + 1
end

local function _set_length_coded_bin(n)
    if n < 251 then
        return strchar(n)
    end

    if n < (1 << 16) then
        return strpack("<BI2", 0xfc, n)
    end

    if n < (1 << 24) then
        return strpack("<BI3", 0xfd, n)
    end

    return strpack("<BI8", 0xfe, n)
end

local function _from_length_coded_str(data, pos)
    local len
    len, pos = _from_length_coded_bin(data, pos)
    if not len or len == null then
        return null, pos
    end

    return sub(data, pos, pos + len - 1), pos + len
end


local function _parse_ok_packet(packet)
    local res = new_tab(0, 5)
    local pos

    res.affected_rows, pos = _from_length_coded_bin(packet, 2)

    --print("affected rows: ", res.affected_rows, ", pos:", pos)

    res.insert_id, pos = _from_length_coded_bin(packet, pos)

    --print("insert id: ", res.insert_id, ", pos:", pos)

    res.server_status, pos = _get_byte2(packet, pos)

    --print("server status: ", res.server_status, ", pos:", pos)

    res.warning_count, pos = _get_byte2(packet, pos)

    --print("warning count: ", res.warning_count, ", pos: ", pos)

    local message = _from_length_coded_str(packet, pos)
    if message and message ~= null then
        res.message = message
    end

    --print("message: ", res.message, ", pos:", pos)

    return res
end


local function _parse_eof_packet(packet)

    local warning_count, pos = _get_byte2(packet, 2)
    local status_flags = _get_byte2(packet, pos)

    return warning_count, status_flags
end


local function _parse_err_packet(packet)
    local errno, pos = _get_byte2(packet, 2)
    local marker = sub(packet, pos, pos)
    local sqlstate
    if marker == '#' then
        -- with sqlstate
        pos = pos + 1
        sqlstate = sub(packet, pos, pos + 5 - 1)
        pos = pos + 5
    end

    return errno, sub(packet, pos), sqlstate
end


local function _parse_result_set_header_packet(packet)
    local field_count, pos = _from_length_coded_bin(packet, 1)

    local extra
    extra = _from_length_coded_bin(packet, pos)

    return field_count, extra
end


local function _parse_field_packet(data)
    local col = new_tab(0, 2)
    local catalog, db, table, orig_table, orig_name, charsetnr, length
    local pos
    catalog, pos = _from_length_coded_str(data, 1)

    --print("catalog: ", col.catalog, ", pos:", pos)

    db, pos = _from_length_coded_str(data, pos)
    table, pos = _from_length_coded_str(data, pos)
    orig_table, pos = _from_length_coded_str(data, pos)
    col.name, pos = _from_length_coded_str(data, pos)

    orig_name, pos = _from_length_coded_str(data, pos)

    pos = pos + 1 -- ignore the filler

    charsetnr, pos = _get_byte2(data, pos)

    length, pos = _get_byte4(data, pos)

    col.type = strbyte(data, pos)

    return col
end


local function _parse_row_data_packet(data, cols, compact)
    local pos = 1
    local ncols = #cols
    local row
    if compact then
        row = new_tab(ncols, 0)
    else
        row = new_tab(0, ncols)
    end
    for i = 1, ncols do
        local value
        value, pos = _from_length_coded_str(data, pos)
        local col = cols[i]
        local typ = col.type
        local name = col.name

        --print("row field value: ", value, ", type: ", typ)

        if value ~= null then
            local conv = converters[typ]
            if conv then
                value = conv(value)
            end
        end

        if compact then
            row[i] = value

        else
            row[name] = value
        end
    end

    return row
end


local function _recv_field_packet(self)
    local packet, typ, err = _recv_packet(self)
    if not packet then
        return nil, err
    end

    if typ == "ERR" then
        local errno, msg, sqlstate = _parse_err_packet(packet)
        return nil, msg, errno, sqlstate
    end

    if typ ~= 'DATA' then
        return nil, "bad field packet type: " .. typ
    end

    return _parse_field_packet(packet)
end

local function _recv_ignore(self)
    local packet, typ, err = _recv_packet(self)
    if not packet then
        self.state = nil
        return nil, err
    end
    return true, typ
end

local function _recv_prepare_status(packet)
    return strunpack("<BI4I2I2BI2", packet)
end

function MySQL.ctor(self)
    self.state = nil
    self.sock = tcp:new()
    self._VERSION = '0.22'
end


function MySQL.set_timeout(self, timeout)
    self.sock._timeout = timeout
end


function MySQL.connect(self, opts)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    local max_packet_size = opts.max_packet_size
    if not max_packet_size then
        max_packet_size = 16 * 1024 * 1024 -- default 4 MB
    end
    self._max_packet_size = max_packet_size

    self.compact = opts.compact_arrays

    local database = opts.database or ""
    local username = opts.username or ""
    local password = opts.password or ""

    local host = opts.host
    if not host then
        return nil, "not host"
    end

    local port = opts.port or 3306

    local ok = sock:connect(host, port)
    if not ok then
        return nil, "Connect failed"
    end

    local packet, typ, err = _recv_packet(self)
    if not packet then
        return nil, err
    end

    if typ == "ERR" then
        local errno, msg, sqlstate = _parse_err_packet(packet)
        return nil, msg, errno, sqlstate
    end

    self.protocol_ver = strbyte(packet)

    --print("protocol version: ", self.protocol_ver)

    local server_ver, pos = _from_cstring(packet, 2)
    if not server_ver then
        return nil, "bad handshake initialization packet: bad server version"
    end

    --print("server version: ", server_ver)

    self._server_ver = server_ver

    local thread_id, pos = _get_byte4(packet, pos)

    --print("thread id: ", thread_id)

    local scramble = sub(packet, pos, pos + 8 - 1)
    if not scramble then
        return nil, "1st part of scramble not found"
    end

    pos = pos + 9 -- skip filler

    -- two lower bytes
    local capabilities  -- server capabilities
    capabilities, pos = _get_byte2(packet, pos)

    -- print(format("server capabilities: %#x", capabilities))

    self._server_lang = strbyte(packet, pos)
    pos = pos + 1

    --print("server lang: ", self._server_lang)

    self._server_status, pos = _get_byte2(packet, pos)

    --print("server status: ", self._server_status)

    local more_capabilities
    more_capabilities, pos = _get_byte2(packet, pos)

    capabilities = capabilities | more_capabilities << 16

    --print("server capabilities: ", capabilities)

    -- local len = strbyte(packet, pos)
    local len = 21 - 8 - 1

    --print("scramble len: ", len)

    pos = pos + 1 + 10

    local scramble_part2 = sub(packet, pos, pos + len - 1)
    if not scramble_part2 then
        return nil, "2nd part of scramble not found"
    end

    scramble = scramble .. scramble_part2
    --print("scramble: ", _dump(scramble))

    local req, token
    local client_flags = 260047
    if find(packet, "caching_sha2_password") then
        client_flags = client_flags | 0x80000 | 0x200000
        token = caching_sha2_password(password, scramble)
        req = strpack("<I4I4Bc23zs1zz", client_flags, self._max_packet_size, CHARSET_MAP[opts.charset] or 33, strrep("\0", 23), username, token, database, "caching_sha2_password")
    else
        token = mysq_native_password(password, scramble)
        req = strpack("<I4I4Bc23zs1z", client_flags, self._max_packet_size, CHARSET_MAP[opts.charset] or 33, strrep("\0", 23), username, token, database)
    end

    local ok = _send_packet(self, req, #req)
    if not ok then
      return nil, "send packet was failed."
    end

    local packet, typ, err = _recv_packet(self)
    if not packet then
        return nil, "failed to receive the result packet: " .. err
    end

    if typ == 'EOF' then
        return nil, "MySQL Authentication protocol not supported"
    end

    if typ == "DATA" then
        if packet == AUTH_SWITCH_CONTINUE then
            local ok = _send_packet(self, '\x02', 1)
            if not ok then
                return nil, "1. MySQL Server close this Authentication Switch session."
            end
            local public_key = _recv_packet(self)
            if not public_key then
                return nil, "2. MySQL Server close this Authentication Switch session."
            end
            local ok = _send_packet(self, rsa_encode(public_key:sub(2, -2), password .. "\x00", scramble), 256)
            if not ok then
                return nil, "3. MySQL Server close this Authentication Switch session."
            end
            packet, typ, err = _recv_packet(self)
        elseif packet == AUTH_SWITCH_OK then
            packet, typ, err = _recv_packet(self)
        else
            return nil, "4. This Connection More Data Authentication Was failed."
        end
    end

    if typ == 'ERR' then
        local errno, msg, sqlstate = _parse_err_packet(packet)
        return nil, msg, errno, sqlstate
    end

    if typ ~= 'OK' then
        return nil, "bad packet type: " .. typ
    end

    self.state = STATE_CONNECTED

    return true
end

function MySQL.close(self)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    if self.state then
        _send_packet(self, strchar(COM_QUIT), 1)
    end
    self.state = nil
    self.sock = nil
    setmetatable(self, nil)
    return sock:close()
end

function MySQL.send_query(self, query)
  self.packet_no = -1
  return _send_packet(self, strchar(COM_QUERY) .. query, 1 + #query)
end

function MySQL.send_prepare(self, query)
  self.packet_no = -1
  return _send_packet(self, strchar(COM_STMT_PREPARE) .. query, 1 + #query)
end

--参数字段类型转换
local store_types = {
    number = function(v)
        if not toint(v) then
            return _set_byte2(0x05), _set_double(v)
        end
        return _set_byte2(0x08), _set_byte8(v)
    end,
    string = function(v)
        return _set_byte2(0x0f), _set_length_coded_bin(#v) .. v
    end,
    --bool转换为0,1
    boolean = function(v)
        return _set_byte2(0x01), v and strchar(1) or strchar(0)
    end
}

function MySQL.send_execute(self, stmt, opt)
  self.packet_no = -1
  local query = strchar(COM_STMT_EXECUTE) .. strpack("<I4BI4", stmt.statement_id, CURSOR_TYPE_NO_CURSOR, 0x01)
  local num_params = stmt.num_params
  if num_params > 0 then
    local bitmap = (num_params + 7) // 8
    local types = new_tab(num_params, 0)
    local values = new_tab(num_params, 0)
    for _, v in pairs(opt) do
        local f = store_types[type(v)]
        if not f then
            error("execute has UnSupport value and type.")
        end
        types[#types+1], values[#values+1] = f(v)
    end
    query = query .. strrep("\0", bitmap) .. strchar(0x01) .. concat(types) .. concat(values)
  end
  return _send_packet(self, query, #query)
end

function MySQL.read_prepare(self)
    local data, typ = _recv_packet(self)
    if typ == "ERR" then
        local errno, msg, sqlstate = _parse_err_packet(data)
        return nil, msg, errno, sqlstate
    end

    local status, statement_id, num_columns, num_params, reserved, warning_count = _recv_prepare_status(data)

    if num_params > 0x00 then
        for i = 1, num_params, 1 do
            local ok, err = _recv_ignore(self)
            if not ok then
                if err then
                    return nil, err
                end
                break
            end
        end
    end

    if num_columns > 0x00 then
        for i = 1, num_columns, 1 do
            local ok, err = _recv_ignore(self)
            if not ok then
                if err then
                    return nil, err
                end
                break
            end
        end
    end
    while 1 do
        local ok, typ = _recv_ignore(self)
        if not ok then
            return nil, typ
        end
        if typ == "EOF" or typ == "ERR" then
            break
        end
    end
    return { success = typ == 'OK' and true or false, status = status, statement_id = statement_id, num_columns = num_columns, num_params = num_params, reserved = reserved, warning_count = warning_count }
end


local _binary_parser = {
    [0x01] = _get_byte1,
    [0x02] = _get_byte2,
    [0x03] = _get_byte4,
    [0x04] = _get_float,
    [0x05] = _get_double,
    [0x07] = _get_datetime,
    [0x08] = _get_byte8,
    [0x0c] = _get_datetime,
    [0x0f] = _from_length_coded_str,
    [0x10] = _from_length_coded_str,
    [0xf9] = _from_length_coded_str,
    [0xfa] = _from_length_coded_str,
    [0xfb] = _from_length_coded_str,
    [0xfc] = _from_length_coded_str,
    [0xfd] = _from_length_coded_str,
    [0xfe] = _from_length_coded_str
}

local function _parse_row_data_binary(data, cols, compact)
    local ncols = #cols
    -- 空位图,前两个bit系统保留 (列数量 + 7 + 2) / 8
    local bitmap = (ncols + 9) // 8
    local pos = 2 + bitmap
    local value

    --空字段表
    local null_fields = new_tab(16, 0)
    local field_index = 1
    for i = 2, pos - 1 do
        local byte = strbyte(data, i)
        for j = 0, 7 do
            if field_index > 2 then
                if byte & (1 << j) == 0 then
                    null_fields[field_index - 2] = false
                else
                    null_fields[field_index - 2] = true
                end
            end
            field_index = field_index + 1
        end
    end

    local row = new_tab(ncols, 0)
    for i = 1, ncols do
        local col = cols[i]
        local typ = col.type
        local name = col.name
        if not null_fields[i] then
            local f = _binary_parser[typ]
            if not f then
                error("_parse_row_data_binary()error,unsupported field type " .. typ)
            end
            value, pos = f(data, pos)
            if compact then
                row[i] = value
            else
                row[name] = value
            end
        end
    end

    return row
end

function MySQL.read_execute(self, est_nrows)
    local packet, typ, err = _recv_packet(self, sock)
    if not packet then
        return nil, err
        --error( err )
    end

    if typ == "ERR" then
        local errno, msg, sqlstate = _parse_err_packet(packet)
        return nil, msg, errno, sqlstate
        --error( strformat("errno:%d, msg:%s,sqlstate:%s",errno,msg,sqlstate))
    end

    if typ == "OK" then
        local res = _parse_ok_packet(packet)
        if res and res.server_status & SERVER_MORE_RESULTS_EXISTS ~= 0 then
            return res, "again"
        end
        return res
    end

    if typ ~= "DATA" then
        return nil, "packet type " .. typ .. " not supported"
        --error( "packet type " .. typ .. " not supported" )
    end

    local field_count, extra = _parse_result_set_header_packet(packet)

    local cols = new_tab(field_count, 0)
    local col
    while true do
        packet, typ, err = _recv_packet(self, sock)
        if typ == "EOF" then
          local warning_count, status_flags = _parse_eof_packet(packet)
          break
        end
        col = _parse_field_packet(packet)
        if not col then
            break
        end
        cols[#cols + 1] = col
    end

    --没有记录集返回
    if #cols < 1 then
        return {}
    end

    local compact = self.compact
    local rows = {}
    local row
    while true do
        packet, typ, err = _recv_packet(self, sock)
        if typ == "EOF" then
            local warning_count, status_flags = _parse_eof_packet(packet)
            if status_flags & SERVER_MORE_RESULTS_EXISTS ~= 0 then
                return rows, "again"
            end
            break
        end
        row = _parse_row_data_binary(packet, cols, compact)
        if not col then
            break
        end
        rows[#rows + 1] = row
    end

    return rows
end

function MySQL.read_result(self, est_nrows)

    local packet, typ, err = _recv_packet(self)
    if not packet then
        self.state = nil
        return nil, err
    end

    if typ == "ERR" then
        local errno, msg, sqlstate = _parse_err_packet(packet)
        return nil, msg, errno, sqlstate
    end

    if typ == 'OK' then
        local res = _parse_ok_packet(packet)
        if res and (res.server_status & SERVER_MORE_RESULTS_EXISTS) ~= 0 then
            return res, "again"
        end
        return res
    end

    if typ ~= 'DATA' then
        self.state = nil
        return nil, "this type: " .. typ .. " is not supported 1"
    end

    local field_count, extra = _parse_result_set_header_packet(packet)

    local cols = new_tab(field_count, 0)
    for i = 1, field_count do
        local col, err, errno, sqlstate = _recv_field_packet(self)
        if not col then
            return nil, err, errno, sqlstate
        end
        cols[i] = col
    end

    local packet, typ, err = _recv_packet(self)
    if not packet then
        self.state = nil
        return nil, err
    end

    if typ ~= 'EOF' then
        return nil, "this type: " .. typ .. " is not supported 2"
    end

    local compact = self.compact
    local rows = new_tab(est_nrows or 16, 0)
    while true do
        packet, typ, err = _recv_packet(self)
        if not packet then
            self.state = nil
            return nil, err
        end
        if typ == 'EOF' then
            local warning_count, status_flags = _parse_eof_packet(packet)
            if (status_flags & SERVER_MORE_RESULTS_EXISTS) ~= 0 then
                return rows, "again"
            end
            break
        end
        rows[#rows + 1] = _parse_row_data_packet(packet, cols, compact)
    end
    return rows
end

function MySQL.query(self, query, est_nrows)
  if type(query) ~= "string" then
    return nil, "Attemp to pass a invaild SQL."
  end
  local ok = self:send_query(query)
  if not ok then
    self.state = nil
    return nil, 'connection already close. 1'
  end
  local ret, err = self:read_result(est_nrows)
  if err ~= 'again' then
    return ret, err
  end
  local multiple_result = new_tab(4, 0)
  multiple_result[#multiple_result+1] = ret
  while err == "again" do
    ret, err, errno, sqlstate = self:read_result(est_nrows)
    if not ret then
        multiple_result[#multiple_result+1] = { error = err, errno = errno, sqlstate = sqlstate }
        break
    end
    multiple_result[#multiple_result+1] = ret
  end
  return multiple_result
end

function MySQL.prepare(self, query)
  if type(query) ~= "string" or query == '' then
    return nil, "Attemp to pass a invaild prepare."
  end
  local ok = self:send_prepare(query)
  if not ok then
    self.state = nil
    return nil, 'connection already close.'
  end
  return self:read_prepare()
end

function MySQL.execute(self, stmt, ...)
    if select("#", ...) ~= stmt.num_params then
        return nil, 'The number of stmt parameters is inconsistent.'
    end
    local ok = self:send_execute(stmt, {...})
    if not ok then
        self.state = nil
        return nil, 'connection already close.'
    end
    return self:read_execute(est_nrows)
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

-- 转义
function MySQL.quote_sql_str( str )
    return strformat("%s", strgsub(str, "[\0\b\n\r\t\26\\\'\"]", escape_map))
end

function MySQL.set_compact_arrays(self, value)
    self.compact = value
end


return MySQL
