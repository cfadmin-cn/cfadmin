local user = require "admin.http.system.user"
local menu = require "admin.http.system.menu"
local header = require "admin.http.system.header"
local role = require "admin.http.system.role"

return {

  -- 用户管理 Controller
  user_response = user.user_response,
  user_render = user.user_render,
  user_add_render = user.user_add_render,
  user_edit_render = user.user_edit_render,

  -- 角色管理 Controller
  role_response = role.role_response,
  role_render = role.role_render,
  role_add_render = role.role_add_render,
  role_edit_render = role.role_edit_render,

  -- 侧边栏 Controller
  menu_response = menu.menu_response,
  menu_render = menu.menu_render,
  menu_add_render = menu.menu_add_render,
  menu_edit_render = menu.menu_edit_render,

  -- 导航栏 Controller
  header_response = header.header_response,
  header_render = header.header_render,
  header_add_render = header.header_add_render,
  header_edit_render = header.header_edit_render,

}
