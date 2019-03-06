local log = require "log"
local class = require "class"
local co = require "internal.Co"
local wbproto = require "protocol.websocket.protocol"
local _recv_frame = wbproto.recv_frame
local _send_frame = wbproto.send_frame

local co_self = co.self
local co_wait = co.wait
local co_spwan = co.spwan
local co_wakeup = co.wakeup

local type = type
local assert = assert
local setmetatable = setmetatable
local tostring = tostring
local char = string.char
local next = next
local pcall = pcall
local ipairs = ipairs

local websocket = class("websocket-server")

function websocket:ctor(opt)
    self.sock = opt.sock
    self.cls = opt.cls:new()
    self.sock._timeout = nil
end

function websocket:start()
    local on_open = self.cls.on_open
    local on_message = self.cls.on_message
    local on_error = self.cls.on_error
    local on_close = self.cls.on_close
    local on_ping = self.cls.on_ping
    local on_pong = self.cls.on_pong
    local sock = self.sock
    local current_co = co_self()
    local cls = self.cls
    local send_masked = self.cls.sen_masked or false
    local max_payload_len = self.cls.max_payload_len or 65535
    local write_list = {}
    local write_co
    co_spwan(function (...)
        write_co = co_self()
        while 1 do
            for index, f in ipairs(write_list) do
                local ok, err = pcall(f)
                if not ok then
                    log.error(err)
                end
            end
            write_list = {}
            co_wait()
            if #write_list == 0 then
                write_co = nil
                write_list = nil
                return
            end
        end
    end)
    local ws = setmetatable({}, { __name = "WebSocket", __index = function (t, key)
        return function(data, binary)
            if not t.CLOSE == true then return end -- 如果已经发送了close则不允许再发送任何协议
            if key == 'ping' then
                write_list[#write_list + 1] = function() _send_frame(sock, true, 0x9, data, max_payload_len, send_masked) end
            elseif key == "pong" then
                write_list[#write_list + 1] = function() _send_frame(sock, true, 0xa, data, max_payload_len, send_masked) end
            elseif key == 'send' then
                if data and type(data) == 'string' then
                    local code = 0x1
                    if binary then
                        code = 0x2
                    end
                    write_list[#write_list + 1] = function () _send_frame(sock, true, code, data, max_payload_len, send_masked) end
                end
            elseif key == "close" then
                t.CLOSE = true
                write_list[#write_list + 1] = function() _send_frame(sock, true, 0x8, char(((1000 >> 8) & 0xff), (1000 & 0xff))..(data or ""), max_payload_len, send_masked) end
                write_list[#write_list + 1] = function() sock:close() end
                write_list[#write_list + 1] = function() co_wakeup(current_co) end
            end
            return co_wakeup(write_co)
        end
    end})
    local ok, err = pcall(on_open, cls, ws)
    if not ok then
        log.error(err)
        return sock:close()
    end
    while 1 do
        local data, typ, err = _recv_frame(sock, max_payload_len, true)
        if (not data and not typ) or typ == 'close' then
            if ws.CLOSE ~= true then
                ws.CLOSE = true
                sock:close()
            end
            if err then
                local ok, err = pcall(on_error, cls, ws, err)
                if not ok then
                    log.error(err)
                end
            end
            local ok, err = pcall(on_close, cls, ws, data)
            if not ok then
                log.error(err)
            end
            return co_wakeup(write_co)
        end
        if typ == 'ping' then
            if not on_ping then 
                write_list[#write_list + 1] = {f = ws.pong(data)} 
            else
                co_spwan(on_ping, cls, ws, data, typ == 'binary')
            end
        elseif typ == 'pong' then
            if on_open then
                co_spwan(on_pong, cls, ws, data, typ == 'binary')
            end
        elseif typ == 'text' or typ == 'binary' then
            co_spwan(on_message, cls, ws, data, typ == 'binary')
        else -- 其他情况与不支持的协议什么都不做.
        end
    end
end

return websocket