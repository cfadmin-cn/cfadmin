-- logging 核心配置
local cf = require "cf"
local cf_at = cf.at

local aio = require "aio"
local aio_fflush = aio.fflush

local class = require "class"

local sys = require "sys"
local now = sys.now
local new_tab = sys.new_tab

local os_date = os.date

local type = type
local select = select
local assert = assert
local pairs = pairs
local tostring = tostring

local modf = math.modf
local toint = math.tointeger
local debug_getinfo = debug.getinfo
local io_open = io.open
local io_write = io.write
local io_type = io.type
local fmt = string.format
local concat = table.concat

-- 可以在这里手动设置是否使用异步日志
local ASYNC = true
-- 这里可以设置异步所使用的buffer.
local ASYNC_BUFFER_SIZE = 1 << 20

if ASYNC and io_type(io.output()) == 'file' then
  local output = io.output()
  output:setvbuf("full", ASYNC_BUFFER_SIZE)
  local at = cf_at(0.5, function ()
    aio_fflush(output)
  end)
end

-- 格式化时间: [年-月-日 时:分:秒,毫秒]
local function fmt_Y_m_d_H_M_S()
  local ts, f = modf(now())
  return concat({'[', os_date('%Y-%m-%d %H:%M:%S', ts), ',', fmt("%003d", modf(f * 1e3)), ']'})
end

-- 格式化时间: [年-月-日 时:分:秒]
local function Y_m_d()
  return os_date('%Y-%m-%d')
end

-- LOG函数的调用信息
local function debuginfo ()
  local info = debug_getinfo(3, 'Sln')
  return concat({'[', info.source, ':', info.currentline, ']'})
end

-- 格式化
local function table_format(tab)
  local list = {}
  for key, value in pairs(tab) do
    local k, v
    if type(key) == 'number' then
      k = concat({'[', key, ']'})
    elseif type(key) == 'string' then
      k = concat({'["', key, '"]'})
    else
      k = concat({'[', tostring(key), ']'})
    end
    if type(value) == 'table' then
      if key ~= '__index' then
        v = table_format(value)
      end
    elseif type(value) == 'string' then
      v = concat({'"', value, '"'})
    elseif value then
      v = tostring(value)
    end
    if k and v then
      list[#list+1] = concat({k, '=', v})
    end
  end
  return concat({tab.__name or "", '{', concat(list, ', '), '}'})
end

local function info_fmt(...)
  local args = {...}
  local index, len = 1, select('#', ...)
  local tab = new_tab(16, 0)
  while 1 do
    local arg = args[index]
    if type(arg) == 'table' then
      tab[#tab+1] = table_format(arg)
    else
      if type(arg) == 'string' then
        tab[#tab+1]= '"' .. tostring(arg) .. '"'
      else
        tab[#tab+1]= tostring(arg)
      end
    end
    if index >= len then
      break
    end
    index = index + 1
  end
  return concat(tab, ', ')
end

-- 格式化日志
local function FMT (where, level, ...)
  return concat({ fmt_Y_m_d_H_M_S(), where, level, ':', info_fmt(...), '\n'}, ' ')
end

local Log = class("Log")

function Log:ctor (opt)
  if type(opt) == 'table' then
    self.counter = 0
    self.sync = opt.sync
    self.dumped = opt.dump
    self.path = opt.path
    self.today = Y_m_d()
    self.buffer_size = toint(opt.buffer_size)
  end
end

-- 常规日志
function Log:INFO (...)
  local info = debuginfo()
  io_write(FMT("\27[32m"..info, "[INFO]".."\27[0m", ...))
  if not self.dumped or type(self.path) ~= 'string' then
    return
  end
  self:dump(FMT(info, "[INFO]", ...))
end

-- 错误日志
function Log:ERROR (...)
  local info = debuginfo()
  io_write(FMT("\27[31m"..info, "[ERROR]".."\27[0m", ...))
  if not self.dumped or type(self.path) ~= 'string' then
    return
  end
  self:dump(FMT(info, "[ERROR]", ...))
end

-- 调试日志
function Log:DEBUG (...)
  local info = debuginfo()
  io_write(FMT("\27[36m"..info, "[DEBUG]".."\27[0m", ...))
  if not self.dumped or type(self.path) ~= 'string' then
    return
  end
  self:dump(FMT(info, "[DEBUG]", ...))
end

-- 警告日志
function Log:WARN (...)
  local info = debuginfo()
  io_write(FMT("\27[33m"..info, "[WARN]".."\27[0m", ...))
  if not self.dumped or type(self.path) ~= 'string' then
    return
  end
  self:dump(FMT(info, "[WARN]", ...))
end

-- 可以在这里手动设置日志路径
local LOG_FOLDER = 'logs/'

-- 异步写入(主线程负责写缓存, 刷写磁盘工作交由工作线程)
local function async_write(self, log)
  if not self.timer then
    self.timer = cf_at(0.5, function ( )
      if self.oldfile then
        self.oldfile:close()
        self.oldfile = nil
      end
      --[[
        开始根据counter来决定是否刷写磁盘, 如果counter数量大于0的时候说明需要;
        这可以减少空闲时间的无效操作, 也可以减少一些特殊情况下的性能损耗问题;
      ]]
      if self.counter % (self.buffer_size or ASYNC_BUFFER_SIZE) == 0 then
        self.counter = 0
        return
      end
      if self.file then
        self.counter = 0
        aio_fflush(self.file)
      end
    end)
  end
  self.counter = self.counter + #log
  return self.file:write(log)
end

-- 同步写入(直接刷写到磁盘)
local function sync_write(self, log)
  return self.file:write(log)
end

-- dump日志到磁盘
function Log:dump(log)
  local today = Y_m_d()
  if today ~= self.today then
    self.today = today
    if self.file then
      self.oldfile = self.file
      self.file = nil
    end
  end
  if not self.file then
    self.file = assert(io_open(LOG_FOLDER..self.path..'_'..self.today..'.log', 'a+'))
    if not self.sync and ASYNC then
      self.file:setvbuf("full", self.buffer_size or ASYNC_BUFFER_SIZE)
    end
  end
  --[[
    `全局配置`和`指定配置`都将使用`同步`的方式刷写日志
  ]]
  if self.sync or not ASYNC then
    return sync_write(self, log)
  end
  return async_write(self, log)
end

return Log