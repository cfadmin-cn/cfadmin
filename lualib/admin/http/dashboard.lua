local template = require "template"
local utils = require "admin.utils"
local Cookie = require "admin.cookie"
local config = require "admin.config"
local locales = require "admin.locales"
local role = require "admin.db.role"
local user = require "admin.db.user"
local user_token = require "admin.db.token"
local view = require "admin.db.view"

local type = type
local ipairs = ipairs

local get_locale = utils.get_locale
local user_have_permission = utils.user_have_permission

local template_path = 'lualib/admin/html/dashboard/base.html'

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
    username = user.name,
    logout = config.login_render,
    user = config.system_user_render,
    menu = config.system_menu_render,
    header = config.system_header_render,
    role = config.system_role_render,
    profile = config.profile_render,
    is_admin = user.is_admin,
    locale = get_locale(Cookie.getCookie("CFLANG"))
  }
end

return dashboard
