local cf = require "cf"
local cf_fork = cf.fork
local cf_sleep = cf.sleep

local wbproto = require "protocol.websocket.protocol"
local _recv_frame = wbproto.recv_frame
local _send_frame = wbproto.send_frame

local Log = require "logging":new { dump = true, path = 'protocol-websocket-server'}

local type = type
local pcall = pcall
local ipairs = ipairs
local assert = assert
local insert = table.insert
local char = string.char

local class = require "class"

local ws = class("ws")

function ws:ctor(opt)
  self.sock = opt.sock
  self.send_masked = nil
  self.max_payload_len = 65535
  self.ext = opt.ext
end

-- 设置发送掩码
function ws:set_send_masked(send_masked)
  self.send_masked = send_masked
end

-- 设置最大数据载荷长度
function ws:set_max_payload_len(max_payload_len)
  self.max_payload_len = max_payload_len
end

-- 异步消息发送
function ws:add_to_queue (f)
  if not self.queue then
    self.queue = {f}
    return cf_fork(function (...)
      for index, func in ipairs(self.queue) do
        local ok, writeable = pcall(func)
        if not ok then
          Log:ERROR(writeable)
        end
        if not ok or not writeable then
          break
        end
      end
      self.queue = nil
    end)
  end
  return self.queue and insert(self.queue, f)
end

-- 发送text/binary消息
function ws:send (data, binary)
  if self.closed then
    return
  end
  assert(type(data) == 'string' and data ~= '', "websoket error: send need string data.")
  self:add_to_queue(function ()
    return _send_frame(self.sock, true, binary and 0x2 or 0x1, data, self.max_payload_len, self.send_masked, self.ext)
  end)
end

-- 发送close帧
function ws:close(data)
  if self.closed then
    return
  end
  self.closed = true
  self:add_to_queue(function ()
    return _send_frame(self.sock, true, 0x8, char(((1000 >> 8) & 0xff), (1000 & 0xff))..(type(data) == 'string' and data or ""), self.max_payload_len, self.send_masked, self.ext)
  end)
  self:add_to_queue(function ()
    return self.sock:close()
  end)
end

local Websocket = { __Version__ = 1.0 }

-- Websocket Server 事件循环
function Websocket.start(opt)
  local sock = opt.sock
  local ext = opt.ext
  local w = ws:new { sock = sock, ext = ext }

  local cls = opt.cls:new { ws = w }
  local on_open = assert(type(cls.on_open) == 'function' and cls.on_open, "'on_open' method is not implemented.")
  local on_message = assert(type(cls.on_message) == 'function' and cls.on_message, "'on_message' method is not implemented.")
  local on_error = assert(type(cls.on_error) == 'function' and cls.on_error, "'on_error' method is not implemented.")
  local on_close = assert(type(cls.on_close) == 'function' and cls.on_close, "'on_close' method is not implemented.")

  sock._timeout = cls.timeout or nil
  local send_masked = cls.send_masked or nil
  local max_payload_len = cls.max_payload_len or 65535
  w:set_send_masked(send_masked)
  w:set_max_payload_len(max_payload_len)
  local ok, err = pcall(on_open, cls)
  if not ok then
    Log:ERROR(err)
    return
  end
  while 1 do
    local data, typ, err = _recv_frame(sock, max_payload_len, send_masked)
    if (not data and not typ) or typ == 'close' then
      w.closed = true
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
      break
    end
    if typ == 'ping' then
      w:add_to_queue(function () return _send_frame(sock, true, 0xA, data or '', max_payload_len, send_masked, ext) end)
    end
    if typ == 'text' or typ == 'binary' then
      cf_fork(on_message, cls, data, typ == 'binary')
    end
  end
  return
end

return Websocket