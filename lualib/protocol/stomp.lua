-- lua-resty-rabbitmqstomp: Opinionated RabbitMQ (STOMP) client lib
-- Copyright (C) 2013 Rohit 'bhaisaab' Yadav, Wingify
-- Opensourced at Wingify in New Delhi under the MIT License
-- modefy by CandyMi in 2019.1.15

local class = require "class"
local tcp = require "internal.TCP"
local dns = require "protocol.dns"
local byte = string.byte
local concat = table.concat
local error = error
local find = string.find
local gsub = string.gsub
local insert = table.insert
local len = string.len
local pairs = pairs
local setmetatable = setmetatable
local sub = string.sub

_VERSION = "0.1"

-- local mt = { __index = _M }
local stomp = class("stomp")

local EOL = "\x0d\x0a"
local NULL_BYTE = "\x00"
local STATE_CONNECTED = 1
local STATE_COMMAND_SENT = 2


function stomp.ctor(self)
    self.sock = tcp:new()
end

function stomp.set_timeout(self, timeout)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:timeout(timeout)
end


local function _build_frame(self, command, headers, body)
    local frame = {command, EOL}

    if body then
        headers["content-length"] = len(body) + 4
    end

    for key, value in pairs(headers) do
        insert(frame, key)
        insert(frame, ":")
        insert(frame, value)
        insert(frame, EOL)
    end

    insert(frame, EOL)

    if body then
        insert(frame, body)
        insert(frame, EOL)
        insert(frame, EOL)
    end

    insert(frame, NULL_BYTE)
    insert(frame, EOL)
    return concat(frame, "")
end

local function _send_frame(self, frame)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    return sock:send(frame)
end

local function _receive_frame(self)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local buf_list, err = {} 
    -- while 1 do
    --     local buf, len = sock:recv(1024)
    --     print(buf, len)
    --     if not buf then
    --         return nil, "stomp server close this session in connecting."
    --     end
    --     print(string.sub(buf, #buf-1, -1) == '\0', buf)
    --     buf_list[#buf_list+1] = buf
    --     -- if buf[#buf] == NULL_BYTE then
    --     if buf[#buf] == NULL_BYTE then
    --         break
    --     end
    -- end
    -- return concat(buf_list), err
    -- local resp = sock:receiveuntil(NULL_BYTE, {inclusive = true})
    local data, err, partial = sock:recv(8192)
    return data, err
end

local function _login(self, user, passwd, vhost)
    local headers = {}
    headers["accept-version"] = "1.2"
    headers["login"] = user
    headers["passcode"] = passwd
    headers["host"] = vhost

    local ok, err = _send_frame(self, _build_frame(self, "CONNECT", headers, nil))
    if not ok then
        return nil, err
    end

    self.state = STATE_CONNECTED
    return _receive_frame(self)
end

local function _logout(self)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    -- self.state = nil
    if self.state == STATE_CONNECTED then
        -- Graceful shutdown
        local headers = {}
        headers["receipt"] = "disconnect"
        sock:send(_build_frame(self, "DISCONNECT", headers, nil))
        -- sock:recv()
    end
    return sock:close()
end

function stomp.connect(self, opts)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    local host = opts.host
    if not host then
        host = "127.0.0.1"
    end

    local port = opts.port
    if not port then
        port = 61613  -- stomp port
    end

    local username = opts.username
    if not username then
        username = "guest"
    end

    local password = opts.password
    if not password then
        password = "guest"
    end

    local vhost = opts.vhost
    if not vhost then
        vhost = "/"
    end
    local ok, ip = dns.resolve(host)
    if not ok then
        return nil, "can't resolve this host:"..tostring(host)
    end
    local ok, err = sock:connect(ip, port)
    if not ok then
        return nil, "failed to connect: " .. tostring(err)
    end

    return _login(self, username, password, vhost)
end

function stomp.send(self, msg, headers)
    local ok, err = _send_frame(self, _build_frame(self, "SEND", headers, msg))
    if not ok then
        return nil, err
    end

    if headers["receipt"] ~= nil then
        return _receive_frame(self)
    end
    return ok, err
end

function stomp.subscribe(self, headers)
    return _send_frame(self, _build_frame(self, "SUBSCRIBE", headers))
end

function stomp.unsubscribe(self, headers)
    return _send_frame(self, _build_frame(self, "UNSUBSCRIBE", headers))
end

function stomp.receive(self)
    local data, err = _receive_frame(self)
    if not data then
        return nil, err
    end
    data = gsub(data, EOL..EOL, "")
    local idx = find(data, "\n\n", 1)
    return sub(data, idx + 2)
end

function stomp.close(self)
    return _logout(self)
end

return stomp