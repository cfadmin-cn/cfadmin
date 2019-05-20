local template = require "template"
local utils = require "admin.utils"
local Cookie = require "admin.cookie"
local config = require "admin.config"
local locales = require "admin.locales"
local role = require "admin.db.role"
local user = require "admin.db.user"
local user_token = require "admin.db.token"
local view = require "admin.db.view"
local crypt = require "crypt"

local type = type
local ipairs = ipairs
local toint = math.tointeger

local json = require "json"
local json_decode = json.decode
local json_encode = json.encode

local url = require "url"
local url_encode = url.encode
local url_decode = url.decode

local get_locale = utils.get_locale

local template_path = 'lualib/admin/html/profile/base.html'

-- 管理页面验权
local function verify_permission (content, db)
  local args = content.args
  -- 切换语言
  if type(args) == 'table' and args.lang then
    local lang = args.lang
    local locale = config.locales[lang]
    if locale then
      Cookie.setCookie('CFLANG', lang)
    else
      Cookie.setCookie('CFLANG', config.locale)
    end
    return false, config.dashboard
  end
  -- 登录注入Cookie
  if type(args) == 'table' and args.token then
    local token = args.token
    if not token then  -- 对一些错误传参直接重定向到登录页
      return false, config.login_render
    end
    -- 开启验证Token
    local exists = user_token.token_exists(db, token)
    if not exists then -- Token不存在需要重新登录
      return false, config.login_render
    end
    -- 如果是第一次带上Token访问后, admin会给予一个重写URL后的url.
    -- 同时admin会在这里将Token写入到Cookie中去, 用户无需感知.
    Cookie.setCookie("CFTOKEN", token)
    return false, utils.get_path(content)
  end
  local token = Cookie.getCookie('CFTOKEN')
  if not token then -- 未授权的访问
    return false, config.login_render
  end
  local exists = user_token.token_exists(db, token)
  if not exists then -- Token不存在需要重新登录
    return false, config.login_render
  end
  local info = user.user_info(db, exists.uid)
  if not info then
    return false, config.login_render
  end
  info.token = exists.token
  info.roles = role.role_permissions(db, info.role)
  return true, info
end


local profile = {}

-- 渲染登录页模板
function profile.render(content)
  local db = config.db
  local ok, user = verify_permission(content, db)
  if not ok then
    return utils.redirect(user)
  end
  if not config.cache then
    template.cache = {}
  end
  return template.compile(template_path){
    cdn = config.cdn,
    user = user,
    api_url = config.profile_api,
    locale = get_locale(Cookie.getCookie("CFLANG"))
  }
end

function profile.response (content)
  local db = config.db
  if type(content.args) ~= 'table' then
    return json_encode({code = 500, msg = "1. 错误的参数" })
  end
  local args = content.args
  local token = args.token
  if not token then
    return json_encode({code = 400, data = null, msg = '2. 错误的参数'})
  end
  -- 验证Token
  local exists = user_token.token_exists(db, token)
  if not exists then
    return json_encode({code = 400, data = null, msg = '3. token不存在'})
  end
  args.id = toint(exists.uid)
  local user_info = user.user_info(db, args.id)
  if not user_info then
    return json_encode({code = 400, data = null, msg = '4. 用户不存在'})
  end
  if args.action == 'update_password' then
    if not args.password or not args.cupassword then
      return json_encode({code = 401, msg = "1. 错误的password参数" })
    end
    if #args.password < 6 or #args.password > 20 then
      return json_encode({code = 403, msg = "2. password长度必须在6~20之间" })
    end
    if args.password == args.cupassword then
      return json_encode({code = 403, msg = "3. 新老密码不能一样" })
    end
    args.password = crypt.hexencode(crypt.sha1(url_decode(args.password)))
    args.cupassword = crypt.hexencode(crypt.sha1(url_decode(args.cupassword)))
    if user_info.password == args.password then
      return json_encode({code = 403, msg = "4. 当前密码不正确或新老密码一致" })
    end
    user.user_update_password(db, args)
    user_token.token_delete(db, args.id)
    return json_encode({code = 0, msg = 'Success: 密码修改成功'})
  end
  if args.action == 'update_userinfo' then
    if not args.name or not args.email or not args.phone then
      return json_encode({code = 500, msg = "2. 错误的info参数" })
    end
    args.name = url_decode(args.name)
    args.email = url_decode(args.email)
    user.user_update_info(db, args)
    user_token.token_delete(db, args.id)
    return json_encode({code = 0, msg = 'Success: 用户信息更新成功'})
  end
  return json_encode({code = 500, msg = "恭喜您完美的错过了所有正确参数" })
end

return profile
