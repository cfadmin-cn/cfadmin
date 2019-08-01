local config = require 'admin.config'
local template = require "template"
local utils = require "admin.utils"
local user = require "admin.db.user"
local user_token = require "admin.db.token"
local role = require "admin.db.role"
local header = require "admin.db.header"
local Cookie = require "admin.cookie"

local json = require "json"
local json_encode = json.encode
local json_decode = json.decode

local url = require "url"
local url_encode = url.encode
local url_decode = url.decode

local type = type
local ipairs = ipairs
local tostring = tostring
local os_date = os.date
local toint = math.tointeger

local get_locale = utils.get_locale

local template_path = 'lualib/admin/html/system/header/'

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
function system.header_render (content)
  local db = config.db
  local ok, user = verify_permission(content, db)
  if not ok then
    return utils.redirect(user)
  end
  if not config.cache then
    template.cache = {}
  end
  return template.compile(template_path..'header.html'){
    cdn = config.cdn,
    token = user.token,
    api_url = config.system_header_api,
    header_add_url = config.system_header_add_render,
    header_edit_url = config.system_header_edit_render,
    locale = get_locale(Cookie.getCookie('CFLANG'))
  }
end

-- 添加导航
function system.header_add_render (content)
  local db = config.db
  local ok, user = verify_permission(content, db)
  if not ok then
    return utils.redirect(user)
  end
  if not config.cache then
    template.cache = {}
  end
  return template.compile(template_path..'header-add.html'){
    cdn = config.cdn,
    api_url = config.system_header_api,
    token = Cookie.getCookie("CFTOKEN"),
    locale = get_locale(Cookie.getCookie('CFLANG'))
  }
end

-- 编辑导航
function system.header_edit_render (content)
  local db = config.db
  local ok, user = verify_permission(content, db)
  if not ok then
    return utils.redirect(user)
  end
  local args = content.args
  if not args or not args.id then
    return utils.error_404()
  end
  local h = header.get_header(db,  args.id)
  if not h then
    return utils.error_404()
  end
  if not config.cache then
    template.cache = {}
  end
  return template.compile(template_path..'header-edit.html'){
    cdn = config.cdn,
    id = h.id,
    url = h.url,
    name = h.name,
    api_url = config.system_header_api,
    token = Cookie.getCookie("CFTOKEN"),
    locale = get_locale(Cookie.getCookie('CFLANG'))
  }
end

-- 用户管理API接口
function system.header_response (content)
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
  if args.action == 'delete' then
    local headerid = toint(args.headerid)
    if not headerid then
      return json_encode({ code = 400, data = null, msg = '1. 未知的header' })
    end
    local exists = header.header_exists(db, headerid)
    if not exists then
      return json_encode({ code = 400, data = null, msg = '2. 试图删除一个不存在的的header' })
    end
    header.header_delete(db, headerid)
    return json_encode({ code = 0, data = null, msg = '删除成功'})
  end
  if args.action == 'list' then
    local headers = header.header_list(db, args)
    for _, header in ipairs(headers) do
      header.create_at = os_date("%Y-%m-%d %H:%M:%S", header.create_at)
      header.update_at = os_date("%Y-%m-%d %H:%M:%S", header.update_at)
    end
    return json_encode({code = 0, data = headers, count = header.header_count(db)})
  end
  if args.action == 'add' then
    if not args.url or not args.name then
      return json_encode({ code = 400, data = null, msg = "1. 添加导航栏参数错误"})
    end
    args.url = url_decode(args.url)
    args.name = url_decode(args.name)
    local ok = header.header_add(db, args)
    if not ok then
      return json_encode({code = 401, msg = "2. 添加导航失败"})
    end
    return json_encode({code = 0, msg = "添加成功"})
  end
  if args.action == 'edit' then
    if not args.id then
      json_encode({ code = 400, data = null, msg = "1. 找不到此header"})
    end
    local url = tostring(args.url)
    local name = tostring(args.name)
    if not url or not name then
      json_encode({ code = 400, data = null, msg = "2. 非法的参数"})
    end
    args.url = url_decode(args.url)
    args.name = url_decode(args.name)
    local ok = header.header_update(db, args)
    if not ok then
      return json_encode({code = 401, msg = "3. 修改失败"})
    end
    return json_encode({ code = 0, msg = "修改成功"})
  end
  return json_encode({code = 500, data = null, msg = '恭喜您完美的错过了所有正确参数'})
end


return system
