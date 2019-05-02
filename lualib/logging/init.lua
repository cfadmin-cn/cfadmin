-- logging 核心配置
local class = require "class"
local system = require "system"
local now = system.now
local type = type
local print = print
local assert = assert
local pairs = pairs
local tostring = tostring
local getmetatable = getmetatable

local modf = math.modf
local debug_getinfo = debug.getinfo
local os_date = os.date
local io_open = io.open
local format = string.format
local concat = table.concat
local modf = math.modf


-- 格式化时间: [年-月-日 时:分:秒,毫秒]
local function fmt_Y_m_d_H_M_S()
  local ts, f = modf(now())
  f = format("%03.0f", f * 1e3)
  return concat({'[', os_date('%Y-%m-%d %H:%M:%S'), ',', f, ']'})
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
  local tab = {}
  while 1 do
    local mt = getmetatable(t)
    for key, value in pairs(t) do
      local k, v
      if type(key) == 'number' then
          k = concat({'[', key, ']'})
      else
          k = concat({'["', key, '"]'})
      end
      if type(value) == 'table' then
        if t ~= value then
          v = table_format(value)
        else
          v = tostring(value)
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

local function fmt(...)
  local args = {...}
  local index, len = 1, select('#', ...)
  local tab = {}
  while 1 do
    local arg = args[index]
    if type(arg) == 'table' then
      tab[#tab+1] = table_format(arg)
    else
      tab[#tab+1]= tostring(arg)
    end
    if index >= len then
      break
    end
    index = index + 1
  end
  return concat(tab, ', ')
end

-- 格式化日志
function FMT (where, level, ...)
  return concat({ fmt_Y_m_d_H_M_S(), where, level, ':', fmt(...), '\n'}, ' ')
end

local Log = class("Log")

function Log:ctor (opt)
  if type(opt) == 'table' then
    self.to_dump = opt.dump
    self.path = opt.path
    self.now = Y_m_d()
  end
end

-- 常规日志
function Log:INFO (...)
  print(FMT("\27[32m"..debuginfo(), "[INFO]".."\27[0m", ...))
  self:dump(FMT(debuginfo(), "[INFO]", ...))
end

-- 错误日志
function Log:ERROR (...)
  print(FMT("\27[31m"..debuginfo(), "[ERROR]".."\27[0m", ...))
  self:dump(FMT(debuginfo(), "[ERROR]", ...))
end

-- 调试日志
function Log:DEBUG (...)
  print(FMT("\27[36m"..debuginfo(), "[DEBUG]".."\27[0m", ...))
  self:dump(FMT(debuginfo(), "[DEBUG]", ...))
end

-- 警告日志
function Log:WARN (...)
  print(FMT("\27[33m"..debuginfo(), "[WARN]".."\27[0m", ...))
  self:dump(FMT(debuginfo(), "[WARN]", ...))
end

-- dump日志到磁盘
function Log:dump(log)
  if self.to_dump and self.path then
    if not self.file then
      self.file, err = io_open('logs/'..self.path..'_'..self.now..'.log', 'a')
    else
      local now = Y_m_d()
      if now ~= self.now then
        self.file:close()
        self.now = now
        self.file = io_open('logs/'..self.path..'_'..self.now..'.log', 'a')
      end
    end
    self.file:write(log):flush()
  end
end

return Log
