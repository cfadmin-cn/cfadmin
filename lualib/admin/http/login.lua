local template = require "template"
local utils = require "admin.utils"
local config = require "admin.config"
local Cookie = require "admin.cookie"
local user = require "admin.db.user"
local user_token = require "admin.db.token"
local token = require "admin.token"
local crypt = require "crypt"

local json = require "json"
local json_decode = json.decode
local json_encode = json.encode

local get_locale = utils.get_locale

template_path = 'lualib/admin/html/login/base.html'

local login = {}

-- 登录页面逻辑
function login.render(content)
  if not config.cache then
    template.cache = {}
  end
  Cookie.init() -- 初始化所有Cookie
  return template.compile(template_path){
    cdn = config.cdn,
    login_api = config.login_api,
    locale = get_locale(Cookie.getCookie("CFLANG"))
  }
end

-- 登录接口逻辑
function login.response (content)
  local db = config.db
  local args = content['args']
  if type(args) ~= 'table' then
    return json_encode({code = 401, msg = "1. 非法的参数"})
  end
  -- 验证参数
  local username, password = args.username, args.password
  if not username or not password then
    return json_encode({code = 401, msg = "2. 错误的参数"})
  end
  -- 获取登录信息
  local user_info = user.user_exists(db, username)
  if not user_info or crypt.hexencode(crypt.sha1(password)) ~= user_info.password then
    return json_encode({code = 403, msg = "3. 用户不存在或者密码错误"})
  end
  local uid, name = user_info.id, user_info.name
  -- 生成token
  local TOKEN = token.generate(uid)
  -- 将Token写入到数据库内
  local ok, err = user_token.token_add(db, uid, name, TOKEN)
  if not ok then
    return json_encode({code = 500, msg = err})
  end
  return json_encode({
    code = 200,
    token = TOKEN,
    url = config.dashboard,
  })
end

return login
