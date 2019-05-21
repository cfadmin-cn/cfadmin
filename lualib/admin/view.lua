local template = require "template"
local utils = require "admin.utils"
local Cookie = require "admin.cookie"
local config = require "admin.config"
local user = require "admin.db.user"
local httpctx = require "admin.httpctx"
local user_token = require "admin.db.token"
local permission = require "admin.db.permission"


local type = type
local assert = assert

local get_path = utils.get_path

-- 用户自定义view页面需要验权
local function verify_permission (content, db)
  local token = Cookie.getCookie("CFTOKEN")
  if not token then
    return false, config.login_render
  end
  local info = user_token.token_to_userinfo(db, token)
  if info and (info.is_admin == 1 or permission.user_have_menu_permission(db, info.id, get_path(content))) then
    return true
  end
  return false, config.login_render
end

local view = {}

-- 页面路由
function view.use (path, cls)
  assert(type(path) == 'string', 'view use path failed.')
  assert(type(cls) == 'function' or type(cls) == 'table', 'view use path failed.')
  local db, app = config.db, config.app
  return app:use(path, function (content)
    local ok, url = verify_permission(content, db)
    if not ok then
      return utils.redirect(url)
    end
    local ok, html
    if type(cls) == 'function' then
      ok, html = pcall(cls, {ctx = httpctx:new{content = content, db = db}})
    else
      ok, html = pcall(cls:new({ctx = httpctx:new{content = content, db = db}}), content['method']:lower())
    end
    return html
  end)
end

-- 接口路由
function view.api (path, cls)
  assert(type(path) == 'string', 'view api path failed.')
  assert(type(cls) == 'function' or type(cls) == 'table', 'view use path failed.')
  local db, app = config.db, config.app
  return app:api(path, function (content)
    local ok, res
    if type(cls) == 'function' then
      ok, res = pcall(cls, {ctx = httpctx:new{content = content, db = db}})
    else
      ok, res = pcall(cls:new({ctx = httpctx:new{content = content, db = db}}), content['method']:lower())
    end
    return res
  end)
end

return view
