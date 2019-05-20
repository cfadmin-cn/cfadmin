
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
  uid, name, token, os_time(), -- VALUES
  token, name, os_time())) -- ON DUPLICATE VALUES
end

-- 删除Token
function token.token_delete (db, id)
  return db:query(fmt([[DELETE FROM cfadmin_tokens WHERE uid = '%s' LIMIT 1]], id))
end

-- Token 是否存在
function token.token_exists (db, token)
  local ret, err = db:query(fmt([[SELECT uid, name, token FROM cfadmin_tokens WHERE token = '%s']], token))
  if not ret or #ret == 0 then
    return
  end
  return ret[1]
end

return token
