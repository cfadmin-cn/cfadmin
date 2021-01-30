local fmt = string.format

local permission = {}

-- 用户是否有此菜单的权限
function permission.user_have_menu_permission (db, uid, url)
  -- 查询用户Role ID
  local uinfo = db:query(fmt([[SELECT id, role AS role_id FROM cfadmin_users WHERE `cfadmin_users`.id = %u AND `cfadmin_users`.active = 1 LIMIT 1]], uid))[1]
  if type(uinfo) ~= 'table' then
    return false
  end
  -- 查询菜单Menu ID
  local minfo = db:query(fmt([[SELECT * FROM cfadmin_menus WHERE `cfadmin_menus`.url = '%s' AND `cfadmin_menus`.active = 1 LIMIT 1]], url))[1]
  if type(minfo) ~= 'table' then
    return true
  end
  -- 检查权限
  local role, err = db:query(fmt([[SELECT * FROM cfadmin_permissions p WHERE p.`active` = 1 AND p.`role_id` = %u AND p.`menu_id` = %u LIMIT 1]], uinfo.role_id, minfo.id))
  if type(role) == 'table' then
    return role[1]
  end
  return role, err
end

return permission
