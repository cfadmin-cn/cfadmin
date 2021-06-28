local type = type
local assert = assert
local getmetatable = getmetatable
local setmetatable = setmetatable

-- 所有对象的基类
local META = { __META_CLASS__ = true }

META.__index = META

META.new = function (M, ...)
  assert(META == getmetatable(M), "[Lua-CLASS ERROR]: Must use `:` to create object.")
  local ctor = M.ctor
  local obj = setmetatable({}, M)
  assert(ctor and type(ctor) == 'function' and ctor, "[Lua-CLASS ERROR]: Can't find `ctor` to init.")(obj, ...)
  return obj
end

META.__call = function (M, ...)
  local meta = getmetatable(M)
  if meta == META then
    return M:new(...);
  end
  return assert(getmetatable(M) == META and M['__name'], "[Lua-CLASS ERROR]: Invalid class arguments.")(M, ...);
end

---comment  `Class`是内部的所有对象用来实现面向对象的方法.
---@param cname? string                  @自定义类名
---@param meta?  table | function | nil  @自定义类行为
---@return table                         @返回一个类
return function (cname, meta)
  local cls = { __name = cname }
  cls.__index = meta or cls
  return setmetatable(cls, META)
end