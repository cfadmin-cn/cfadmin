local toint = math.tointeger
local fmt = string.format
local concat = table.concat
local os_time = os.time

local menu = {}

-- 菜单列表
function menu.menu_list (db, opt)
  local limit = toint(opt.limit) or 100
  local page = toint(opt.page) or 1
  return db:query(fmt([[SELECT id, parent, name, url, icon, create_at, update_at FROM cfadmin_menus WHERE active = '1' LIMIT %s, %s]], limit * (page - 1), limit))
end

-- 菜单名已存在
function menu.menu_name_exists (db, name)
  local ret = db:query(fmt([[SELECT name FROM cfadmin_menus WHERE name = '%s' AND active = '1']], name))
  if ret and #ret > 0 then
    return true
  end
  return false
end

-- 菜单信息
function menu.menu_info (db, id)
  return db:query(fmt([[SELECT id, name, url, icon FROM cfadmin_menus WHERE id = '%s' AND active = '1']], id))[1]
end

-- 添加菜单菜单
function menu.menu_add (db, opt)
  local now = os_time()
  if opt.id > 0 then -- 是否是增加二级菜单
    db:query(fmt([[UPDATE cfadmin_menus SET URL = 'NULL' WHERE id = '%s' AND active = '1']], id))
  end
  return db:query(fmt([[INSERT INTO cfadmin_menus(`parent`, `name`, `url`, `icon`, `create_at`, `update_at`, `active`) VALUES('%s', '%s', '%s', '%s', '%s', '%s', '1')]], opt.id, opt.name, opt.url, opt.icon, now, now))
end

-- 更新菜单
function menu.menu_update (db, opt)
  local ret, err = db:query(fmt([[SELECT id FROM cfadmin_menus WHERE parent == '%s' AND active = '1']], opt.id))
  return db:query(fmt([[UPDATE cfadmin_menus SET name = '%s', url = '%s', icon = '%s'  WHERE id = '%s' AND active = '1']], opt.name, ret and #ret > 0 and "NULL" or opt.url, opt.icon, opt.id))
end

-- dtree专用结构
function menu.menu_tree (db)
  local menus, err = db:query([[SELECT id, parent AS parentId, name AS title FROM cfadmin_menus WHERE active = '1']])
  for _, menu in ipairs(menus) do
    menu.checkArr = "0"
  end
  return menus
end

-- 删除菜单与下属子菜单
function menu.menu_delete (db, id)
  local id_list = {}
  local menus, err = db:query(fmt([[SELECT id FROM cfadmin_menus WHERE parent = '%s' AND active = '1']], id))
  if menus and #menus > 0 then
    for _, menu in ipairs(menus) do
      id_list[#id_list+1] = menu.id
    end
    local subs, err = db:query(fmt([[SELECT id FROM cfadmin_menus WHERE parent IN (%s) AND active = '1']], concat(id_list, ', ')))
    if subs and #subs > 0 then
      for _, sub in ipairs(subs) do
        id_list[#id_list+1] = sub.id
      end
    end
  end
  id_list[#id_list+1] = id
  local now = os_time()
  local list = concat(id_list, ', ')
  -- 删除menu
  db:query(fmt([[UPDATE cfadmin_menus SET active = '0', update_at = '%s' WHERE id IN (%s) AND active = '1']], now,  list))
  -- 删除role关联permissions
  db:query(fmt([[UPDATE cfadmin_permissions SET active = '0', update_at = '%s' WHERE menu_id IN (%s) AND active = '1']], now,  list))
end

return menu
