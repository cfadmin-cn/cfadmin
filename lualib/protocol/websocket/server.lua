local cf = require "cf"
local cf_fork = cf.fork

local new_tab = require"sys".new_tab

local wsproto = require "protocol.websocket.protocol"
local _recv_frame = wsproto.recv_frame
local _send_frame = wsproto.send_frame

local Log = require "logging":new { dump = true, path = 'protocol-websocket-server'}

local type = type
local pcall = pcall
local ipairs = ipairs
local assert = assert
local insert = table.insert
local strpack = string.pack

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
    self.queue = new_tab(64, 0)
    self.co = cf_fork(function ()
      for _, func in ipairs(self.queue) do
        local ok, writeable = pcall(func)
        if not ok then
          Log:ERROR(writeable)
        end
        if not ok or not writeable then
          break
        end
      end
      self.co, self.queue = nil, nil
    end)
  end
  return insert(self.queue, f)
end

-- 发送text/binary消息
function ws:send (data, binary)
  if self.closed then
    return
  end
  assert(type(data) == 'string' and data ~= '', "websoket error: send need string data.")
  self:add_to_queue(function ()
    return _send_frame(self.sock, true, binary and 0x02 or 0x01, data, self.max_payload_len, self.send_masked, self.ext)
  end)
end

-- 发送close帧
function ws:close(data)
  if self.closed then
    return
  end
  self.closed = true
  self:add_to_queue(function ()
    return _send_frame(self.sock, true, 0x08, strpack(">H", 1000) .. (type(data) == 'string' and data or ""), self.max_payload_len, self.send_masked, self.ext) and self.sock:close()
  end)
end

-- 退出
function ws:exit()
  self.closed = true
  self:add_to_queue(function () end)
end

local Websocket = { __Version__ = 1.0 }

-- Websocket Server 事件循环
function Websocket.start(opt)
  local sock = opt.sock
  local ext = opt.ext
  local w = ws:new { sock = sock, ext = ext }

  local cls = opt.cls:new { ws = w, args = opt.args, headers = opt.headers }
  local on_open = assert(type(cls.on_open) == 'function' and cls.on_open, "'on_open' method is not implemented.")
  local on_message = assert(type(cls.on_message) == 'function' and cls.on_message, "'on_message' method is not implemented.")
  local on_error = assert(type(cls.on_error) == 'function' and cls.on_error, "'on_error' method is not implemented.")
  local on_close = assert(type(cls.on_close) == 'function' and cls.on_close, "'on_close' method is not implemented.")

  sock._timeout = cls.timeout or nil
  local max_payload_len = cls.max_payload_len or 65535
  w:set_max_payload_len(max_payload_len)
  local ok, err = pcall(on_open, cls)
  if not ok then
    Log:ERROR(err)
    return
  end
  -- Websocket 交互协议循环
  while 1 do
    local data, typ, errinfo = _recv_frame(sock, max_payload_len, true)
    if not typ or typ == 'close' or typ == 'error' then
      w:exit()
      if typ == 'error' then
        ok, err = pcall(on_error, cls, errinfo)
        if not ok then
          Log:ERROR(err)
        end
      end
      ok, err = pcall(on_close, cls, data or errinfo)
      if not ok then
        Log:ERROR(err)
      end
      break
    end
    if typ == 'ping' then
      w:add_to_queue(function () return _send_frame(sock, true, 0x0A, data or '', max_payload_len, false, ext) end)
    end
    if typ == 'text' or typ == 'binary' then
      cf_fork(on_message, cls, data, typ == 'binary')
    end
  end
  return
end

return Websocket