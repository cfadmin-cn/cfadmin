local config = require "admin.config"

local Cookie = require "httpd.Cookie"
local getCookie = Cookie.getCookie
local setCookie = Cookie.setCookie
local delCookie = Cookie.delCookie

local os_time = os.time

local Cookie = {}

-- 登录页面需要初始化Cookie.
function Cookie.init ()
  local session = getCookie('CFTOKEN')
  if session then
    return delCookie("CFTOKEN")
  end
  local session = getCookie('CFLANG')
  if not session then
    setCookie("CFLANG", config.locale)
  end
end

-- 设置Cookie
function Cookie.setCookie (name, value)
  return setCookie(name, value, config.cookie_timeout + os_time())
end

-- 获取Cookie
function Cookie.getCookie (name)
  return getCookie(name)
end

return Cookie
