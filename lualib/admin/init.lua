local template = require "template"
local config = require "admin.config"
local locales = require "admin.locales"
local admin_db = require "admin.db"
local login = require "admin.http.login"
local system = require "admin.http.system"
local profile = require "admin.http.profile"
local dashboard = require "admin.http.dashboard"

local admin = {}

-- 开启全局模板缓存
function admin.cached()
  config.cache = true
end

-- 设置静态文件的域名与前缀
function admin.static(domain)
  config.cdn = domain
end

-- Cookie时间
function admin.cookie_timeout (timeout)
  config.cookie_timeout = tonumber(timeout) or 86400
end

-- 添加某语言的字段
function admin.add_locale_item(lang, locale_item)
  local locale = locales[lang]
  if locale and type(locale) == 'table' then
    for _, item in ipairs(locale_item) do
      locale[item[1]] = item[2]
    end
  end
end

-- 修改全局默认语言
function admin.set_locale (locale)
  if type(locale) == 'string' then
    config.locale = locale
  end
end

-- 设置仪表盘显示页
function admin.init_home (url)
  config.home = url or config.home
end

function admin.init_page (app, db)
  config.app = assert(app, '初始化必须传入有效的http对象')
  config.db = assert(db, '初始化必须传入有效的db对象')

  config.home = config.home or '/welcome.html'

  -- 注册登录页相关路由
  config.login_api = '/api/login'
  config.login_render = '/admin'
  app:api(config.login_api, login.response)
  app:use(config.login_render, login.render)

  -- 后台首页路由
  config.dashboard = '/admin/dashboard'
  app:use(config.dashboard, dashboard.render)

  -- 用户管理路由
  config.system_user_api = '/api/system/user'
  config.system_user_render = '/admin/system/user'
  config.system_user_add_render = '/admin/system/user/add'
  config.system_user_edit_render = '/admin/system/user/edit'
  app:api(config.system_user_api, system.user_response)
  app:use(config.system_user_render, system.user_render)
  app:use(config.system_user_add_render, system.user_add_render)
  app:use(config.system_user_edit_render, system.user_edit_render)

  -- 菜单管理
  config.system_menu_api = '/api/system/menu'
  config.system_menu_render = '/admin/system/menu'
  config.system_menu_add_render = '/admin/system/menu/add'
  config.system_menu_edit_render = '/admin/system/menu/edit'
  app:api(config.system_menu_api, system.menu_response)
  app:use(config.system_menu_render, system.menu_render)
  app:use(config.system_menu_add_render, system.menu_add_render)
  app:use(config.system_menu_edit_render, system.menu_edit_render)

  -- 导航管理
  config.system_header_api = '/api/system/header'
  config.system_header_render = '/admin/system/header'
  config.system_header_add_render = '/admin/system/header/add'
  config.system_header_edit_render = '/admin/system/header/edit'
  app:api(config.system_header_api, system.header_response)
  app:use(config.system_header_render, system.header_render)
  app:use(config.system_header_add_render, system.header_add_render)
  app:use(config.system_header_edit_render, system.header_edit_render)

  -- 权限管理
  config.system_role_api = '/api/system/role'
  config.system_role_render = '/admin/system/role'
  config.system_role_add_render = '/admin/system/role/add'
  config.system_role_edit_render = '/admin/system/role/edit'
  app:api(config.system_role_api, system.role_response)
  app:use(config.system_role_render, system.role_render)
  app:use(config.system_role_add_render, system.role_add_render)
  app:use(config.system_role_edit_render, system.role_edit_render)


  -- profile路由
  config.profile_api = '/api/profile'
  config.profile_render = '/admin/profile'
  app:api(config.profile_api, profile.response)
  app:use(config.profile_render, profile.render)

end

-- 初始化数据
function admin.init_db (...)
  return admin_db(...)
end

return admin
