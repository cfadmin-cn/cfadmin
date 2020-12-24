local config = require 'admin.config'
local template = require "template"
local utils = require "admin.utils"
local user = require "admin.db.user"
local user_token = require "admin.db.token"
local menu = require "admin.db.menu"
local role = require "admin.db.role"
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
local role_already_selected = utils.role_already_selected

local template_path = 'lualib/admin/html/system/role/'

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

local system = {}

-- 角色管理
function system.role_render (content)
  local db = config.db
  local ok, user = verify_permission(content, db)
  if not ok then
    return utils.redirect(user)
  end
  if not config.cache then
    template.cache = {}
  end
  return template.compile(template_path..'role.html'){
    cdn = config.cdn,
    token = user.token,
    api_url = config.system_role_api,
    role_add_url = config.system_role_add_render,
    role_edit_url = config.system_role_edit_render,
    locale = get_locale(Cookie.getCookie('CFLANG'))
  }
end

-- 添加角色
function system.role_add_render (content)
  local db = config.db
  local ok, user = verify_permission(content, db)
  if not ok then
    return utils.redirect(user)
  end
  if not config.cache then
    template.cache = {}
  end
  return template.compile(template_path..'role-add.html'){
    cdn = config.cdn,
    token = user.token,
    api_url = config.system_role_api,
    locale = get_locale(Cookie.getCookie('CFLANG'))
  }
end

-- 编辑角色
function system.role_edit_render (content)
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
  local exists = role.role_id_exists(db, id)
  if not exists then
    return utils.error_404(config.login_render)
  end
  return template.compile(template_path..'role-edit.html'){
    cdn = config.cdn,
    id = exists.id,
    name = exists.name,
    token = user.token,
    api_url = config.system_role_api,
    locale = get_locale(Cookie.getCookie('CFLANG'))
  }
end

-- 用户管理API接口
function system.role_response (content)
  local db = config.db
  local args = content.args
  if type(args) ~= 'table' then
    if not content.json then -- 可以用这个字段判断是否json请求
      return json_encode({code = 400, msg = '1. 错误的参数'})
    end
    args = json_decode(content.body)
  end
  local token = args.token
  if not token then
    return json_encode({code = 400, msg = '2. 错误的参数'})
  end
  -- 验证Token
  local exists = user_token.token_exists(db, token)
  if not exists then
    return json_encode({code = 400, msg = '3. token不存在或权限不足'})
  end
  local user_info = user.user_info(db, exists.uid)
  if not user_info or user_info.is_admin == 0 then
    return json_encode({code = 400, msg = '4. 用户权限不足'})
  end
  if args.action == 'list' then
    return json_encode({code = 0, count = role.role_count(db), data = role.role_list(db, args)})
  end
  if args.action == 'add' then
    if not args.name or not args.permissions then
      return json_encode({code = 400, msg = '错误的role创建参数'})
    end
    args.name = url_decode(args.name)
    if role.role_name_exists(db, args.name) then
      return json_encode({ code = 401, msg = "角色名已存在"})
    end
    local name = role.role_add(db, args)
    return json_encode({code = 0, msg = '添加成功'})
  end
  if args.action == 'get_tree_list' then
    return json_encode({code = 0, data = menu.menu_tree(db, {page=1, limit=1000})})
  end
  if args.action == 'get_veri_tree' then
    local id = toint(args.id)
    if not id then
      return json_encode({code = 400, msg = "错误的参数"})
    end
    local menus = menu.menu_tree(db, {page=1, limit=1000})
    if #menus <= 0 then
      return json_encode({code = 0, data = json.empty_array})
    end
    local permissions = role.role_permissions(db, id)
    for _, menu in ipairs(menus) do
      if role_already_selected(permissions, menu.id) then
        menu.checkArr = {isChecked = 1}
      end
    end
    return json_encode({code = 0, data = menus})
  end
  if args.action == 'edit' then
    args.id = toint(args.id)
    if not args.id or not args.name or type(args.permissions) ~= 'table' then
      return json_encode({code = 400, msg = '错误的role修改参数'})
    end
    args.name = url_decode(args.name)
    role.role_update(db, args)
    return json_encode({code = 0, msg = '更新成功'})
  end
  if args.action == 'delete' then
    local id = toint(args.id)
    if not id then
      return json_encode({code = 400, msg = "1. 错误的参数"})
    end
    local exists = role.role_id_exists(db, id)
    if not exists then
      return json_encode({code = 400, msg = "2. 该角色不存在"})
    end
    if user_info.role == id then
      return json_encode({code = 400, msg = "3. 不可删除此角色"})
    end
    local ok = role.role_delete(db, id)
    if not ok then
      return json_encode({code = 400, msg = "4. 删除此角色失败"})
    end
    return json_encode({code = 0, msg = "角色删除成功"})
  end
  return json_encode({code = 500, msg = '恭喜您完美的错过了所有正确参数'})
end


return system
