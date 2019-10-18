local crypt = require "crypt"
local md5 = crypt.md5

local pairs = pairs
local ipairs = ipairs
local sort = table.sort
local concat = table.concat

local __Version__ = 0.1

return function (mchid, key, map)
  map["mchid"] = mchid
  local keys = {}
  for key, value in pairs(map) do
    if value ~= '' then
      keys[#keys+1] = key
    end
  end
  sort(keys)
  local args = {}
  local parms = {}
  for index, key in ipairs(keys) do
    local k, v = key, map[key]
    args[#args+1] = {k, v}
    parms[#parms+1] = k .. '=' .. v
  end
  parms[#parms+1] = "key=" .. key
  args[#args+1] = {"sign", md5(concat(parms, "&"), true):upper()}
  return args
end