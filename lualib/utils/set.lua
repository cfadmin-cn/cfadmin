local type = type
local pairs = pairs
local assert = assert
local tostring = tostring
local setmetatable = setmetatable

local tconcat = table.concat

---@class Set @集合
local MetaSet = { map = {} }

MetaSet.__index = MetaSet

---comment 实例化`Set`
---@return Set
function MetaSet:new()
  return setmetatable({ count = 0, map = {} }, MetaSet)
end

---comment 插入元素
---@param value any  @待插入的元素
---@return boolean   @已存在返回`false`, 否则返回`true`
function MetaSet:insert(value)
  if not self.map[value] then
    self.map[value] = true
    self.count = self.count + 1
    return true
  end
  return false
end

---comment 删除元素
---@param value any  @待删除的元素
---@return boolean   @删除成功返回`true`, 否则返回`false`
function MetaSet:remove(value)
  if self.map[value] then
    self.map[value] = nil
    self.count = self.count - 1
    return true
  end
  return false
end

---comment 返回集合内的元素数量
---@return integer
function MetaSet:len()
  return self.count
end

---comment 是否为空
---@return boolean
function MetaSet:is_empty()
  return self.count == 0
end

---comment 美化打印输出
---@return string
function MetaSet:__tostring()
  local tab = {}
  for element in pairs(self.map) do
    tab[#tab+1] = tostring(element)
  end
  return "Set([" .. tconcat(tab, ', ') .. "])"
end

---comment 求差集
---@param t1 Set @集合1
---@param t2 Set @集合2
---@return Set   @新集合
function MetaSet.__sub(t1, t2)
  assert(type(t1) == 'table' and type(t2) == 'table', "[Set ERROR]: Invalid Set OP.")
  local t1_map, t2_map = t1.map, t2.map
  assert(type(t1_map) == 'table' and type(t2_map) == 'table', "[Set ERROR]: Invalid Set OP.")
  local Set = MetaSet.new()
  for k in pairs(t1_map) do
    if not t2_map[k] then
      Set:insert(k)
    end
  end
  return Set
end

---comment 求交集
---@param t1 Set @集合1
---@param t2 Set @集合2
---@return Set   @新集合
function MetaSet.__band (t1, t2)
  assert(type(t1) == 'table' and type(t2) == 'table', "[Set ERROR]: Invalid Set OP.")
  local t1_map, t2_map = t1.map, t2.map
  assert(type(t1_map) == 'table' and type(t2_map) == 'table', "[Set ERROR]: Invalid Set OP.")
  local Set = MetaSet.new()
  for k in pairs(t1_map) do
    if t2_map[k] then
      Set:insert(k)
    end
  end
  return Set
end

---comment 求并集
---@param t1 Set @集合1
---@param t2 Set @集合2
---@return Set   @新集合
function MetaSet.__bor (t1, t2)
  assert(type(t1) == 'table' and type(t2) == 'table', "[Set ERROR]: Invalid Set OP.")
  local t1_map, t2_map = t1.map, t2.map
  assert(type(t1_map) == 'table' and type(t2_map) == 'table', "[Set ERROR]: Invalid Set OP.")
  local Set = MetaSet.new()
  for k in pairs(t1_map) do
    Set:insert(k)
  end
  for k in pairs(t2_map) do
    Set:insert(k)
  end
  return Set
end

---comment 求并集
---@param t1 Set @集合1
---@param t2 Set @集合2
---@return Set   @新集合
function MetaSet.__add (t1, t2)
  assert(type(t1) == 'table' and type(t2) == 'table', "[Set ERROR]: Invalid Set OP.")
  local t1_map, t2_map = t1.map, t2.map
  assert(type(t1_map) == 'table' and type(t2_map) == 'table', "[Set ERROR]: Invalid Set OP.")
  local Set = MetaSet.new()
  for k in pairs(t1_map) do
    Set:insert(k)
  end
  for k in pairs(t2_map) do
    Set:insert(k)
  end
  return Set
end

return MetaSet