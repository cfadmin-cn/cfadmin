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
local ipairs = ipairs
local tostring = tostring
local getmetatable = getmetatable

local modf = math.modf
local debug_getinfo = debug.getinfo
local io_open = io.open
local io_write = io.write
local io_flush = io.flush
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
local function table_format(t)
  local tab = new_tab(16, 0)
  while 1 do
    local mt = getmetatable(t)
    for key, value in pairs(t) do
      local k, v
      if type(key) == 'number' then
        k = concat({'[', key, ']'})
      elseif type(key) == 'string' then
        k = concat({'["', key, '"]'})
      else
        k = concat({'[', tostring(key), ']'})
      end
      if type(value) == 'table' then
        if t ~= value then
          v = table_format(value)
        else
          if type(value) == 'table' then
            v = table_format(value)
          else
            v = tostring(value)
          end
        end
      elseif type(value) == 'string' then
        v = concat({'"', value, '"'})
      else
        v = tostring(value)
      end
      tab[#tab+1] = concat({k, '=', v})
    end
    if not mt or mt == t then
      break
    end
    t = mt
  end
  return concat({'{', concat(tab, ', '), '}'})
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
    self.sync = opt.sync
    self.dumped = opt.dump
    self.path = opt.path
    self.today = Y_m_d()
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

-- 异步写入(写缓存, 刷新工作交由工作线程)
function Log:async_write(log)
  if not self.timer then
    self.timer = cf_at(0.5, function ( ... )
      if self.oldfile then
        self.oldfile:close()
        self.oldfile = nil
      end
      if self.file then
        aio_fflush(self.file) -- 使用单独的进程刷写数据到磁盘, 以此减少线程阻塞的可能性.
      end
    end)
  end
  return self.file:write(log)
end

-- 同步写入(直接刷写到磁盘)
function Log:sync_write(log)
  return self.file:write(log)
end


-- dump日志到磁盘
function Log:dump(log)
  local today = Y_m_d()
  if today ~= self.today then
    if self.file then
      self.oldfile = self.file
      self.file = nil
    end
  end
  if not self.file then
    local file, err = io_open(LOG_FOLDER..self.path..'_'..today..'.log', 'a+')
    if not file then
      return io_type(io.output()) == 'file' and io_write('打开文件失败: '..(('['..err..']') or '')..'\n')
    end
    self.file, self.today = file, today
    if self.async and ASYNC then
      file:setvbuf("full", ASYNC_BUFFER_SIZE)
    else
      file:setvbuf("line")
    end
  end
  if not self.sync then
    if not ASYNC then
      return self:async_write(log)
    end
  end
  return self:sync_write(log)
end

return Log
