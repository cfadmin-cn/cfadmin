local toint = math.tointeger
local os_time = os.time
local fmt = string.format

local header = {}

-- header 列表
function header.header_list (db, opt)
  local limit = toint(opt.limit) or 10
  local page = toint(opt.page) or 1
  return db:query(fmt([[SELECT id, name, url, create_at, update_at FROM cfadmin_headers WHERE active = 1 ORDER BY id LIMIT %s, %s]], limit * (page - 1) , limit))
end

-- 获取指定header
function header.get_header (db, id)
  local ret = db:query(fmt([[ SELECT id, name, url FROM cfadmin_headers WHERE id = '%s' LIMIT 1]], id))
  if not ret or #ret == 0 then
    return
  end
  return ret[1]
end

-- header 总数
function header.header_count (db)
  return db:query([[SELECT count(id) AS count FROM cfadmin_headers WHERE active = 1]])[1]['count']
end

-- 是否存在此header
function header.header_exists (db, id)
  local ret = db:query(fmt([[SELECT id FROM cfadmin_headers WHERE id = '%s' AND active = 1 LIMIT 1]], id))
  return ret and #ret > 0
end

-- 删除header
function header.header_delete (db, id)
  return db:query(fmt([[UPDATE cfadmin_headers SET active = '0', update_at = '%s' WHERE id = '%s' AND active = 1]], os_time(), id))
end

-- 增加header
function header.header_add(db, opt)
  return db:query(fmt([[INSERT INTO cfadmin_headers(`name`, `url`, `create_at`, `update_at`, `active`) VALUES('%s', '%s', '%s', '%s', 1)]], opt.name, opt.url, os_time(), os_time()))
end

-- 修改header
function header.header_update (db, opt)
  return db:query(fmt([[UPDATE cfadmin_headers SET name = '%s', url = '%s', update_at = '%s' WHERE id = '%s']], opt.name, opt.url, os_time(), opt.id))
end

return header
