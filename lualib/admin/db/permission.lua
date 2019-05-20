local fmt = string.format

local permission = {}

-- 用户是否有此菜单的权限
function permission.user_have_menu_permission (db, uid, url)
  local ret, err = db:query(fmt([[
  SELECT
    count(`cfadmin_menus`.`id`) AS count
  FROM
    cfadmin_users, cfadmin_menus, cfadmin_permissions
  WHERE
    (`cfadmin_users`.id = '%s' AND `cfadmin_users`.active = '1')	AND
    (`cfadmin_menus`.active = '1' AND `cfadmin_menus`.url = '%s') AND `cfadmin_permissions`.active = '1' AND
    `cfadmin_users`.role = `cfadmin_permissions`.role_id AND `cfadmin_permissions`.menu_id = `cfadmin_menus`.id]],
  uid, url))
  if ret and ret[1] and ret[1]['count'] == 1 then
    return true
  end
  return false
end

return permission
