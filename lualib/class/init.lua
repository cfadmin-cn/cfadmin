local type = type
local setmetatable = setmetatable
local new_tab = require "sys".new_tab

-- 一个精简版的类实现
return function (cls_name)
  local cls = {}
  cls.__name = cls_name
  cls.__index = cls
  cls.__call = function (c, ...)
    local call = c[cls_name]
    if type(call) ~= 'function' then
      return
    end
    return call(c, ...)
  end
  cls.new = function (c, ...)
    if cls ~= c then
      return print("Please use ':' to create new object :)")
    end
    local obj = new_tab(0, 16)
    local ctor = cls.ctor
    if not ctor then
      return print("Can't find ctor to init.")
    end
    ctor(obj, ...)
    return setmetatable(obj, cls)
  end
  return cls
end