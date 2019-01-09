-- Copyright (C) Yichun Zhang (agentzh)
-- modify by CandyMi in 2019.1.9

local crypt = require "crypt"
local sha1_bin = crypt.sha1
local base64 = crypt.base64encode

local wbproto = require "protocol"
local new_tab = wbproto.new_tab
local _recv_frame = wbproto.recv_frame
local _send_frame = wbproto.send_frame

local str_lower = string.lower
local char = string.char
local str_find = string.find

local type = type
local setmetatable = setmetatable
local tostring = tostring

local _M = new_tab(0, 10)
_M._VERSION = '0.07'

local mt = { __index = _M }


function _M.new(self, opts)
    local max_payload_len, send_masked, timeout
    if opts then
        max_payload_len = opts.max_payload_len
        send_masked = opts.send_masked
        timeout = opts.timeout

        if timeout then
            sock:settimeout(timeout)
        end
    end

    return setmetatable({
        sock = sock,
        max_payload_len = max_payload_len or 65535,
        send_masked = send_masked,
    }, mt)
end


function _M.set_timeout(self, time)
    local sock = self.sock
    if not sock then
        return nil, nil, "not initialized yet"
    end

    return sock:timeout(time)
end


function _M.recv_frame(self)
    if self.fatal then
        return nil, nil, "fatal error already happened"
    end

    local sock = self.sock
    if not sock then
        return nil, nil, "not initialized yet"
    end

    local data, typ, err =  _recv_frame(sock, self.max_payload_len, true)
    if not data and not str_find(err, ": timeout", 1, true) then
        self.fatal = true
    end
    return data, typ, err
end


local function send_frame(self, fin, opcode, payload)
    if self.fatal then
        return nil, "fatal error already happened"
    end

    local sock = self.sock
    if not sock then
        return nil, "not initialized yet"
    end

    local bytes, err = _send_frame(sock, fin, opcode, payload,
                                   self.max_payload_len, self.send_masked)
    if not bytes then
        self.fatal = true
    end
    return bytes, err
end
_M.send_frame = send_frame


function _M.send_text(self, data)
    return send_frame(self, true, 0x1, data)
end


function _M.send_binary(self, data)
    return send_frame(self, true, 0x2, data)
end


function _M.send_close(self, code, msg)
    local payload
    if code then
        if type(code) ~= "number" or code > 0x7fff then
        end
        payload = char((code >> 8) & 0xff, code & 0xff) .. (msg or "")
    end
    return send_frame(self, true, 0x8, payload)
end


function _M.send_ping(self, data)
    return send_frame(self, true, 0x9, data)
end


function _M.send_pong(self, data)
    return send_frame(self, true, 0xa, data)
end


return _M