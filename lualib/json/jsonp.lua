local json = require "json"
local json_encode = json.encode
local json_decode = json.decode

local sub = string.sub
local find = string.find
local concat = table.concat

local jsonp = {}

function jsonp.encode(callback_name, tab)
  return concat {callback_name, "(", json_encode(tab), ")"}
end

function jsonp.decode(str)
  local s, e = find(str, "%("), find(str, "%)", -1)
  if not s or not e or e <= s then
    return
  end
  return json_decode(sub(str, s + 1, e - 1))
end

return jsonp