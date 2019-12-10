local template = require "template"
local utils = require "admin.utils"
local Cookie = require "admin.cookie"
local config = require "admin.config"
local user = require "admin.db.user"
local httpctx = require "admin.httpctx"
local user_token = require "admin.db.token"
local permission = require "admin.db.permission"

local LOG = require "logging"

local type = type
local pcall = pcall
local assert = assert

local get_path = utils.get_path

-- 用户自定义view页面需要验权
local function verify_permission (content, db)
  local token = Cookie.getCookie("CFTOKEN")
  if not token then
    return false, config.login_render
  end
  -- 无效token则需要登录
  local info = user_token.token_to_userinfo(db, token)
  if not info then
    return false, config.login_render
  end
  -- 有效token需要验证访问权限
  if info.is_admin ~= 1 and permission.user_have_menu_permission(db, info.id, get_path(content)) then
    return false, config.login_render
  end
  return true
end

local view = {}

-- 页面路由
function view.use (path, f)
  assert(type(path) == 'string', 'view use path failed.')
  assert(type(f) == 'function', 'view use handle failed.')
  local db, app = config.db, config.app
  assert(db and app, "view.use need db session and http context.")
  return app:use(path, function (content)
    local ok, url = verify_permission(content, db)
    if not ok then
      return utils.redirect(url)
    end
    if not config.cache then
      template.cache = {}
    end
    local ok, html = pcall(f, httpctx:new{content = content}, db)
    if not ok then
      LOG:ERROR(html)
    end
    return html
  end)
end

-- 接口路由
function view.api (path, f)
  assert(type(path) == 'string', 'view api path failed.')
  assert(type(f) == 'function', 'view api handle failed.')
  local db, app = config.db, config.app
  assert(db and app, "view.api need db session and http context.")
  return app:api(path, function (content)
    local ok, res = pcall(f, httpctx:new{content = content}, db)
    if not ok then
      LOG:ERROR(res)
    end
    return res
  end)
end

-- 首页
function view.home(path, f)
  assert(type(path) == 'string', 'view use path failed.')
  assert(type(f) == 'function', 'view use handle failed.')
  config.home = path
  local db, app = config.db, config.app
  assert(db and app, "view.home need db session and http context.")
  return app:use(path, function (content)
    local token = Cookie.getCookie("CFTOKEN")
    if not token then
      return false, config.login_render
    end
    local info = user_token.token_to_userinfo(db, token)
    if not info then
      return utils.redirect(config.login_render)
    end
    local ok, res = pcall(f, httpctx:new{content = content}, db)
    if not ok then
      LOG:ERROR(res)
    end
    return res
  end)
end

-- 获取当前用户语言表
function view.get_locale ()
  return utils.get_locale(Cookie.getCookie("CFLANG"))
end

-- 获取静态文件前缀
function view.get_cdn ()
  return config.cdn
end

-- 模板渲染
function view.template( ... )
  if not config.cache then
    template.cache = {}
  end
  return template.compile(...)
end

return view
