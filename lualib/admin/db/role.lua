local tonumber = tonumber
local tostring = tostring
local concat = table.concat
local os_time = os.time
local os_date = os.date
local fmt = string.format

local role = {}

-- 角色列表
function role.role_list (db, opt)
  local limit = tonumber(opt.limit) or 10
  local page = tonumber(opt.page) or 1
  local roles, err = db:query(fmt([[SELECT id, name, create_at, update_at FROM cfadmin_roles WHERE active = '1' ORDER BY id LIMIT %s, %s]], limit * (page - 1) , limit))
  if not roles then
    return
  end
  for _, role in ipairs(roles) do
    role.create_at = os_date("%Y-%m-%d %H:%M:%S", role.create_at)
    role.update_at = os_date("%Y-%m-%d %H:%M:%S", role.update_at)
  end
  return roles
end

-- 计算角色数量
function role.role_count (db)
  return db:query([[SELECT count(id) AS count FROM cfadmin_roles WHERE active = '1']])[1]['count']
end

-- 角色对应权限
function role.role_permissions (db, id)
  return db:query(fmt([[SELECT role_id, menu_id FROM cfadmin_permissions WHERE role_id = '%s' AND active = '1']], id))
end

-- 角色名已存在
function role.role_name_exists (db, name)
  local ret, err = db:query(fmt([[SELECT id, name FROM cfadmin_roles WHERE name = '%s' AND active = '1' LIMIT 1]], name))
  if ret and #ret > 0 then
    return ret[1]
  end
  return false
end

-- 角色id已存在
function role.role_id_exists (db, id)
  local ret, err = db:query(fmt([[SELECT id, name FROM cfadmin_roles WHERE id = '%s' AND active = '1' LIMIT 1]], id))
  if ret and #ret > 0 then
    return ret[1]
  end
  return false
end

-- 添加角色
function role.role_add (db, opt)
  local now = os_time()
  db:query(fmt([[INSERT INTO cfadmin_roles(`name`, `is_admin`, `create_at`, `update_at`, `active`) VALUES('%s', '0', '%s', '%s', '1')]], opt.name, now, now))
  if opt.permissions then
    local id = db:query(fmt([[SELECT id FROM cfadmin_roles WHERE name = '%s' AND active = '1' LIMIT 1]], opt.name))[1]['id']
    local tab = {}
    local SQL = [[INSERT INTO cfadmin_permissions(`role_id`, `menu_id`, `create_at`, `update_at`, `active`) VALUES]]
    for _, permission in ipairs(opt.permissions) do
      tab[#tab+1] = '('..concat({id, permission.menu_id, now, now, 1}, ', ')..')'
    end
    db:query(SQL..concat(tab, ', '))
  end
end

-- 删除角色关联数据
function role.role_delete (db, id)
  local now = os_time()
  -- 删除角色
  db:query(fmt([[UPDATE cfadmin_roles SET active = '0', update_at = '%s' WHERE id = '%s' AND active = '1']], now, id))
  -- 删除角色对应的权限
  db:query(fmt([[UPDATE cfadmin_permissions SET active = '0', update_at = '%s' WHERE role_id = '%s' AND active = '1']], now, id))
end

-- 更新role相关数据
function role.role_update(db, opt)
  local now = os_time()
  db:query(fmt([[UPDATE cfadmin_roles SET name = '%s', update_at = '%s' where id = '%s' AND active = '1']], opt.name, now, opt.id))
  db:query(fmt([[UPDATE cfadmin_permissions SET active = '0', update_at = '%s' WHERE role_id = '%s']], now, opt.id))
  local tab = {}
  local SQL = [[INSERT INTO cfadmin_permissions(`role_id`, `menu_id`, `create_at`, `update_at`, `active`) VALUES]]
  for _, permission in ipairs(opt.permissions) do
    tab[#tab+1] = '('..concat({opt.id, permission.menu_id, now, now, 1}, ', ')..')'
  end
  db:query(SQL..concat(tab, ', '))
end

return role
