local cf = require "cf"
local cf_fork = cf.fork
local cf_sleep = cf.sleep

local wbproto = require "protocol.websocket.protocol"
local _recv_frame = wbproto.recv_frame
local _send_frame = wbproto.send_frame

local log = require "logging"
local Log = log:new({ dump = true, path = 'protocol-websocket-server'})

local type = type
local pcall = pcall
local ipairs = ipairs
local insert = table.insert
local char = string.char

local class = require "class"

local websocket = class("websocket-server")

function websocket:ctor(opt)
  self._VERSION = '0.07'
  self.cls = opt.cls
  self.sock = opt.sock
  self.closed = nil
  self.sock._timeout = nil
end

-- 异步消息发送
function websocket:add_to_queue (f)
  if not self.queue then
    self.queue = {f}
    return cf_fork(function (...)
      for index, func in ipairs(self.queue) do
        local ok, writeable = pcall(func)
        if not ok then
          Log:ERROR(writeable)
        end
        if not writeable then
          break
        end
      end
      self.queue = nil
    end)
  end
  return self.queue and insert(self.queue, f)
end

-- send_text、send_binary
function websocket:send (data, binary)
  if self.closed then
    return
  end
  assert(type(data) == 'string' and data ~= '', "websoket error: send发送的消息应该是string类型.")
  self:add_to_queue(function ()
    return _send_frame(self.sock, true, binary and 0x2 or 0x1, data, self.max_payload_len, self.send_masked)
  end)
end

-- 发送close帧
function websocket:close (data)
  if self.closed then
    return
  end
  self.closed = true
  self:add_to_queue(function ()
    return _send_frame(self.sock, true, 0x8, char(((1000 >> 8) & 0xff), (1000 & 0xff))..data, self.max_payload_len, self.send_masked)
  end)
  self:add_to_queue(function ()
    return self.sock:close()
  end)
end

-- Websocket Server 事件循环
function websocket:start()
  local sock = self.sock
  local cls = self.cls:new { ws = self }
  local on_open = cls.on_open
  local on_message = cls.on_message
  local on_error = cls.on_error
  local on_close = cls.on_close
  self.cls = nil
  self.sock._timeout = cls.timeout
  self.send_masked = cls.send_masked
  self.max_payload_len = cls.max_payload_len or 65535
  local ok, err = pcall(on_open, cls)
  if not ok then
    self.sock = nil
    return Log:ERROR(err)
  end
  while 1 do
    local data, typ, err = _recv_frame(sock, self.max_payload_len, self.send_masked)
    if (not data and not typ) or typ == 'close' then
      self.closed = true
      if err and err ~= 'read timeout' then
        local ok, err = pcall(on_error, cls, err)
        if not ok then
          Log:ERROR(err)
        end
      end
      local ok, err = pcall(on_close, cls, data or err)
      if not ok then
        Log:ERROR(err)
      end
      return
    end
    if typ == 'ping' then
      self:add_to_queue(function () return _send_frame(sock, true, 0xA, data or '', self.max_payload_len, self.send_masked) end)
    end
    if typ == 'text' or typ == 'binary' then
      cf_fork(on_message, cls, data, typ == 'binary')
    end
  end
end

return websocket
