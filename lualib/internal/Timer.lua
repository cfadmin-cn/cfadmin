local co = require "internal.Co"
local ti = require "timer"

local new_tab = require("sys").new_tab

local type = type
local ti_new = ti.new
local ti_start = ti.start
local ti_stop = ti.stop

local co_new = co.new
local co_wait = co.wait
local co_spawn = co.spawn
local co_wakeup = co.wakeup
local co_self = co.self

local co_wait_ex = coroutine.yield

local tremove = table.remove
local tinsert = table.insert

local Timer = new_tab(0, 1 << 10)

local Tlist = new_tab(1 << 10, 0)

-- 创建`Timer`对象
local function Timer_new()
  return tremove(Tlist) or ti_new()
end

-- 停止`Timer`对象
local function Timer_stop(self)
  Timer[self] = nil
  tinsert(Tlist, self.t)
  ti_stop(self.t)
  return true
end

-- 启动`Timer`对象
local function Timer_start(self)
  Timer[self] = self
  ti_start(self.t, self.timeout or self.repeats, self.co)
  return self
end

---comment 一次性定时器
---@param timeout   number   @超时时间
---@param callback  function @回调函数
function Timer.timeout(timeout, callback)
  if type(timeout) ~= 'number' or timeout <= 0 or type(callback) ~= 'function' then
    return
  end
  local timer = { t = Timer_new(), timeout = timeout, stoped = false }
  -- 实现`停止定时器`的方法
  timer.stop = function(self)
    if not self.stoped then
      self.stoped = true
      Timer_stop(self)
    end
    return true
  end
  -- 实现定时器回调协程
  timer.co = co_new(function()
    if timer.stoped then
      timer.co = nil
      return
    end
    co_spawn(callback)
    return Timer_stop(timer)
  end)
  -- 启动定时器
  return Timer_start(timer)
end

---comment 重复定时器
---@param repeats   number   @间隔时间
---@param callback  function @回调函数
function Timer.at(repeats, callback)
  if type(repeats) ~= 'number' or repeats <= 0 or type(callback) ~= 'function' then
    return
  end
  local timer = { t = Timer_new(), repeats = repeats, stoped = false }
  -- 实现`停止定时器`的方法
  timer.stop = function(self)
    if not self.stoped then
      self.stoped = true
      Timer_stop(self)
    end
    return true
  end
  -- 实现定时器回调协程
  timer.co = co_new(function()
    while true do
      if timer.stoped then
        timer.co = nil
        return
      end
      co_spawn(callback)
      co_wait_ex()
    end
  end)
  -- 启动定时器
  return Timer_start(timer)
end

---comment 休眠当前协程
---@param nsleep    number    @休眠时间(毫秒)
function Timer.sleep(nsleep)
  if type(nsleep) ~= 'number' or nsleep <= 0 then
    return
  end
  -- 创建`Timer`对象
  local timer = { t = Timer_new(), main_co = co_self(), timeout = nsleep }
  -- 实现定时器回调协程
  timer.co = co_new(function ()
    Timer_stop(timer)
    timer.co = nil
    return co_wakeup(timer.main_co)
  end)
  Timer_start(timer)
  return co_wait()
end

---comment 计算缓存的定时器对象数量
---@return integer
function Timer.count()
  return #Tlist
end

return Timer