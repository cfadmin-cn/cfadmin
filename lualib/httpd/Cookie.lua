local Co = require "internal.Co"
local co_self = Co.self

local crypt = require "crypt"
local xor_str = crypt.xor_str
local hexencode = crypt.hexencode
local hexdecode = crypt.hexdecode

local type = type
local pcall = pcall
local assert = assert
local ipairs = ipairs
local os_date = os.date
local os_time = os.time
local concat = table.concat
local splite = string.gmatch

-- 默认密匙
local secure = 'http://github.com/candymi/core_framework'

-- 加密Cookie Value
local function encode_value (value)
  return xor_str(value, secure, true):upper()
end

-- 解密Cookie Value
local function decode_value (value)
  local ok, msg = pcall(hexdecode, value:lower())
  if not ok then
    return msg
  end
  return xor_str(msg, secure)
end

-- 当前协程注册的cookie
local Cookie = {
  client = {},
  server = {},
}

function Cookie.setSecure (sec)
  if type(sec) == 'string' and sec ~= '' then
      secure = sec
  end
end

-- 设置Cookie
function Cookie.setCookie (name, value, expires, notall, https)
  assert(type(name) == 'string' and key ~= '', '错误的Cookie Key, 请检查参数有效性')
  assert(type(value) == 'string' or type(value) == 'number', '错误的Cookie Value, 请检查参数有效性')
  assert(not expires or expires > os_time(), '错误的Cookie Expires, 请检查参数有效性')
  local co = co_self()
  local cs = Cookie.server[co]
  if not cs then
    cs = {}
    Cookie.server[co] = cs
  end
  cs[#cs+1] = {
    name = name,
    value = value,
    expires = expires,
    path = '/',
    httponly = notall and 'HttpOnly',
    secure = https and 'Secure'
  }
end

-- 获取指定Cookie字段
function Cookie.getCookie (name)
  local co = co_self()
  local cs = Cookie.client[co]
  if not cs then
    return
  end
  local value = cs[name]
  if not value then
    return
  end
  return decode_value(value)
end

function Cookie.delCookie (name)
  return Cookie.setCookie(name, ' ', os_time() + 1)
end

-- 对cookie进行反序列化
function Cookie.deserialization (cs)
  local co = co_self()
  local Cookies = {}
  if type(cs) ~= 'string' or cs == '' then
    Cookie.client[co] = Cookies
    return
  end
  for name, value in splite(cs, '([^ ;]+)=([^ ;]+)') do
    Cookies[name] = value
  end
  Cookie.client[co] = Cookies
  -- local log = require 'logging'
  -- local Log = log:new()
  -- Log:DEBUG('反序列化后的cookie', Cookies)
end

-- 对cookie进行序列化
function Cookie.serialization ()
  local co = co_self()
  local cs = Cookie.server[co]
  if not cs then
    return {}
  end
  local tab = {}
  for _, cookie in ipairs(cs) do
    local t = {}
    t[#t+1] = concat({cookie.name, '=', encode_value(cookie.value)})
    t[#t+1] = cookie.expires and concat({'expires', '=', os_date("%a, %d %b %Y %X GMT", cookie.expires)})
    t[#t+1] = concat({'path', '=', cookie.path})
    t[#t+1] = cookie.httponly
    if cookie.httponly then
      t[#t+1] = cookie.secure
    end
    tab[#tab+1] = 'Set-Cookie: '..concat(t, "; ")
  end
  return tab
end

-- 清理Cookie
function Cookie.clean ()
  local co = co_self()
  Cookie.server[co] = nil
  Cookie.client[co] = nil
  -- local log = require 'logging'
  -- local Log = log:new()
  -- Log:DEBUG('反序列化后的cookie', Cookie)
end

return Cookie
