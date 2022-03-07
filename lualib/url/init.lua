local type = type
local assert = assert
local setmetatable = setmetatable

local strsub = string.sub
local strbyte = string.byte
local strfind = string.find
local strfmt = string.format
local strmatch = string.match

local tconcat = table.concat

-- C版实现
local encode = require("crypt").urlencode
local decode = require("crypt").urldecode

--[[
经过测试: 100万此编码/解码两者性能相差30倍, 正好是lua与C的性能差距.
]]

local url = {}

-- urlencode编码
function url.encode(s)
  -- return spliter(spliter(s, "([^%w%.%- ])", function(c) return fmt("%%%02X", byte(c)) end), " ", "+")
  return encode(s)
end

-- urldecode解码
function url.decode(s)
  -- return spliter(s, '%%(%x%x)', function(h) return char(tonumber(h, 16)) end)
  return decode(s)
end

local meta = {}

function meta.__tostring(t)
  return strfmt(
    "Url(sheme='%s', netloc='%s', path='%s', query='%s', fragment='%s')",
    t.sheme or '', t.netloc or '', t.path or '', t.query or '', t.fragment or ''
  )
end

local function parse_other(other, t, dec)
  -- find '#' or '?'
  local pos = strfind(other, "#")
  if pos then
    -- Begin with '#'
    t.fragment = strsub(other, pos + 1)
    if pos > 1 then
      t.query = strsub(other, 2, pos - 1)
    end
  else
    -- got query string.
    pos = strfind(other, "?")
    if pos then
      t.query = strsub(other, pos + 1)
    end
  end
  if dec and t.query and t.query ~= '' then
    t.query = decode(t.query)
  end
end

local function parse_noloc(str, dec)
  local t, other = {}, nil
  t.path, other = strmatch(str, "([^%?#]*)([%?#]?.*)")
  parse_other(other, t, dec)
  return setmetatable(t, meta)
end

local function parse_nosheme(str, dec)
  local t, other = {}, nil
  -- got url split string.
  t.path, other = strmatch(str, "([^%?#]*)([%?#]?.*)")
  if strbyte(t.path) == 47 then
    return parse_noloc(str)
  end
  if strfind(t.path, '/') then
    t.netloc, t.path, other = strmatch(str, "([^/]*)([^%?#]*)([%?#]?.*)")
  end
  parse_other(other, t, dec)
  return setmetatable(t, meta)
end

---comment split url to Url Table(Class).
---@param str   string  @Url buffer.
---@param dec   boolean @Url decode.
---@return table
function url.split(str, dec)
  assert(type(str) == 'string', 'Invalid Url type.')
  local t, other = {}, nil
  -- got url split string.
  t.sheme, t.netloc, t.path, other = strmatch(str, '([^:]*)[:]?//([^/]*)([/]?[^%?#]*)([%?#]?.*)')
  if not t.sheme then
    return parse_nosheme(str, dec)
  end
  parse_other(other, t, dec)
  return setmetatable(t, meta)
end

---comment Use `Url` Table(Class) to Build url `String`.
---@param tab table @Split Class.
---@return string
function url.join(tab)
  assert(type(tab) == 'table', 'Invalid Url Class.')
  local urls = {}
  if tab.sheme then
    urls[1] = (tab.sheme ~= '' and (tab.sheme .. ':') or '' ) .. '//'
  end
  if tab.netloc then
    urls[#urls+1] = tab.netloc
  end
  if tab.path then
    urls[#urls+1] = tab.path
  end
  if tab.query then
    urls[#urls+1] = '?' .. tab.query
  end
  if tab.fragment then
    urls[#urls+1] = '#' .. tab.fragment
  end
  return tconcat(urls)
end

return url
