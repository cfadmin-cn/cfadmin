local utils = require "process.utils"
local dataset = {}

local data = {}

if master then
  data = utils.copy(master)
elseif worker then
  data = utils.copy(worker)
else
  error("[process error]: Cannot run in single process mode.")
end

---comment 获得当前进程的数据
---@param key any
function dataset.get(key)
  return data[key]
end

---comment 修改当前进程的数据
---@param key any
function dataset.set(key, val)
  data[key] = val
end

return dataset