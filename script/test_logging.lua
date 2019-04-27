local LOG = require "logging"

-- 初始化日志
local log = LOG:new { path = './admin' }

-- 打印
log:INFO('this is INFO LOG', nil, 1, nil)
log:DEBUG('this is DEBUG LOG', nil, nil, 1)
log:WARN('this is WARN LOG', 1, nil, nil)
log:ERROR('this is ERROR LOG', nil, nil, nil, log)
