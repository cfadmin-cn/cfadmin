local assert, type = assert, type
local getmetatable = getmetatable
local setmetatable = setmetatable

--`Anonymous`是所有对象的基类.
local Anonymous = { __META__ = true, __name = "Anonymous" }

Anonymous.__index = Anonymous

Anonymous.new = function (M, ...)
  assert(Anonymous == getmetatable(M), "[Lua-CLASS ERROR]: Must use `:` to create object.")
  local ctor = M.ctor
  local obj = setmetatable({}, M)
  assert(ctor and type(ctor) == 'function' and ctor, "[Lua-CLASS ERROR]: Can't find `ctor` to init.")(obj, ...)
  return obj
end

Anonymous.__call = function (M, ...)
  local meta = getmetatable(M)
  if meta == Anonymous then
    return M:new(...);
  end
  return assert(getmetatable(M) == Anonymous and M['__name'], "[Lua-CLASS ERROR]: Invalid class arguments.")(M, ...);
end

return Anonymous