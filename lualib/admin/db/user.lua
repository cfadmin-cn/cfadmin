local toint = math.tointeger
local tostring = tostring
local os_time = os.time
local fmt = string.format

local user = {}

-- 用户列表
function user.user_list (db, opt)
  local limit = toint(opt.limit) or 10
  local page = toint(opt.page) or 1
  return db:query(fmt([[
  SELECT
    `cfadmin_users`.id,
    `cfadmin_users`.name,
    `cfadmin_users`.username,
    `cfadmin_roles`.name AS role_name,
    `cfadmin_users`.email,
    `cfadmin_users`.phone,
    `cfadmin_users`.create_at,
    `cfadmin_users`.update_at,
    `cfadmin_users`.active
  FROM cfadmin_users, cfadmin_roles
  WHERE
    `cfadmin_roles`.id = `cfadmin_users`.role AND `cfadmin_users`.active = 1
  LIMIT %s, %s
  ]], limit * (page - 1), limit))
end

-- 模糊查找用户列表
function user.find_by_username (db, opt)
  local limit = toint(opt.limit) or 10
  local page = toint(opt.page) or 1
  local condition
  if opt.condition == 'id' or opt.condition == 'email' or opt.condition == 'phone' then
    condition = fmt("`cfadmin_users`.`%s` = '%s'", opt.condition, opt.value)
  else
    condition = fmt("`cfadmin_users`.`%s` LIKE '%%%s%%'", opt.condition, opt.value)
  end
  return db:query(fmt([[
  SELECT
    `cfadmin_users`.id,
    `cfadmin_users`.name,
    `cfadmin_users`.username,
    `cfadmin_roles`.name AS role_name,
    `cfadmin_users`.email,
    `cfadmin_users`.phone,
    `cfadmin_users`.create_at,
    `cfadmin_users`.update_at,
    `cfadmin_users`.active
  FROM cfadmin_users, cfadmin_roles
  WHERE
    `cfadmin_roles`.id = `cfadmin_users`.role AND `cfadmin_users`.active = 1 AND %s
   ORDER BY `cfadmin_users`.id LIMIT %s, %s
  ]], condition, limit * (page - 1), limit))
end

-- 用户总数
function user.user_count (db)
  return db:query([[SELECT count(id) AS count FROM cfadmin_users WHERE active = '1']])[1]['count']
end

-- 用户是否存在
function user.user_exists (db, username, uid)
  local condition
  if username then
    condition = fmt([[`cfadmin_users`.username = '%s']], username)
  elseif uid then
    condition = fmt([[`cfadmin_users`.id = '%s']], uid)
  else
    return
  end
  local user, err = db:query(fmt([[
  SELECT
    `cfadmin_users`.id,
    `cfadmin_users`.name,
    `cfadmin_users`.username,
    `cfadmin_users`.password
  FROM cfadmin_users
  WHERE
    `cfadmin_users`.active = '1' AND %s
  LIMIT 1]], condition))
  if not user then
    return nil, err
  end
  return user[1]
end

-- 用户名或者登录名是否存在
function user.user_name_or_username_exists (db, name, username)
  local ret, err = db:query(fmt([[SELECT name, username FROM cfadmin_users WHERE active = '1' AND (name = '%s' OR username = '%s')]], name, username))
  if ret and #ret > 0 then
    return true
  end
  return false
end

-- 用户信息
function user.user_info (db, uid)
  local ret, err = db:query(fmt([[
  SELECT
  	`cfadmin_users`.id,
    `cfadmin_users`.name,
    `cfadmin_users`.username,
    `cfadmin_users`.password,
    `cfadmin_roles`.name AS role_name,
    `cfadmin_roles`.is_admin,
    `cfadmin_users`.role,
    `cfadmin_users`.phone,
    `cfadmin_users`.email
  FROM
  	cfadmin_users, cfadmin_roles
  WHERE
  	`cfadmin_users`.role = `cfadmin_roles`.id AND `cfadmin_users`.id = '%s'
  LIMIT 1]], uid))
  return ret[1]
end

-- 添加用户
function user.user_add (db, opt)
  local now = os_time()
  return db:query(fmt([[
    INSERT INTO cfadmin_users(`name`, `username`, `password`, `role`, `email`, `phone`, `create_at`, `update_at`, `active`)
      VALUES ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '1')
  ]], opt.name, opt.username, opt.password, opt.role, opt.email, opt.phone, now, now))
end

-- 删除用户
function user.user_delete (db, uid)
  return db:query(fmt([[UPDATE cfadmin_users SET active = '0', update_at = '%s' WHERE id = '%s']], os_time(), uid))
end

function user.user_update (db, opt)
  return db:query(fmt([[
  UPDATE cfadmin_users
    SET name = '%s', username = '%s', password = '%s', role = '%s', email = '%s', phone = '%s', update_at = '%s' WHERE id = '%s'
  ]], opt.name, opt.username, opt.password, opt.role, opt.email, opt.phone, os_time(), opt.id))
end

-- 更新用户密码
function user.user_update_password (db, opt)
  return db:query(fmt([[UPDATE cfadmin_users SET password = '%s', update_at = '%s' WHERE id = '%s' AND active = '1']], opt.password, os_time(), opt.id))
end

-- 更新用户信息
function user.user_update_info (db, opt)
  return db:query(fmt([[UPDATE cfadmin_users SET name = '%s', phone = '%s', email = '%s', update_at = '%s' WHERE id = '%s' AND active = '1']], opt.name, opt.phone, opt.email, os_time(), opt.id))
end

return user
