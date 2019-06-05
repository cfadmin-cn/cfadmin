-- lua版实现
-- local tonumber = tonumber
-- local byte = string.byte
-- local char = string.char
-- local fmt = string.format
-- local spliter = string.gsub

-- C版实现
local encode = require("sys").urlencode
local decode = require("sys").urldecode

--[[
经过测试: 100万此编码/解码两者性能相差30倍, 正好是lua与C的性能差距.
]]

local url = {}

-- urlencode编码
function url.encode(s)
  -- return spliter(spliter(s, "([^%w%.%- ])", function(c) return fmt("%%%02X", byte(c)) end), " ", "+")
  return encode(s)
end

-- urldecode解码
function url.decode(s)
  -- return spliter(s, '%%(%x%x)', function(h) return char(tonumber(h, 16)) end)
  return decode(s)
end

return url
