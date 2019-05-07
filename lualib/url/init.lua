local tonumber = tonumber
local byte = string.byte
local char = string.char
local fmt = string.format
local spliter = string.gsub

local url = {}

-- urlencode编码
function url.encode(s)
    return spliter(spliter(s, "([^%w%.%- ])", function(c) return fmt("%%%02X", byte(c)) end), " ", "+")
end

-- urlencode解码
function url.decode(s)
    return spliter(s, '%%(%x%x)', function(h) return char(tonumber(h, 16)) end)
end

return url
