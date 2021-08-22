local type, pairs = type, pairs
local getmetatable = getmetatable
local setmetatable = setmetatable

local metaclass = require "class.meta"

---comment  `class`是内部的所有对象用来实现面向对象的方法.
---@param cname? string                  @自定义类名
---@param cmeta?  table  | nil            @自定义父类
---@return table                         @返回一个类
return function (cname, cmeta)
  local cls = { __name = cname }
  if getmetatable(cmeta) == metaclass then
    for k, v in pairs(cmeta) do
      if type(v) == 'function' or (k ~= '__name' and k ~= '__index' and k ~= '__metatable') then
        cls[k] = v
      end
    end
  end
  cls.__index = cls
  return setmetatable(cls, metaclass)
end