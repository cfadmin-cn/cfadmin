local TCP = require "internal.TCP"
local sock_recv = TCP.recv
local sock_send = TCP.send
local sock_close = TCP.close

local dataset = require "process.dataset"

local session = require "process.session"
local session_wakeup = session.wakeup

local lpack = require "pack"
local lpack_encode = lpack.encode
local lpack_decode = lpack.decode

local cf = require "cf"
local cf_fork = cf.fork
local cf_wait = cf.wait
local cf_wakeup = cf.wakeup

local ipairs = ipairs
local strunpack = string.unpack
local tconcat = table.concat

local MAX_BUFFER_SIZE = 4194304

local class = require "class"

local Channel = class("Channel")

function Channel:ctor()
  self.id = dataset.get('pid')
end

function Channel:send(...)
  if not self.queue then
    self.queue = {}
    local sock = self.sock
    self.writer = cf_fork(function ()
      while true do
        for _, buf in ipairs(self.queue) do
          sock_send(sock, buf)
        end
        self.queue = {}
        self.waited = true
        cf_wait()
      end
    end)
  end
  if self.waited then
    self.waited = nil
    cf_wakeup(self.writer)
  end
  self.queue[#self.queue + 1] = lpack_encode(...)
  return true
end

function Channel:recv()
  local sock = self.sock
  local data = sock_recv(sock, 4)
  if not data then
    return sock_close(sock)
  end
  local buffers = {data}
  local len = strunpack("<I4", data)
  if len <= 4 then
    return true
  end
  len = len - 4
  while true do
    local buf, dsize = sock_recv(sock, len)
    if not buf then
      return sock_close(sock)
    end
    buffers[#buffers+1] = buf
    if dsize == len then
      break
    end
    len = len - dsize
  end
  return true, lpack_decode(tconcat(buffers))
end

function Channel:setcb(func)
  if not self.reader then
    self.reader = cf_fork(function ()
      local function dispatch(success, sessionid, ...)
        if not success then
          return false
        end
        -- 如果有需要就唤醒等待的.
        if sessionid and session_wakeup(sessionid, ...) then
          return true
        end
        -- 如果是普通消息则直接调用.
        cf_fork(func, sessionid, ...)
        return true
      end
      while true do
        if not dispatch(self:recv()) then
          break
        end
      end
    end)
  end
end

function Channel:connect(mode)
  self.sock = TCP:new()
  if mode == 'master' then
    local sockname = self.id .. '.sock'
    local num = 0
    local channels = {}
    local co = cf.self()
    self.sock:listen_ex(sockname, true, function (fd)
      local chan = Channel:new()
      chan.sock = TCP:new():set_fd(fd)
      chan.sock:set_read_buffer_size(MAX_BUFFER_SIZE)
      chan.sock:set_write_buffer_size(MAX_BUFFER_SIZE)
      local _, id = chan:recv()
      chan.id = id
      channels[chan.id] = chan
      num = num + 1
      if num == master.nprocess then
        cf.wakeup(co, channels)
        os.remove(sockname)
      end
    end)
    return cf.wait()
  elseif mode == 'worker' then
    local sockname = dataset.get('ppid') .. '.sock'
    while true do
      if self.sock:connect_ex(sockname) then
        self.sock:set_read_buffer_size(MAX_BUFFER_SIZE)
        self.sock:set_write_buffer_size(MAX_BUFFER_SIZE)
        self:send(self.id)
        break
      end
    end
    return true
  end
end

return Channel