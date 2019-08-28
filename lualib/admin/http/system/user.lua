local config = require 'admin.config'
local template = require "template"
local utils = require "admin.utils"
local user = require "admin.db.user"
local user_token = require "admin.db.token"
local role = require "admin.db.role"
local Cookie = require "admin.cookie"
local crypt = require "crypt"

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

local get_locale = utils.get_locale

local template_path = 'lualib/admin/html/system/user/'

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
    return false, config.login_render
  end
  info.token = exists.token
  info.roles = role.role_permissions(db, info.role)
  return true, info
end

local system = {}

-- 用户管理render
function system.user_render (content)
  local db = config.db
  local ok, user = verify_permission(content, db)
  if not ok then
    return utils.redirect(user)
  end
  if not config.cache then
    template.cache = {}
  end
  return template.compile(template_path..'user.html'){
    cdn = config.cdn,
    token = user.token,
    api_url = config.system_user_api,
    user_add_url = config.system_user_add_render,
    user_edit_url = config.system_user_edit_render,
    locale = get_locale(Cookie.getCookie('CFLANG'))
  }
end

-- 添加用户页面
function system.user_add_render (content)
  local db = config.db
  local ok, user = verify_permission(content, db)
  if not ok then
    return utils.redirect(user)
  end
  if not config.cache then
    template.cache = {}
  end
  return template.compile(template_path..'user-add.html'){
    cdn = config.cdn,
    token = user.token,
    api_url = config.system_user_api,
    roles = role.role_list(db, {limit = 100}),
    locale = get_locale(Cookie.getCookie('CFLANG'))
  }
end

-- 编辑用户
function system.user_edit_render (content)
  local db = config.db
  local ok, opt = verify_permission(content, db)
  if not ok then
    return utils.redirect(opt)
  end
  local args = content.args
  if not type(args) == 'table' and not args.id then
    return utils.error_404(config.login_render)
  end
  local user = user.user_info(db, args.id or 0)
  if not user then
    return utils.error_404(config.login_render)
  end
  if not config.cache then
    template.cache = {}
  end
  return template.compile(template_path..'user-edit.html'){
    cdn = config.cdn,
    token = opt.token,
    api_url = config.system_user_api,
    user = user,
    roles = role.role_list(db, {limit = 100}),
    locale = get_locale(Cookie.getCookie('CFLANG'))
  }
end

-- 用户管理API接口
function system.user_response (content)
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
  local action = args.action
  -- 查找用户(模糊)
  if action == 'findUser' then
    if not args.value or not args.condition then
      return json_encode({code = 400, data = null, msg = '1. 无效的参数'})
    end
    local users, count = user.find_user(db, args)
    if not users or not count then
      return json_encode({code = 400, data = null, msg = '2. 无效的参数'})
    end
    return json_encode({code = 0, data = users, count = count})
  end
  -- 添加用户
  if action == 'add' then
    if not args.name or not args.username or not args.password then
      return json_encode({code = 400, data = null, msg = '1. 用户信息不完善'})
    end
    args.phone = toint(args.phone)
    args.role = toint(args.role)
    if not args.role or not args.email or not args.phone then
      return json_encode({code = 400, data = null, msg = '2. 用户信息不完善'})
    end
    if #args.username < 6 or #args.username > 20 or #args.password < 6 or #args.password > 20 then
      return json_encode({code = 400, data = null, msg = '3. 用户名与密码需要在6~20字符之间'})
    end
    args.name = url.decode(args.name)
    args.email = url.decode(args.email)
    local exists = user.user_name_or_username_exists(db, args.name, args.username)
    if exists then
      return json_encode({code = 400, data = null, msg = '4. 用户已存在'})
    end
    args.password = crypt.sha1(args.password, true)
    local ok = user.user_add(db, args)
    if not ok then
      return json_encode({code = 401, msg = "5. 添加用户失败"})
    end
    return json_encode({code = 0, msg = "添加成功"})
  end
  -- 删除用户
  if action == 'delete' then
    local uid = toint(args.id)
    if not uid then
      return json_encode({code = 400, data = null, msg = '1. 未知的用户ID'})
    end
    if exists.uid == uid then
      return json_encode({code = 401, data = null, msg = "2. 不能删除当前用户"})
    end
    local exists = user.user_exists(db, nil, uid)
    if not exists then
      return json_encode({code = 403, data = null, msg = '3. 试图删除不存在的用户'})
    end
    user.user_delete(db, uid)
    user_token.token_delete(db, uid) -- 清除Token
    return json_encode({code = 0, msg = "删除用户成功"})
  end
  -- 获取用户列表
  if action == 'list' then
    local users = user.user_list(db, args)
    for _, user in ipairs(users) do
      user.create_at = os_date("%Y-%m-%d %H:%M:%S", user.create_at)
      user.update_at = os_date("%Y-%m-%d %H:%M:%S", user.update_at)
    end
    return json_encode({code = 0, msg = "SUCCESS", count = user.user_count(db), data = users})
  end
  if action == 'edit' then
    if not args.name then
      return json_encode({code = 400, data = null, msg = "1. 未知的用户名"})
    end
    args.name = url_decode(args.name)
    if not args.id or not args.role then
      return json_encode({code = 400, data = null, msg = "2. 未知的用户与权限"})
    end
    if not args.username or not args.password then
      return json_encode({code = 400, data = null, msg = "3. 未知的账户与密码"})
    end
    if not args.phone or not args.email then
      return json_encode({code = 400, data = null, msg = "4. 邮箱与手机号"})
    end
    args.email = url_decode(args.email)
    args.password = crypt.sha1(args.password, true)
    local ok = user.user_update(db, args)
    if not ok then
      return json_encode({code = 401, msg = "5. 更新用户信息失败"})
    end
    user_token.token_delete(db, args.id) -- 清除Token
    return json_encode({code = 0, msg = "SUCCESS"})
  end
  -- 如果没有action字段则返回500
  return json_encode({code = 500, data = null, msg = '恭喜您完美的给予了错误的参数'})
end


return system
