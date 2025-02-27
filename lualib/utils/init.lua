local type = type
local pairs = pairs
local print = print
local tostring = tostring

local getmetatable = getmetatable
local setmetatable = setmetatable

local mtype = math.type or function (v)
  return type(v) == 'number' and
    (v % 1 == 0 and 'integer' or 'float') or 'nil'
end

local debug_getinfo = debug.getinfo

local strrep = string.rep
local strfmt = string.format

local tconcat = table.concat
local tinsert = table.insert

local r = debug.getregistry()
local l, g = r._LOADED, _G

local V = tonumber(_VERSION:sub(4))

local function space(level)
  return strrep('    ', level)
end

local function tokey(key)
  if type(key) ~= 'string' then
    return strfmt("%s", key)
  end
  return strfmt("%q", key)
end

local array_mt = r['Lua.Array']
local function isarray(tab)
  if #tab > 0 then
    return true
  end
  return array_mt and getmetatable(tab) == array_mt
end

---comment 格式化打印变量`tab`.
---@param tab   any        @指定指定变量
---@param meta  boolean?   @是否跟进元表
---@param level integer?   @指定打印层级
local function var_dump(tab, meta, level)
  if type(tab) ~= 'table' then
    return strfmt("%s\n", tostring(tab))
  end
  local ptab = {}
  -- 拆分
  local M, I
  if meta then
    M = getmetatable(tab)
    if M then
      setmetatable(tab, nil)
      tab.__metatable__ = M
    end
  end
  if tab.__index == tab then
    I = tab.__index
    tab.__index = nil
  end
  local n = 0
  local olevel = level
  level = level + 1
  for k, v in pairs(tab) do
    if type(k) ~= 'number' and type(k) ~= 'string' then
      k = tostring(k)
    end
    if type(v) == "number" then
      if mtype(v) == 'float' then
        tinsert(ptab, strfmt('%s[%s] = Number(%s),\n', space(level), tokey(k), v))
      else
        tinsert(ptab, strfmt('%s[%s] = Integer(%d),\n', space(level), tokey(k), v))
      end
    elseif type(v) == 'boolean' then
      tinsert(ptab, strfmt('%s[%s] = Boolean(%s),\n', space(level), tokey(k), v))
    elseif type(v) == 'table' then
      if v == g or v == l then
        tinsert(ptab, strfmt('%s[%s] = %s,\n', space(level), tokey(k), tostring(v)))
      else
        tinsert(ptab, strfmt('%s[%s] = %s', space(level), tokey(k), var_dump(v, meta, level)))
      end
    elseif type(v) == 'string' then
      tinsert(ptab, strfmt('%s[%s] = String(%q),\n', space(level), tokey(k), v))
    elseif type(v) == 'function' then
      local info = debug_getinfo(v)
      if info.linedefined > 0 then
        if V > 5.3 then
          tinsert(ptab, strfmt('%s[%s] = LuaFunction(%p%s),\n', space(level), tokey(k), v, info.source .. ':' .. info.linedefined))
        else
          tinsert(ptab, strfmt('%s[%s] = %s(%s),\n', space(level), tokey(k), v, info.source .. ':' .. info.linedefined))
        end
      else
        if V > 5.3 then
          tinsert(ptab, strfmt('%s[%s] = LuaCFunction(%p),\n', space(level), tokey(k), tostring(v)))
        else
          tinsert(ptab, strfmt('%s[%s] = c%s,\n', space(level), tokey(k), tostring(v)))
        end
      end
    else
      tinsert(ptab, strfmt('%s[%s] = %s,\n', space(level), tokey(k), tostring(v)))
    end
    n = n + 1
  end
  -- 还原
  if meta then
    if M then
      setmetatable(tab, M)
      tab.__metatable__ = nil
    end
  end
  if I then
    tab.__index = I
  end
  local left, right = "{\n", "%s}%s\n"
  if n == #tab and isarray(tab) then
    left, right = "[\n", "%s]%s\n"
  end
  return left .. tconcat(ptab) .. strfmt(right, space(olevel), olevel == 0 and "" or ",")
end

---comment Dump表结构
---@param tab    any       @格式化打印当前表结构
---@param meta?  boolean   @将元表结构也打印出来
_G.var_dump = function (tab, meta)
  print(var_dump(tab, meta, 0))
end