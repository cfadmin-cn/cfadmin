local ti = require "internal.Timer"
local co = require "internal.Co"
local udp = require "udp"
local class = require "class"

local co_new = co.new
local co_self = co.self
local co_wakeup = co.wakeup
local co_wait = co.wait

local G_Reference = {}
local tab = debug.getregistry()
tab['__G_UDP__'] = G_Reference

local UDP = class("UDP")

function UDP:ctor(opt)
  self.udp = udp.new()
  G_Reference[self] = true
end

-- 超时时间
function UDP:timeout(Interval)
  if Interval and Interval > 0 then
    self._timeout = Interval
  end
  return self
end

function UDP:connect(ip, port)
  self.fd = udp.connect(ip, port)
  if not self.fd or self.fd <= 0 then
    return nil, "Can't Creat UDP Socket"
  end
  return true
end

function UDP:recv(...)
  if self.udp then
    local co = co_self()
    self.read_co = co_new(function ( ... )
      local data, len = udp.recv(self.fd)
      if self.timer then
        self.timer:stop()
        self.timer = nil
      end
      udp.stop(self.udp)
      self.read_co = nil
      if data then
        return co_wakeup(co, data, len)
      end
      return co_wakeup(co, nil, '未知的udp错误')
    end)
    self.timer = ti.timeout(self._timeout, function ( ... )
      udp.stop(self.udp)
      self.read_co = nil
      self.timer = nil
      return co_wakeup(co, nil, 'udp_recv timout(超时)..')
    end)
    udp.start(self.udp, self.fd, self.read_co)
    return co_wait()
  end
end

function UDP:send(data)
  if type(data) ~= 'string' or not self.fd or self.fd <= 0 then
    return
  end
  return udp.send(self.fd, data, #data)
end

function UDP:close()
  if self.udp then
    udp.stop(udp)
    self.udp = nil
  end

  if self.timer then
    ti.stop(self.timer)
    self.timer = nil
  end

  if self.fd then
    udp.close(self.fd)
    self.fd = nil
  end

  if self._timeout then
    self._timeout = nil
  end

  G_Reference[self] = nil
end

return UDP
