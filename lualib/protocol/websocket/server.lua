local stream = require "stream"

local cf = require "cf"
local cf_fork = cf.fork
local cf_sleep = cf.sleep

local wsproto = require "protocol.websocket.protocol"
local _recv_frame = wsproto.recv_frame
local _send_frame = wsproto.send_frame

local LOG = require "logging":new { dump = true, path = 'protocol-websocket-server'}

local type = type
local pcall = pcall
local ipairs = ipairs
local assert = assert
local insert = table.insert
local strpack = string.pack

local class = require "class"

local ws = class("ws")

function ws:ctor(opt)
  self.ext = opt.ext
  self.sock = opt.sock
  self.closed = false
  self.max_payload_len = 65535
end

function ws:set_timeout(timeout)
  self.sock:timeout(timeout)
end

-- 设置发送掩码
function ws:set_send_masked(send_masked)
  self.send_masked = send_masked
end

-- 设置最大数据载荷长度
function ws:set_max_payload_len(max_payload_len)
  self.max_payload_len = max_payload_len
end

-- 发送TEXT/BINARY帧
function ws:send(data, binary)
  if self.closed or self.sock.closed then
    return
  end
  _send_frame(self.sock, true, binary and 0x02 or 0x01, data, false, self.ext)
end

-- 发送PING帧
function ws:ping(data)
  if self.closed or self.sock.closed then
    return
  end
  return _send_frame(self.sock, true, 0x09, data or '', false, self.ext)
end

-- 发送CLOSE帧
function ws:close(data)
  if self.closed or self.sock.closed then
    return
  end
  self.closed = true
  _send_frame(self.sock, true, 0x08, strpack(">H", 1000) .. (type(data) == 'string' and data or ""), false, self.ext)
end

local Websocket = { __Version__ = 0.1 }

function Websocket.start(sock, cls, args, headers, ext)
  local on_open = assert(type(cls.on_open) == 'function' and cls.on_open, "'on_open' method is not implemented.")
  local on_message = assert(type(cls.on_message) == 'function' and cls.on_message, "'on_message' method is not implemented.")
  local on_error = assert(type(cls.on_error) == 'function' and cls.on_error, "'on_error' method is not implemented.")
  local on_close = assert(type(cls.on_close) == 'function' and cls.on_close, "'on_close' method is not implemented.")

  sock = stream(sock)
  local w = ws { sock = sock, ext = ext }
  local obj = cls{ ws = w, args = args, headers = headers }

  local timeout = obj.timeout or 0
  local max_payload_len = obj.max_payload_len or 65535
  w:set_timeout(timeout); w:set_max_payload_len(max_payload_len)

  local ok, err = pcall(on_open, obj)
  if not ok then
    return LOG:ERROR(err)
  end
  -- 开始监听
  :: CONTINUE ::
  local data, typ, errinfo = _recv_frame(sock, max_payload_len, true)
  if not typ or typ == 'close' or typ == 'error' then
    if typ == 'error' then
      ok, err = pcall(on_error, obj, errinfo)
      if not ok then
        LOG:ERROR(err)
      end
    end
    ok, err = pcall(on_close, obj, data or errinfo)
    if not ok then
      LOG:ERROR(err)
    end
    return w:close(), cf_sleep(0)
  elseif typ == 'ping' then
    _send_frame(sock, true, 0x0A, data or '', false, ext)
  elseif typ == 'text' or typ == 'binary' then
    cf_fork(on_message, obj, data, typ == 'binary')
  end
  goto CONTINUE
end

return Websocket