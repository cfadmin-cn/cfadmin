local type = type
local assert = assert
local find = string.find

local urldecode = require "url".decode

local codes = {
  [301] = "301 Moved Permanently",   -- （永久移动）
  [302] = "302 Found",               -- （发现）
  [303] = "303 See Other",           -- （查看其他）
  [307] = "307 Temporary Redirect",  -- （临时重定向）
  [308] = "308 Permanent Redirect",  -- （永久重定向）
}

---comment 检查状态码是否在指定范围内
---@param code number         @HTTP状态码
---@return boolean | integer
local function check_code(code)
  return codes[code] and code or nil
end

---comment 检查重定向的url是否合法.
---@param url string          @合法的路由或http[s]地址
---@return boolean | string
local function check_url(url)
  if type(url) ~= "string" or url == "" then
    return false
  end
  url = urldecode(url)
  if find(url, "^/.*") then
    return url
  end
  if find(url, "^http[s]?://.*") then
    return url
  end
  return false
end

---comment 让注册的`USE`/`API`路由可以合法的重定向.
---@param code  integer   @HTTP状态码.
---@param url   string    @需要重定向的`URL`.
return function (code, url)
  return { __OPCODE__ = -65536, __CODE__ = assert(check_code(code), "Invalid http code.") , __MSG__ = assert(check_url(url), "Invalid url") }
end