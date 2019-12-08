
local fmt = string.format
local os_time = os.time

local token = {}

-- 写入Token
function token.token_add (db, uid, name, token)
  return db:query(fmt(
  [[
    INSERT INTO
      `cfadmin_tokens`(`uid`, `name`, `token`, `create_at`)
    VALUES
      ('%s', '%s', '%s', '%s')
    ON DUPLICATE KEY UPDATE `token` = '%s', `name` = '%s', `create_at` = '%s'
  ]],
  uid, name, token, os_time(), token, name, os_time()))
end

-- 删除Token
function token.token_delete (db, id, tk)
  return db:query(fmt([[DELETE FROM cfadmin_tokens WHERE uid = '%s' or token = '%s' LIMIT 1]], id, tk))
end

-- Token 是否存在
function token.token_exists (db, token)
  local ret, err = db:query(fmt([[SELECT uid, name, token FROM cfadmin_tokens WHERE token = '%s']], token:gsub("'", "\\'")))
  if not ret or #ret == 0 then
    return
  end
  return ret[1]
end

-- 根据token查用户信息
function token.token_to_userinfo (db, token)
  return db:query(fmt([[
  SELECT
  	`cfadmin_users`.id,
  	`cfadmin_users`.name,
  	`cfadmin_users`.username,
  	`cfadmin_users`.password,
  	`cfadmin_tokens`.token,
  	`cfadmin_users`.role,
    `cfadmin_users`.name AS role_name,
  	`cfadmin_roles`.is_admin,
  	`cfadmin_users`.email,
  	`cfadmin_users`.phone,
  	`cfadmin_users`.create_at,
  	`cfadmin_users`.update_at
  FROM
  	cfadmin_users, cfadmin_tokens, cfadmin_roles
  WHERE
  	`cfadmin_tokens`.uid = `cfadmin_users`.id AND
    `cfadmin_roles`.id = `cfadmin_users`.role AND
  	`cfadmin_tokens`.token = '%s'
  LIMIT 1]], token:gsub("'", "\\'")))[1]
end

return token
