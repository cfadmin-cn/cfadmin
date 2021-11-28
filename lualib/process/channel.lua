local TCP = require "internal.TCP"

local dataset = require "process.dataset"

local session = require "process.session"
local session_wakeup = session.wakeup

local lpack = require "pack"
local lpack_encode = lpack.encode
local lpack_decode = lpack.decode

local cf = require "cf"
local cf_fork = cf.fork


local ipairs = ipairs
local assert = assert

local strunpack = string.unpack
local tconcat = table.concat
local tunpack = table.unpack

local class = require "class"

local Channel = class("Channel")

function Channel:ctor()
  self.id = dataset.get('pid')
end

function Channel:send(...)
  if not self.queue then
    self.queue = {}
    cf_fork(function ()
      for _, buf in ipairs(self.queue) do
        self.sock:send(buf)
      end
      self.queue = nil
    end)
  end
  self.queue[#self.queue + 1] = lpack_encode(...)
  return true
end

function Channel:recv()
  local data = self.sock:recv(4)
  if not data then
    return self.sock:close()
  end
  local buffers = {data}
  local len = strunpack("<I4", data)
  if len <= 4 then
    return true
  end
  len = len - 4
  while true do
    local buf, dsize = self.sock:recv(len)
    if not buf then
      return self.sock:close()
    end
    buffers[#buffers+1] = buf
    if dsize == len then
      break
    end
    len = len - dsize
  end
  return true, lpack_decode(tconcat(buffers))
  -- return true, {lpack_decode(tconcat(buffers))}
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
        self:send(self.id)
        break
      end
    end
    return true
  end
end

return Channel