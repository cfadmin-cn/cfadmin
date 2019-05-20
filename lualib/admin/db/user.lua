local toint = math.tointeger
local tostring = tostring
local os_time = os.time
local fmt = string.format

local json = require "json"
local json_encode = json.encode
local json_decode = json.decode

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
    `cfadmin_roles`.name as role_name,
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

-- 用户总数
function user.user_count (db)
  return db:query([[SELECT count(id) as count FROM cfadmin_users WHERE active = '1']])[1]['count']
end

-- 用户是否存在
function user.user_exists (db, username, uid)
  return db:query(fmt([[
  SELECT
    `cfadmin_users`.id,
    `cfadmin_users`.name,
    `cfadmin_users`.username,
    `cfadmin_users`.password
  FROM cfadmin_users
  WHERE
    `cfadmin_users`.active = '1' AND `cfadmin_users`.username = '%s' OR `cfadmin_users`.id = '%s'
  LIMIT 1]],
  tostring(username), toint(uid)))[1]
end

-- 用户信息
function user.user_info (db, uid)
  local ret, err = db:query(fmt([[
  SELECT
  	`cfadmin_users`.id,
    `cfadmin_users`.name,
    `cfadmin_users`.username,
    `cfadmin_users`.password,
    `cfadmin_roles`.name as role_name,
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
  return db:query(fmt([[UPDATE cfadmin_users SET password = '%s' WHERE id = '%s' AND active = '1']], opt.password, opt.id))
end

-- 更新用户信息
function user.user_update_info (db, opt)
  return db:query(fmt([[UPDATE cfadmin_users SET name = '%s', phone = '%s', email = '%s' WHERE id = '%s' AND active = '1']], opt.name, opt.phone, opt.email, opt.id))
end

return user
