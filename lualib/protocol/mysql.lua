local tcp = require "internal.TCP"
local log = require "log"
local crypt = require "crypt"

local sub = string.sub
local strgsub = string.gsub
local strformat = string.format
local strbyte = string.byte
local strchar = string.char
local strrep = string.rep
local strunpack = string.unpack
local strpack = string.pack
local sha1= crypt.sha1
local setmetatable = setmetatable
local error = error
local tonumber = tonumber
local new_tab = function (narr, nrec) return {} end

local MySQL = class("MySQL")

local STATE_CONNECTED = 1
local STATE_COMMAND_SENT = 2

local COM_QUIT = 0x01
local COM_QUERY = 0x03
local CLIENT_SSL = 0x0800

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

local function _from_cstring(data, i)
    return strunpack("z", data, i)
end

local function _dumphex(bytes)
    return strgsub(bytes, ".", function(x) return strformat("%02x ", strbyte(x)) end)
end

local function _compute_token(password, scramble)
    local stage1 = sha1(password)
    local stage2 = sha1(stage1)
    local stage3 = sha1(scramble .. stage2)
	local i = 0
	return strgsub(stage3,".", function(x)
		i = i + 1
		return strchar(strbyte(x) ~ strbyte(stage1, i))
	end)
end

local function _send_packet(self, req, size)
    local sock = self.sock

    self.packet_no = self.packet_no + 1

    local packet = _set_byte3(size) .. strchar(self.packet_no & 255) .. req

    return sock:send(packet)
end


local function _recv_packet(self)
    local sock = self.sock

    local data, err = sock:recv(4) -- packet header
    if not data then
        return nil, nil, "failed to receive packet header: " .. err
    end

    --print("packet header: ", _dump(data))

    local len, pos = _get_byte3(data, 1)

    --print("packet length: ", len)

    if len == 0 then
        return nil, nil, "empty packet"
    end

    if len > self._max_packet_size then
        return nil, nil, "packet size too big: " .. len
    end

    local num = strbyte(data, pos)

    --print("recv packet: packet no: ", num)

    self.packet_no = num

    data, err = sock:recv(len)

    --print("receive returned")

    if not data then
        return nil, nil, "failed to read packet content: " .. err
    end

    local field_count = strbyte(data, 1)

    local typ
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


function MySQL.ctor(self)
    self.state = nil
    self.sock = tcp:new()
    self._VERSION = '0.21'
end


function MySQL.set_timeout(self, timeout)
    return self.sock:settimeout(timeout)
end


function MySQL.connect(self, opts)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    local max_packet_size = opts.max_packet_size
    if not max_packet_size then
        max_packet_size = 4 * 1024 * 1024 -- default 4 MB
    end
    self._max_packet_size = max_packet_size

    self.compact = opts.compact_arrays

    local database = opts.database or ""
    local user = opts.user or ""
    local host = opts.host

    if not host then
        return nil, "not host"
    end

    local port = opts.port or 3306
    if not pool then
        pool = user .. ":" .. database .. ":" .. host .. ":" .. port
    end

    local ok = sock:connect(host, port)
    if not ok then
        self:close()
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

    local password = opts.password or ""

    local token = _compute_token(password, scramble)

    --print("token: ", _dump(token))

    local client_flags = 260047;

    local req = strpack("<I4I4c24zs1z",
        client_flags,
        self._max_packet_size,
        strrep("\0", 24),	-- TODO: add support for charset encoding
        user,
        token,
        database)

    local packet_len = #req

    -- print("packet content length: ", packet_len)
    -- print("packet content: ", _dump(concat(req, "")))

    _send_packet(self, req, packet_len)

    --print("packet sent ", bytes, " bytes")

    local packet, typ, err = _recv_packet(self)
    if not packet then
        return nil, "failed to receive the result packet: " .. err
    end

    if typ == 'ERR' then
        local errno, msg, sqlstate = _parse_err_packet(packet)
        return nil, msg, errno, sqlstate
    end

    if typ == 'EOF' then
        return nil, "old pre-4.1 authentication protocol not supported"
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
    if self.state ~= STATE_CONNECTED then
        return nil, "cannot send query in the current context: ".. (self.state or "nil")
    end

    self.packet_no = -1

    local cmd_packet = strchar(COM_QUERY) .. query

    _send_packet(self, cmd_packet, 1 + #query)

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
        self.state = nil
        return nil, "this type: " .. typ .. " is not supported 2"
    end
    local compact = self.compact
    local rows = new_tab(est_nrows or 4, 0)
    local i = 0
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
        local row = _parse_row_data_packet(packet, cols, compact)
        i = i + 1
        rows[i] = row
    end
    return rows
end


function MySQL.query(self, query, est_nrows)

    if not query or type(query) ~= "string" then
        return nil, "Attemp to pass a invaild SQL."
    end

    self:send_query(query)

    return self:read_result(est_nrows)

end


function MySQL.set_compact_arrays(self, value)
    self.compact = value
end


return MySQL
