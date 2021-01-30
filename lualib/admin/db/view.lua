local view = {}

-- 获取顶部栏
function view.get_headers (db)
  return db:query([[SELECT id, name, url FROM cfadmin_headers WHERE active = 1 ORDER BY `id`]])
end

-- 获取菜单栏
function view.get_menus (db)
  return db:query([[SELECT id, parent, name, url, icon, create_at, update_at FROM cfadmin_menus WHERE active = 1 ORDER BY `id`]])
end

return view
