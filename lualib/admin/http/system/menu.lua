local config = require 'admin.config'
local template = require "template"
local utils = require "admin.utils"
local user = require "admin.db.user"
local user_token = require "admin.db.token"
local menu = require "admin.db.menu"
local role = require "admin.db.role"
local view = require "admin.db.view"
local Cookie = require "admin.cookie"

local json = require "json"
local json_encode = json.encode
local json_decode = json.decode

local url = require "url"
local url_encode = url.encode
local url_decode = url.decode

local type = type
local ipairs = ipairs
local os_date = os.date
local toint = math.tointeger

local get_path = utils.get_path
local get_locale = utils.get_locale
local access_deny = utils.access_deny
local user_have_permission = utils.user_have_permission

local template_path = 'lualib/admin/html/system/menu/'

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
  if not info or info.is_admin ~= 1 then
    return false, access_deny(get_path(content))
  end
  info.token = exists.token
  info.roles = role.role_permissions(db, info.role)
  return true, info
end

-- 构建根节点
local function root_tree (list, role)
	local root = {}
	for _, item in ipairs(list) do
    -- 判断是否超级管理员或用户所在权限组有当前页面权限
		if (role.is_admin or user_have_permission(role.roles, item.id)) and item.parent == 0 then
			root[#root+1] = {id = item.id, name = item.name, url = item.url ~= null and item.url or nil, icon = item.icon ~= null and item.icon or nil}
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
			tab[#tab+1] = {id = item.id, name = item.name, url = item.url ~= null and item.url or nil, icon = item.icon ~= null and item.icon or nil}
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
  				sub['list'] = sub_tree(sub, list, role)
  			end
  	end
  	root['list'] = subs
  end
  return roots
end


local system = {}

-- 菜单管理render
function system.menu_render (content)
  local db = config.db
  local ok, user = verify_permission(content, db)
  if not ok then
    return utils.redirect(user)
  end
  if not config.cache then
    template.cache = {}
  end
  return template.compile(template_path..'menu.html'){
    cdn = config.cdn,
    token = user.token,
    api_url = config.system_menu_api,
    menu_add_url = config.system_menu_add_render,
    menu_edit_url = config.system_menu_edit_render,
    menus = get_menus(db, {is_admin = user.is_admin, roles = user.roles}),
    locale = get_locale(Cookie.getCookie('CFLANG'))
  }
end

function system.menu_add_render (content)
  local db = config.db
  local ok, user = verify_permission(content, db)
  if not ok then
    return utils.redirect(user)
  end
  if not config.cache then
    template.cache = {}
  end
  local args = content.args
  if type(args) ~= 'table' then
    args = { id = nil }
  else
    args.id = toint(args.id) or nil
  end
  return template.compile(template_path..'menu-add.html'){
    cdn = config.cdn,
    id = args.id,
    token = user.token,
    api_url = config.system_menu_api,
    locale = get_locale(Cookie.getCookie('CFLANG'))
  }
end

function system.menu_edit_render (content)
  local db = config.db
  local ok, user = verify_permission(content, db)
  if not ok then
    return utils.redirect(user)
  end
  if not config.cache then
    template.cache = {}
  end
  local args = content.args
  if type(args) ~= 'table' then
    return utils.error_404(config.login_render)
  end
  local id = toint(args.id)
  if not id then
    return utils.error_404(config.login_render)
  end
  local menu = menu.menu_info(db, id)
  if not menu then
    return utils.error_404(config.login_render)
  end
  return template.compile(template_path..'menu-edit.html'){
    cdn = config.cdn,
    token = user.token,
    id = id,
    menu = menu,
    api_url = config.system_menu_api,
    locale = get_locale(Cookie.getCookie('CFLANG'))
  }
end

-- 菜单管理API接口
function system.menu_response (content)
  local db = config.db
  local args = content.args
  if type(args) ~= 'table' then
    return json_encode({code = 400, data = null, msg = '1. 错误的参数'})
  end
  local token = args.token
  if not token then
    return json_encode({code = 400, data = null, msg = '2. 错误的参数'})
  end
  -- 验证Token
  local exists = user_token.token_exists(db, token)
  if not exists then
    return json_encode({code = 400, data = null, msg = '3. token不存在或权限不足'})
  end
  local user_info = user.user_info(db, exists.uid)
  if not user_info or user_info.is_admin == 0 then
    return json_encode({code = 400, data = null, msg = '4. 用户权限不足'})
  end
  -- 添加菜单
  local action = args.action
  if action == 'add' then
    if not args.name then
      return json_encode({ code = 401, msg = '1. add参数不足'})
    end
    args.id = toint(args.id) or 0 -- id > 0 则为添加子菜单
    args.name = url_decode(args.name)
    args.url = url_decode(args.url) or "NULL"
    args.icon = url_decode(args.icon)
    if menu.menu_name_exists(db, args.name) then
      return json_encode({code = 401, msg = '菜单名已存在'})
    end
    menu.menu_add(db, args)
    return json_encode({code = 0, msg = 'Success'})
  end
  -- 删除菜单
  if action == 'delete' then
    local id = toint(args.id)
    if not id then
      return json_encode({ code = 500, msg = "1.1 错误的删除菜单参数"})
    end
    menu.menu_delete(db, id)
    return json_encode({code = 0, msg = "删除成功"})
  end
  if action == 'edit' then
    args.id = toint(args.id)
    if not args.id then
      return json_encode({ code = 500, msg = "1.1 错误的删除菜单参数"})
    end
    args.name = url_decode(args.name)
    args.url = url_decode(args.url) or "NULL"
    args.icon = url_decode(args.icon)
    menu.menu_update(db, args)
    return json_encode({code = 0, msg = "修改成功"})
  end
  -- 获取菜单列表
  if action == 'list' then
    local menus = menu.menu_list(db, args)
    for _, menu in ipairs(menus) do
      menu.create_at = os_date("%Y-%m-%d %H:%M:%S", menu.create_at)
      menu.update_at = os_date("%Y-%m-%d %H:%M:%S", menu.delete_at)
    end
    return json_encode({ code = 0, data = menus, count = menu.menu_count(db) })
  end
  -- 如果没有action字段则返回500
  return json_encode({code = 500, data = null, msg = '恭喜您完美的给予了错误的参数'})
end


return system
