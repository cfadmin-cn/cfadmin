local utils = {}

function utils.copy(tab)
  local t = {}
  for k, v in pairs(tab) do
    t[k] = v
  end
  return t
end

return utils