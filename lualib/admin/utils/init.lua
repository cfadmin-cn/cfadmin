local template = require "template"
local config = require "admin.config"

local type = type
local assert = assert
local ipairs = ipairs

local split = string.sub
local find = string.find
local concat = table.concat


local utils = {}

-- 页面重定向
function utils.redirect(path, args)
  assert(path ~= '' or type(path) ~= 'string' , '试图传递一个非法的path')
  assert(not args or type(args) == 'table' , '试图传递一个非法的args')
  local tab, arguments = { }, nil
  if args then
    for _, arg in ipairs(args) do
      tab[#tab+1] = concat(arg, '=')
    end
  end
  local arguments = concat(tab, '&')
  return template.compile('lualib/admin/html/redirect.html'){
    path = (path or config.github) .. arguments,
  }
end

-- 404错误页
function utils.error_404(location)
  return template.compile('lualib/admin/html/404.html'){
    cdn = config.cdn,
    locale = config.locales[config.locale],
    location = location or config.github,
  }
end

-- 获取页面url
function utils.get_path (content)
  return split(content['path'], 1, (find(content['path'], '?') or 0) - 1)
end

-- 获取语言
function utils.get_locale (lang)
  local locale = config.locales[lang]
  if locale then
    return locale
  end
  return config.locales[config.locale]
end

-- 用户是否包含此权限
function utils.user_have_permission (permissions, id)
  for _, permission in ipairs(permissions) do
    if permission.menu_id == id then
      return true
    end
  end
  return false
end

-- 角色权限组是否已经有此权限
function utils.role_already_selected (permissions, id)
  for _, permission in ipairs(permissions) do
    if permission.menu_id == id then
      return true
    end
  end
  return false
end

return utils
