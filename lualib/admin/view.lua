local template = require "template"
local utils = require "admin.utils"
local config = require "admin.config"
local user = require "admin.db.user"
local user_token = require "admin.db.token"
local permission = require "admin.db.permission"


local get_path = utils.get_path

-- 用户自定义view页面需要验权
local function verify_permission (content, db)
  local token = Cookie.getCookie("CFTOKEN")
  if not token then
    return false, config.login_render
  end
  local exists = user_token.token_exists(db, token)
  if not exists then -- Token不存在需要重新登录
    return false, config.login_render
  end
  local info = user.user_info(db, exists.uid)
  if not info or info.is_admin ~= 1 or not permission.user_have_menu_permission(db, info.id, get_path(content))
    return false, config.login_render
  end
  return true
end

local view = {}

-- 渲染模板
function view.render (content, path)
  local db = config.db
  local ok, page = verify_permission(content, db)
  if not ok then
    return utils.redirect(page)
  end
  return template.compile(path)
end

return view
