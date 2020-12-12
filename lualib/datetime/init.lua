local type = type
local assert = assert

local sys = require "sys"
local os_now = sys.now
local os_time = os.time
local os_date = os.date
local difftime = os.difftime

local match = string.match
local fmt = string.format

local abs = math.abs
local toint = math.tointeger

local datetime = {}

--[[
时间日期格式化符号：
%y 两位数的年份表示（00-99）
%Y 四位数的年份表示（000-9999）
%m 月份（01-12）
%d 月内中的一天（0-31）
%H 24小时制小时数（0-23）
%I 12小时制小时数（01-12）
%M 分钟数（00=59）
%S 秒（00-59）

%a 本地简化星期名称
%A 本地完整星期名称
%b 本地简化的月份名称
%B 本地完整的月份名称
%c 本地相应的日期表示和时间表示
%j 年内的一天（001-366）
%p 本地A.M.或P.M.的等价符
%U 一年中的星期数（00-53）星期天为星期的开始
%w 星期（0-6），星期天为星期的开始
%W 一年中的星期数（00-53）星期一为星期的开始
%x 本地相应的日期表示
%X 本地相应的时间表示
%Z 当前时区的名称
%% %号本身

例如:　　"Tue May 31 17:46:55 +0800 2011" 对应 "%a %b %d %H:%M:%S %Z %Y" +0800为中国的时区代码(东八区)
]]

-- DATETIME 时间格式
function datetime.datetime(timestamp)
  return os_date("%F %X", timestamp or os_time())
end

-- ISO 8601表示法 - 1
function datetime.iso8601( timestamp )
  return os_date("%FT%X", timestamp or os_time()) .. datetime.timezone2()
end

-- ISO 8601表示法 - 2
function datetime.iso8601_2( timestamp )
  return os_date("%Y%m%dT%H%M%S", timestamp or os_time()) .. datetime.timezone2()
end

-- 格林威治时间
function datetime.greenwich( timestamp )
  return os_date("%a, %d %b %Y %X GMT", timestamp or os_time())
end

-- 本地时间表示法
function datetime.localtime( timestamp )
  return os_date("%c", timestamp or os_time())
end

-- 当前所在时区
function datetime.timezone()
  local time = difftime(os_time(), os_time(os_date("!*t")))
  return toint(time // 3600)
end

-- 当前所在时区
function datetime.timezone2()
  local time = difftime(os_time(), os_time(os_date("!*t")))
  if abs(time) ~= time then
    return fmt("-%02d:00", abs(time // 3600))
  end
  return fmt("+%02d:00", toint(time // 3600))
end

-- 凌晨 - 秒级时间戳
function datetime.dawn(timestamp)
  local time = os_date("*t", timestamp)
  return os_time { year = time.year, month = time.month, day = time.day, hour = 0, min = 0, sec = 0 }
end

-- 午夜 - 秒级时间戳
function datetime.midnight(timestamp)
  local time = os_date("*t", timestamp)
  return os_time { year = time.year, month = time.month, day = time.day, hour = 23, min = 59, sec = 59 }
end

-- 毫秒级时间戳
function datetime.mtime()
  return toint((os_now() * 1e3) // 1)
end

-- 秒级时间戳
function datetime.time()
  return os_time()
end

-- DATETIME 转换为秒级时间戳
function datetime.from_timestamp(dt)
  assert(type(dt) == 'string' and dt ~= '', "Invalide datetime format.")
  local year, month, day, hour, min, sec = match(dt, '([%d]-)[%-/]?([%d]-)[%-/]?([%d]-)[T ]+([%d]+):([%d]+):([%d]+)')
  return os_time { year = year, month = month, day = day, hour = hour, min = min, sec = sec }
end

-- DATETIME 转换为毫秒级时间戳
function datetime.from_timestamp2(dt)
  assert(type(dt) == 'string' and dt ~= '', "Invalide datetime format.")
  local year, month, day, hour, min, sec, ms = match(dt, '([%d]-)[%-/]?([%d]-)[%-/]?([%d]-)[T ]+([%d]+):([%d]+):([%d]+)[%., ]+([%d]+)')
  local ms = ms:sub(1, 3)
  if #ms < 3 then
    local ms = toint(ms)
    if ms < 100 then
      if ms < 10 then
        ms = ms * 10
      end
      ms = ms * 10
    end
  end
  return toint(os_time { year = year, month = month, day = day, hour = hour, min = min, sec = sec } * 1e3 + ms)
end

return datetime