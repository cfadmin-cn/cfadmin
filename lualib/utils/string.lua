local type = type
local select = select
local assert = assert
local tonumber = tonumber

local string = string
local ssub = string.sub
local srep = string.rep
local sfind = string.find
local sbyte = string.byte
local sgsub = string.gsub
local sgmatch = string.gmatch

local mtype = math.type
local tconcat = table.concat

---comment 计算`pattern`在`text`中pos位置开始出现的总次数.
---@param text    string   @实际内容
---@param pattern string   @匹配内容
---@param pos     integer  @字符串
---@return string @返回拼接好的字符串
function string.count (text, pattern, pos)
  if mtype(pos) ~= 'integer' or pos < 1 then
    pos = 1
  end
  local count = 0
  while true do
    pos = sfind(text, pattern, pos)
    if not pos then
      break
    end
    count = count + 1
    pos = pos + 1
  end
  return count
end

---comment 以`text`为中心拼接`count`个`fill`在两侧.
---@param text   string   @实际内容
---@param fill   string   @填充字符
---@param count  integer  @填充数量
---@return string @返回拼接好的字符串
function string.center (text, fill, count)
  assert(type(text) == 'string' and type(fill) == 'string' , "Invalid string `text` or `fill`.")
  assert(type(count) == 'number' and tonumber(count) or count > 0, "Invalid fill `count`")
  local fill_text = srep(fill, count)
  return tconcat{ fill_text, text, fill_text }
end

---comment 判断指定字符串内容是否全部空格
---@param text string   @判断内容
---@return boolean      @如果`text`全是空格返回`true`, 否则返回`false`.
function string.allspace (text)
  return sfind(text or '', "^[ ]+$") and true or false
end

---comment 连接`1`个或`N`个字符串, 非可转换字符串的对象会抛出异常
---@return string
function string.join (...)
  if select("#", ...) <= 1 then
    return (...) or ''
  end
  return tconcat{...}
end

---comment 根据`sep`分割`text`字符串.
---@param text   string   @待分割的字符串
---@param sep    string   @分割用的分隔符
---@return table          @分割后的数组
function string.split(text, sep)
  assert(type(text) == 'string', "Invalid string `text`.")
  if not sep or type(sep) ~= 'string' or sep == ''  then
    sep = '%,'
  end
  local index = 1
  local list = {}
  for sub in sgmatch(text, "([^" .. sep .. "]*)") do
    list[index] = sub
    index = index + 1
  end
  if index == 1 then
    list[index] = text
  end
  return list
end

local function strip(text, sep, left, right)
  if left then
    text = sgsub(text, "^[" .. sep .."]+", "", 1)
  end
  if right then
    text = sgsub(text, "[" .. sep .."]+$", "", 1)
  end
  return text
end

---comment 移除字符串头、尾指定的字符
---@param text   string   @待分割的字符串
---@param sep    string   @移除用的分隔符
function string.strip (text, sep)
  assert(type(text) == 'string', "Invalid string `text`.")
  if not sep or type(sep) ~= 'string' or sep == ''  then
    sep = ' '
  end
  return strip(text, sep, true, true)
end

---comment 移除字符串头部指定的字符
---@param text   string   @待分割的字符串
---@param sep    string   @移除用的分隔符
function string.lstrip (text, sep)
  assert(type(text) == 'string', "Invalid string `text`.")
  if not sep or type(sep) ~= 'string' or sep == ''  then
    sep = ' '
  end
  return strip(text, sep, true, false)
end

---comment 移除字符串尾部指定的字符
---@param text string   @待分割的字符串
---@param sep  string   @移除用的分隔符
function string.rstrip (text, sep)
  assert(type(text) == 'string', "Invalid string `text`.")
  if not sep or type(sep) ~= 'string' or sep == ''  then
    sep = ' '
  end
  return strip(text, sep, false, true)
end

---comment 判断起始位置是否指定内容
---@param text    string  @待匹配内容
---@param sstring string  @其实内容
---@param start   integer @起始位置
function string.startswith(text, sstring, start)
  assert(type(text) == 'string', "Invalid string `text`.")
  assert(type(sstring) == 'string', "Invalid start string.")
  return sfind(text, '^' .. sstring,  start) and true or false
end

---comment 判断结束位置是否指定内容
---@param text    string  @待匹配内容
---@param estring string  @结束内容
---@param over    integer @结束位置
function string.endswith(text, estring, over)
  assert(type(text) == 'string', "Invalid string `text`.")
  assert(type(estring) == 'string', "Invalid end string.")
  return sfind(text, estring .. '$',  over) and true or false
end

---comment 将`text`里的`s1`替换为`s2`(最多`count`此)
---@param text  string  @原始内容
---@param s1    string  @匹配字符串
---@param s2    string  @替换字符串
---@param count number  @替换次数
---@return string       @替换后内容
function string.replace (text, s1, s2, count)
  assert(type(text) == 'string' and text ~= '', "Invalid text string.")
  assert(type(s1) == 'string' and s1 ~= '', "Invalid s1 string.")
  assert(type(s2) == 'string' and s2 ~= '', "Invalid s2 string.")
  local s = sgsub(text, s1, s2, count)
  return s
end

---comment 字符串转换为字节数组
---@param  text string  @待转换的字符串
---@return table        @转换后的字节数组
function string.tobytes(text)
  assert(type(text) == 'string' and text ~= '', "Invalid text string.")
  local list = {}
  for idx = 1, #text do
    list[#list+1] = sbyte(text, idx)
  end
  return list
end

---comment 向指定位置的字符串后插入字符串.
---@param text   string  @原始字符串
---@param pos    integer @待插入的位置
---@param str    string  @待插入的字符串
---@return string        @返回插入后的字符串内容
function string.insert(text, pos, str)
  assert(type(text) == 'string' and text ~= '', "Invalid text string.")
  assert(type(pos) == 'number', "Invalid pos integer.")
  assert(type(str) == 'string' and str ~= '', "Invalid text string.")
  return tconcat{ssub(text, 1, pos), str, ssub(text, pos + 1, -1)}
end

local _, liconv = pcall(require, "liconv")

---comment 替换iconv函数, 错误的实现会出现运行时错误.
---@param module table
---@param encode string  @需保证`module[encode]`行为与`liconv.to`行为一致
---@param decode string  @需保证`module[decode]`行为与`liconv.from`行为一致
function string.iconv(module, encode, decode)
  liconv = { to = module[encode], from = module[decode] }
end

---comment 使用iconv进行编码转换
---@param text     string  @文本内容
---@param encoding string  @目标编码
---@return string          @转换后的文本
function string.encode (text, encoding)
  assert(type(text) == 'string', "Invalid string `text`.")
  assert(type(encoding) == 'string', "Invalid string encoding.")
  return assert(type(liconv) == 'table' and liconv, "Lua iconv is not supported.").to(encoding, text)
end

---comment 使用iconv进行编码转换
---@param text     string  @文本内容
---@param decoding string  @原始编码
---@return string          @转换后的文本
function string.decode (text, decoding)
  assert(type(text) == 'string', "Invalid string `text`.")
  assert(type(decoding) == 'string', "Invalid string encoding.")
  return assert(type(liconv) == 'table' and liconv, "Lua iconv is not supported.").from(decoding, text)
end