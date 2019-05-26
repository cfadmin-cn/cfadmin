local class = require "class"

local wbproto = require "protocol.websocket.protocol"
local _recv_frame = wbproto.recv_frame
local _send_frame = wbproto.send_frame

local log = require "logging"
local Log = log:new({ dump = true, path = 'protocol-websocket-server'})

local co = require "internal.Co"
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

-- 将回调函数写入到队列内
local function add_to_queue(queue, f)
    queue[#queue + 1] = f
end

-- 唤醒write queue
local function wakeup(co, ...)
    return co and co_wakeup(co, ...)
end

local websocket = class("websocket-server")

function websocket:ctor(opt)
  self._VERSION = '0.07'
  self.cls = opt.cls
  self.sock = opt.sock
  self.co = co_self()
  self.write_co = nil
  self.closed = nil
  self.sock._timeout = nil
  self.queue = {}
  self.write_state = 'work'
  co_spwan(function ()
    self.write_co = co_self()
    while 1 do
      self.write_state = 'work'
      for _, f in ipairs(self.queue) do
        local ok, err = pcall(f)
        if not ok then
          Log:ERROR(err)
        end
      end
      if self.closed then
        self.write_state = 'quit'
        return
      end
      self.queue = {}
      self.write_state = 'wait'
      local continue = co_wait()
      if not continue then
        self.write_state = 'quit'
        return
      end
    end
  end)
end

-- send_text、send_binary
function websocket:send (data, binary)
  if self.closed then
    return
  end
  if data and type(data) == 'string' then
    add_to_queue(self.queue, function ()
      return _send_frame(self.sock, true, binary and 0x2 or 0x1, data, self.max_payload_len, self.send_masked)
    end)
    if self.write_state == 'wait' then
      return wakeup(self.write_co, true)
    end
  end
end

-- 发送close帧
function websocket:close (data)
  if self.closed then
    return
  end
  self.closed = true
  if type(data) == 'string' and data ~= '' then
    add_to_queue(self.queue, function ()
      return _send_frame(self.sock, true, 0x8, char(((1000 >> 8) & 0xff), (1000 & 0xff))..data, self.max_payload_len, self.send_masked)
    end)
  end
  if self.write_state == 'wait' then
    wakeup(self.write_co)
  end
  wakeup(self.co)
end

-- Websocket Server 事件循环
function websocket:start()
  local sock = self.sock
  local cls = self.cls:new { ws = self }
  local on_open = cls.on_open
  local on_message = cls.on_message
  local on_error = cls.on_error
  local on_close = cls.on_close
  local ok, err = pcall(on_open, cls)
  if not ok then
    self.sock = nil
    return Log:ERROR(err)
  end
  self.cls = nil
  self.sock._timeout = cls.timeout
  self.send_masked = cls.send_masked
  self.max_payload_len = cls.max_payload_len or 65535
  while 1 do
    local data, typ, err = _recv_frame(sock, self.max_payload_len, self.send_masked)
    if (not data and not typ) or typ == 'close' then
      self.closed = true
      if self.write_state == 'wait' then
        wakeup(self.write_co)
      end
      if err and err ~= 'read timeout' then
        local ok, err = pcall(on_error, cls, err)
        if not ok then
          Log:ERROR(err)
        end
      end
      local ok, err = pcall(on_close, cls, data)
      if not ok then
        Log:ERROR(err)
      end
      self.sock = nil
      return
    end
    if typ == 'ping' then
      add_to_queue(self.queue, function () return _send_frame(sock, true, 0xA, data or '', self.max_payload_len, self.send_masked) end)
      if self.write_state == 'wait' then
        wakeup(self.write_co, true)
      end
    end
    if typ == 'text' or typ == 'binary' then
      co_spwan(on_message, cls, data, typ == 'binary')
    end
  end
end

return websocket
