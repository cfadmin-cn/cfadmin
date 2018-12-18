--[[
-- log.lua
--
-- Copyright (c) 2016 rxi
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
-- Modefy by CandyMi In 2018.12.18

log的内部方法包括:
log.trace(...)  紫色
log.debug(...)  天蓝色
log.info(...)   绿色
log.warn(...)   黄色
log.error(...)  红色
log.fatal(...)  粉色

log.usecolor
默认情况下: 这个为true！ 如果你的终端不支持ANSI颜色转义码, 请将它设置为false或者nil.

log.outfile
将log输出到outfile字符串指定的文件(路径).

log.level
请参考使用方法相关method

--]]

local concat = table.concat

local date = os.date

local open = io.open

local ceil = math.ceil

local floor = math.floor

local fmt = string.format


local log = { _version = "0.1.0" }

log.usecolor = true
log.outfile = nil
log.level = "trace"


local modes = {
  { name = "trace", color = "\27[34m", },
  { name = "debug", color = "\27[36m", },
  { name = "info",  color = "\27[32m", },
  { name = "warn",  color = "\27[33m", },
  { name = "error", color = "\27[31m", },
  { name = "fatal", color = "\27[35m", },
}


local levels = {}
for i, v in ipairs(modes) do
  levels[v.name] = i
end


local round = function(x, increment)
  increment = increment or 1
  x = x / increment
  return (x > 0 and floor(x + .5) or ceil(x - .5)) * increment
end


local _tostring = tostring

local tostring = function(...)
  local t = {}
  for i = 1, select('#', ...) do
    local x = select(i, ...)
    if type(x) == "number" then
      x = round(x, .01)
    end
    t[#t + 1] = _tostring(x)
  end
  return concat(t, " ")
end


for i, x in ipairs(modes) do
  local nameupper = x.name:upper()
  log[x.name] = function(...)
    
    -- Return early if we're below the log level
    if i < levels[log.level] then
      return
    end

    local msg = tostring(...)
    local info = debug.getinfo(2, "Sl")
    local lineinfo = info.short_src .. ":" .. info.currentline

    -- Output to console
    print(fmt("%s[%s][%s]%s %s: %s",
                        log.usecolor and x.color or "",
                        nameupper,
                        date("%Y/%m/%d %H:%M:%S"),
                        log.usecolor and "\27[0m" or "",
                        lineinfo,
                        msg))

    -- Output to log file
    if log.outfile then
      local fp = open(log.outfile, "a")
      fp:write(fmt("[%s][%s] %s: %s\n",
                                nameupper,
                                date("%Y/%m/%d %H:%M:%S"),
                                lineinfo,
                                msg))
      fp:close()
    end

  end

end


return log