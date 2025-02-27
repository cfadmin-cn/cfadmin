local pairs, type = pairs, type
local getmetatable = getmetatable
local setmetatable = setmetatable

local V = tonumber(_VERSION:sub(4))

-- 这里定义的字段不会被主动继承
local inheritance = { __name = true, __index = true, __metatable = true }

---@class META
local Anonymous = { __name = "Anonymous", ctor = nil }

---comment 索引自身
Anonymous.__index = Anonymous

---comment 字符串化
function Anonymous.__tostring(M, ...)
  if V and V > 5.3 then
    return string.format("%s: %p", M.__name, M)
  end
  return M.__name
end

local function class_init(M, ...)
  if getmetatable(M) ~= Anonymous then
    error("[class error]: You must use the `cls(...)` to create an object.", 2)
  end
  local obj = setmetatable({}, M)
  local ctor = obj.ctor
  if type(ctor) == 'function' then
    ctor(obj, ...)
  end
  return obj
end

---comment 使用cls(...)语法创建对象
---@generic T : META
---@param M   META
---@param ... any
---@return T
function Anonymous.__call(M, ...)
  return class_init(M, ...)
end

---comment 使用cls:new(...)语法创建对象
---@generic T : META
---@param M   META
---@param ... any
---@return T
---@deprecated
function Anonymous.new(M, ...)
  return class_init(M, ...)
end

---comment  此函数返回`Lua`类, 所有内部`class`实现均使用它.
---@param cname string?    @自定义类名(可选)
---@param cmeta META?      @继承的父类(可选)
---@return META
local function class_define(cname, cmeta)
  local cls = {}
  if cmeta and getmetatable(cmeta) == Anonymous then
    for k, v in pairs(cmeta) do
      if not inheritance[k] then
        cls[k] = v
      end
    end
  end
  cls.__index = cls; cls.__name = cname;
  return setmetatable(cls, Anonymous)
end

---@class ClassWraper
local class = { __record = false }
class.__index = class

function class:__call(cname, cmeta)
  -- 记录类信息
  if self.__record then
    local list = self.__list__
    if not self.__list__ then
      list = {}
      self.__list__ = list
    end
    local info = debug.getinfo(2)
    if cname and cmeta then
      list[#list+1] = string.format("class `%s`: public `%s` (%s:%s)", cname, tostring(cmeta):gsub(':(.*)', ''), info.short_src, info.currentline)
    else
      list[#list+1] = string.format("class `%s` (%s:%s)", cname and tostring(cname) or 'Unknown', info.short_src, info.currentline)
    end
  end
  -- 记录类信息
  return class_define(cname, cmeta)
end

---comment 返回对象引用信息数组
---@return table
function class:dump()
  return self.__list__
end

---comment 当前服务对象注册记录
---@param op boolean @默认为`false`
function class:enable_recorded(op)
  self.__record = op
end

return setmetatable({}, class)