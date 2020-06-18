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

local type = type
local byte = string.byte
local get_locale = utils.get_locale

local template_path = 'lualib/admin/html/login/base.html'

local function random_sign(randomkey, value)
  local sign = {}
  randomkey = randomkey:reverse()
  for i = 1, #value do
    sign[i] = (byte(value, i) ~ byte(randomkey, i <= #randomkey and i or (i % randomkey) + 1)) & 0xff
    sign[i] = string.format("%02x", sign[i])
  end
  return table.concat(sign)
end

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
    randomkey = crypt.randomkey_ex(16, true):reverse(),
    locale = get_locale(Cookie.getCookie("CFLANG"))
  }
end

-- 登录接口逻辑
function login.response (content)
  local db = config.db
  local args = content.args or (content.json and json_decode(content.body))
  -- 验证参数是否存在
  if type(args) ~= 'table' or type(args.username) ~= 'string' or type(args.password) ~= 'string' or type(args.randomkey) ~= 'string' then
    return json_encode({code = 401, msg = "1. 无效的请求参数"})
  end
  local username, password, randomkey, verify_code = args.username, args.password, args.randomkey, args.verify_code
  if username == '' or password == '' or randomkey == '' or type(verify_code) ~= 'string' then
    return json_encode({code = 401, msg = "2. 无效的请求参数"})
  end
  -- 验证随机数行为
  if random_sign(randomkey, username .. password) ~= verify_code then
    return json_encode({code = 401, msg = "3. 用户密码验证失败"})
  end
  -- 获取登录信息
  local user_info = user.user_exists(db, username)
  if not user_info or username ~= user_info.username or crypt.sha1(password, true) ~= user_info.password then
    return json_encode({code = 403, msg = "4. 用户不存在或者密码错误"})
  end
  local uid, name = user_info.id, user_info.name
  -- 生成token
  local TOKEN = token.generate(uid)
  -- 将Token写入到数据库内
  local ok, err = user_token.token_add(db, uid, name, TOKEN)
  if not ok then
    return json_encode({code = 500, msg = err})
  end
  return json_encode({code = 0, msg = "登录成功", token = TOKEN, url = config.dashboard })
end

return login
