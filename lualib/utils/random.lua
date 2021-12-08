local type = type
local assert = assert

local ssub = string.sub
local char = string.char

local mlog = math.log
local mexp = math.exp
local msqrt = math.sqrt
local mcos = math.cos
local msin = math.sin
local mrandom = math.random
local mrandomseed = math.randomseed

local NV_MAGIC = 4 * mexp(-0.5) / msqrt(2.0)

local PI2 = 2 * math.pi
local gauss_next = nil

local random = {}

---comment @同`math.randomseed`
function random.randomseed(...)
  return mrandomseed(...)
end

---comment @同`math.random`
---@return number
function random.random(...)
  return mrandom(...)
end

---comment 生成指定数量的字符数组
---@param num integer    @样品数量
---@return table
function random.generatechar(num)
  local list = {}
  for i = 1, num do
    list[i] = char(mrandom(0, 255))
  end
  return list
end

---comment 生成指定数量的随机整数数组
---@param x integer @随机数的最小值, 结果包含该值.
---@param y integer @随机数的最大值, 结果包含该值.
---@param num integer    @样品数量
---@return table
function random.generateint (x, y, num)
  local list = {}
  for i = 1, num do
    list[i] = mrandom(x, y)
  end
  return list
end

---comment 生成指定数量的随机实数数组
---@param x integer @随机数的最小值, 结果包含该值.
---@param y integer @随机数的最大值, 结果包含该值.
---@param num integer    @样品数量
---@return table
function random.generatefloat (x, y, num)
  local list = {}
  for i = 1, num do
    list[i] = random.uniform(x, y)
  end
  return list
end

---comment 将随机生成一个实数，它在`x`, `y`范围内。
---@param x integer @随机数的最小值, 结果包含该值.
---@param y integer @随机数的最大值, 结果包含该值.
---@return number
function random.uniform(x, y)
  return mrandom(x or 0, y or 4294967296) + mrandom()
end

---comment 返回给定`sequence`内的随机项。
---@param sequence string | table @可以是`数组`或`字符串`.
---@return any
function random.choice(sequence)
  local tp = type(sequence)
  if tp ~= 'string' and tp ~= 'table' then
    return
  end
  local len = #sequence
  if len < 1 then
    return
  end
  local rv = mrandom(1, len)
  if tp == 'table' then
    return sequence[rv]
  end
  return ssub(sequence, rv, rv)
end

---comment 打乱给定`sequence`内的顺序
---@param sequence table @数组结构
function random.shuffle(sequence)
  local len = #assert(sequence, "Invalid `sequence`")
  for i = 1, len, 1 do
    local j = mrandom(1, len)
    sequence[i], sequence[j] = sequence[j], sequence[i]
  end
  return sequence
end

---comment 根据给定`sequence`选取`num`个样品
---@param sequence table @样品数组
---@param num integer    @样品数量
function random.sample(sequence, num)
  local len = #assert(sequence, "Invalid `sequence`")
  assert(num and num <= len, "Invalid `num` or `sample` larger than population.")
  local idx_list = {}
  for i = 1, len do
    idx_list[i] = i
  end
  random.shuffle(idx_list)
  local list = {}
  for i = 1, num do
    list[i] = sequence[idx_list[i]]
  end
  return list
end

---comment 正态分布
---@param mean  number   @平均值
---@param sigma number   @标准差
---@return number
function random.normalvariate(mean, sigma)
  local z, zz, u1, u2
  while true do
    u1 = mrandom()
    u2 = 1.0 - mrandom()
    z = NV_MAGIC * (u1 - 0.5) / u2
    zz = z * z / 4.0
    if zz <= -mlog(u2) then
      break
    end
  end
  return mean + z * sigma
end

---comment 对数正态分布
---@param mean  number   @平均值
---@param sigma number   @标准差
---@return number
function random.lognormvariate(mean, sigma)
  return mexp(random.normalvariate(mean, sigma))
end

---comment 指数分布
---@param lambd number @lambd 是1.0除以所需的平均值.
function random.expovariate(lambd)
  return -mlog(1.0 - mrandom()) / lambd
end

---comment 高斯分布
---@param mean  number   @平均值
---@param sigma number   @标准差
function random.gauss(mean, sigma)
  local z = gauss_next
  gauss_next = nil
  if not z then
    local x2pi = mrandom() * PI2
    local g2rad = msqrt(-2.0 * mlog(1.0 - mrandom()))
    z = mcos(x2pi) * g2rad
    gauss_next = msin(x2pi) * g2rad
  end
  return mean + z * sigma
end

return random