local template = require "template"
local utils = require "admin.utils"
local Cookie = require "admin.cookie"
local config = require "admin.config"
local locales = require "admin.locales"
local role = require "admin.db.role"
local view = require "admin.db.view"
local user = require "admin.db.user"
local user_token = require "admin.db.token"

local type = type
local ipairs = ipairs

local get_locale = utils.get_locale
local user_have_permission = utils.user_have_permission

local template_path = 'lualib/admin/html/dashboard/base.html'

local function verify_permission (content, db)
  local args = content.args
  if type(args) == 'table' then
    local lang, token, logout = args.lang, args.token, args.logout
    if lang then  -- 切换语言
      Cookie.setCookie('CFLANG', config.locales[lang] and lang or config.locale)
      return false, config.dashboard
    end
    if logout then -- 注销登录
      local tk = Cookie.getCookie('CFTOKEN')
      if tk then   -- 注销的时候有token必须清除
        user_token.token_delete(db, nil, tk)
      end
      return false, config.login_render
    end
    if token then -- 登录授权
      local exists = user_token.token_exists(db, token)
      if not exists then -- Token不存在需要重新登录
        return false, config.login_render
      end
      Cookie.setCookie("CFTOKEN", token)
      return false, config.dashboard
    end
  end
  local token = Cookie.getCookie('CFTOKEN')
  if not token then -- 未授权的访问
    return false, config.login_render
  end
  local info = user_token.token_to_userinfo(db, token)
  if not info then
    return false, config.login_render
  end
  info.is_admin = info.is_admin == 1
  info.roles = role.role_permissions(db, info.role)
  return true, info
end

-- 构建根节点
local function root_tree (list, role)
	local root = {}
	for _, item in ipairs(list) do
    -- 判断是否超级管理员或用户所在权限组有当前页面权限
		if (role.is_admin or user_have_permission(role.roles, item.id)) and item.parent == 0 then
			root[#root+1] = {id = item.id, item.name, item.url ~= null and item.url or nil, item.icon ~= null and item.icon or nil}
		end
	end
	return root -- 返回树的根结构
end

-- 构建叶(子)节点
local function sub_tree (root, list, role)
	local tab = {}
	for index, item in ipairs(list) do
    -- 判断是否超级管理员或用户所在权限组有当前页面权限
		if (role.is_admin or user_have_permission(role.roles, item.id)) and root.id == item.parent then
			tab[#tab+1] = {id = item.id, item.name, item.url ~= null and item.url or nil, item.icon ~= null and item.icon or nil}
		end
	end
	return #tab > 0 and tab or nil -- 返回树的叶(子)结构
end

-- menu 生成
local function get_menus (db, role)
  local list = view.get_menus(db)
  if not list then
    return {}
  end
  local roots = root_tree(list, role)
  if #roots == 0 then
    return roots
  end
  for _, root in ipairs(roots) do
  	local subs = sub_tree(root, list, role)
  	if subs then
  			for _, sub in ipairs(subs) do
  				sub[2] = sub_tree(sub, list, role) or sub[2]
  			end
  	end
  	root[2] = subs or root[2]
  end
  return roots
end

-- header 生成
local function get_headers (db)
  local tab = {}
  for _, header in ipairs(view.get_headers(db)) do
    tab[#tab+1] = {header.name, header.url}
  end
  return tab
end

local dashboard = {}

-- 渲染登录页模板
function dashboard.render(content)
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
    home = config.home,
    logo = config.dashboard,
    menus = get_menus(db, {is_admin = user.is_admin, roles = user.roles}),
    headers = get_headers(db),
    token = user.token,
    username = user.name,
    is_admin = user.is_admin,
    logout = config.dashboard .."?logout=true",
    user = config.system_user_render,
    menu = config.system_menu_render,
    header = config.system_header_render,
    role = config.system_role_render,
    display_lang = config.display_lang,
    profile = config.profile_render,
    locale = get_locale(Cookie.getCookie("CFLANG"))
  }
end

return dashboard
