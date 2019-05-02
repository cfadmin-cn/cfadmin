local log = require "logging"
local class = require "class"
local co = require "internal.Co"
local wbproto = require "protocol.websocket.protocol"
local _recv_frame = wbproto.recv_frame
local _send_frame = wbproto.send_frame

local Log = log:new({ dump = true, path = 'protocol-websocket-server'})

local co_self = co.self
local co_wait = co.wait
local co_spwan = co.spwan
local co_wakeup = co.wakeup

local type = type
local next = next
local pcall = pcall
local ipairs = ipairs
local assert = assert
local setmetatable = setmetatable
local tostring = tostring
local char = string.char


local websocket = class("websocket-server")

function websocket:ctor(opt)
    self.cls = opt.cls
    self.sock = opt.sock
    self.sock._timeout = nil
end

-- 将回调函数写入到队列内
local function add_to_queue(queue, func)
    queue[#queue + 1] = func
end

-- 一次将多条回调函数写入到队列内
local function more_add_to_queue(queue, list)
    for _, func in ipairs(list) do
        add_to_queue(queue, func)
    end
end

-- 唤醒write queue
local function wakeup(co)
    return co and co_wakeup(co)
end

function websocket:start()
    local cls
    local sock = self.sock
    local current_co = co_self()
    local write_list = {}
    local write_co = co_spwan(function (...)
        while 1 do
            for _, f in ipairs(write_list) do
                local ok, err = pcall(f)
                if not ok then
                    Log:ERROR(err)
                end
            end
            write_list = {}
            co_wait()
            if #write_list == 0 then
                -- print("写入协程退出了")
                return
            end
        end
    end)
    local ws = {
        CLOSE = false,
        send = function (self, data, binary)
            if self.CLOSE then return end
            if data and type(data) == 'string' then
                local code = 0x1
                if binary then
                    code = 0x2
                end
                add_to_queue(write_list, function ()
                    return _send_frame(
                        sock,
                        true,
                        code,
                        data,
                        cls.max_payload_len or 65535,
                        cls.send_masked or false
                    )
                end)
                return wakeup(write_co)
            end
        end,
        close = function (self, data)
            if self.CLOSE then return end
            self.CLOSE = true
            more_add_to_queue(write_list, {
                function()
                    return _send_frame(
                        sock,
                        true,
                        0x8,
                        char(((1000 >> 8) & 0xff),(1000 & 0xff))..(data or ""),
                        cls.max_payload_len or 65535,
                        cls.send_masked or false
                    )
                end,
                function() return sock:close() end,
            })
            return wakeup(current_co), wakeup(write_co)
        end,
        -- ping = function (self, data)
        --     if self.CLOSE then return end
        --     add_to_queue(write_list, function()
        --         _send_frame(sock, true, 0x9, data, cls.max_payload_len or 65535, cls.send_masked or false)
        --     end)
        --     return wakeup(write_co)
        -- end,
        -- pong = function (self, data)
        --     if self.CLOSE then return end
        --     add_to_queue(write_list, function()
        --         _send_frame(sock, true, 0xa, data, cls.max_payload_len or 65535, cls.send_masked or false)
        --     end)
        --     return wakeup(write_co)
        -- end,
    }
    cls = self.cls:new { ws = ws }
    local on_open = cls.on_open
    local on_message = cls.on_message
    local on_error = cls.on_error
    local on_close = cls.on_close
    local ok, err = pcall(on_open, cls)
    if not ok then
        Log:ERROR(err)
        return sock:close()
    end
    while 1 do
        local data, typ, err = _recv_frame(sock, cls.max_payload_len, true)
        if (not data and not typ) or typ == 'close' then
            -- 客户端主动关闭: ws.CLOSE == flase
            -- 服务端主动关闭: ws.CLOSE == true
            if not ws.CLOSE then
                ws.CLOSE = true
                write_list = {}
                sock:close()
            end
            if err then
                local ok, err = pcall(on_error, cls, err)
                if not ok then
                    Log:ERROR(err)
                end
            end
            local ok, err = pcall(on_close, cls, data)
            if not ok then
                Log:ERROR(err)
            end
            -- print("读取协程退出了")
            return wakeup(write_co)
        end
        if typ == 'ping' then
            add_to_queue(write_list, function()
                _send_frame(
                    sock,
                    true,
                    0xa,
                    data,
                    cls.max_payload_len or 65535,
                    cls.send_masked or false
                )
            end)
        elseif typ == 'text' or typ == 'binary' then
            co_spwan(on_message, cls, data, typ)
        else
            -- 目前将设计精简为: 除了需要回应的ping协议, 其他协议均不会触发任何Server端回调响应;
            -- 如需特殊需求, 请自行在业务逻辑中解决(或使用定时器进行循环探测);
        end
    end
end

return websocket
