local sys = require "sys"
local now = sys.now
local is_ipv4 = sys.ipv4
local is_ipv6 = sys.ipv6

local type = type
local pairs = pairs
local ipairs = ipairs

local os_date = os.date
local os_time = os.time

local modf = math.modf

local fmt = string.format

local System = {
  -- 类型转换函数
  toint = math.modf,
  tonumber = tonumber,
  tostring = tostring,
}

-- 以下为类型判断函数

-- 是否为整数类型
function System.is_int(number)
  if type(number) ~= 'number' then
    return false
  end
  local int, float = modf(number)
  return float == 0.
end

-- 是否为浮点型
function System.is_float(number)
  if type(number) ~= 'number' then
    return false
  end
  local int, float = modf(number)
  return float ~= 0.
end

-- 是否字符串类型, empty = true则追加判断字符串是否为空
function System.is_string(str, empty)
  if type(str) == 'string' then
    if empty and str == '' then
      return false
    end
    return true
  end
  return false
end

-- 判断字符串是否IP地址
function System.is_ip(str)
  if type(str) ~= 'string' or str == '' then
    return false, "ip need a string type."
  end
  if is_ipv4(str) then
    return true, 4
  end
  if is_ipv4(str) then
    return true, 6
  end
  return false, 'string not ipv4 or ipv6.'
end

-- 判断字符串是否ipv4
function System.is_ipv4(str)
  if type(str) ~= 'string' or str == '' then
    return false, "ip need a string type."
  end
  if is_ipv4(str) then
    return true
  end
  return false, 'string not ipv4.'
end

-- 判断字符串是否ipv6
function System.is_ipv6(str)
  if type(str) ~= 'string' or str == '' then
    return false, "ip need a string type."
  end
  if is_ipv6(str) then
    return true
  end
  return false, 'string not ipv6.'
end

-- 是否数组成员
function System.is_array_member(array, value)
  for _, val in ipairs(array) do
    if val == value then
      return true
    end
  end
  return false
end

-- 是否哈希表成员
function System.is_table_member(tab, value)
  for _, val in pairs(tab) do
    if val == value then
      return true
    end
  end
  return false
end

-- 返回微秒级别的时间戳
function System.now()
  return now()
end

-- 返回timestamp当日的临晨与午夜的时间戳
function System.same_day(timestamp)
  local date_tab = os_date("*t", timestamp)
  local year, month, day = date_tab.year, date_tab.month, date_tab.day
  local time_start = {year = year, month = month, day = day, hour = 0, min = 0, sec = 0}
  local time_end = {year = year, month = month, day = day, hour = 23, min = 59, sec = 59}
  return os_time(time_start), os_time(time_end)
end

return System
