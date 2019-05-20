local config = require "admin.config"

local Cookie = require "httpd.Cookie"
local getCookie = Cookie.getCookie
local setCookie = Cookie.setCookie
local delCookie = Cookie.delCookie

local os_time = os.time

local Cookie = {}

-- 每次Login页需要生成全新的Cookie值.
function Cookie.init ()
  local session = getCookie('CFTOKEN')
  if not session then
    return
  end
  local session = getCookie('CFLANG')
  if not session then
    setCookie("CFLANG", config.locale)
  end
  return delCookie("CFTOKEN")
end

-- 设置Cookie
function Cookie.setCookie (name, value)
  return setCookie(name, value, config.cookie_timeout + os_time())
end

function Cookie.getCookie (name)
  return getCookie(name)
end

return Cookie
