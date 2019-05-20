local crypt = require "crypt"
local config = require "admin.config"

local fmt = string.format
local os_time = os.time
-- 作为初始化DB工作, 这个函数(must)只能运行一次.
-- 一般情况下, 大家在设计完成后都会手动简历数据表并导入内容.
-- 此文件仅作为作者调试与使用者开发使用, 不对此文件做任何其它保证.
local log = require "logging"
local Log = log:new({path = 'admin-db'})

return function ()
  local ret, err
  local db = config.db
  local now = os_time()
  -- 初始化角色
  ret, err = db:query(fmt([[
  INSERT INTO
    cfadmin_roles
      (`id`, `name`, `is_admin`, `create_at`, `update_at`, `active`)
    VALUES
      ('1', '管理员', '1', '%s', '%s', '1')
  ]], now, now))
  if not ret then
    Log:ERROR(err)
    return nil, err
  end
  -- 初始化用户
  ret, err = db:query(fmt([[
  INSERT INTO
    `cfadmin_users`
      (`name`, `username`, `password`, `email`, `phone`, `role`, `create_at`, `update_at`, `active`)
    VALUES
      ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '1')]],
  '管理员', 'admin', crypt.hexencode(crypt.sha1('admin')), '869646063@qq.com', '13000000000', '1', now, now))
  if not ret then
    Log:ERROR(err)
    return nil, err
  end
  return true, '初始化完成'
end
