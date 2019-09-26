local LOG = require "logging"

--[[
  日志库分为2种使用方式: 1. 初始化后使用, 2. 直接导入使用;  两者之间的差异根据不同需求不同使用.

  初始化使用时为了将不同的日志打印并dump到不同的日志文件中, 这中方式在调试开发的时候非常有用.

  直接导入使用不会将日志持久化到磁盘(输出到stdout), 相对于dump到本地磁盘. 它更是适用于docker这种做为集中式日志收集.

  `path`参数通常是一个日志文件名, 它的前缀为`logs/{your_path}`, 但是你可以根据实际情况加上路径对文件进行分割.

  `dump`参数决定是否将打印内容序列化到磁盘.

  注意: 如果您的path中包含了目录, 需要先自行创建目录. 否则将会打印错误.
]]

-- 初始化日志
local log = LOG:new { path = 'admin/main' , dump = true }

print()

-- dump到磁盘
log:INFO('this is INFO LOG', nil, 1, nil)
log:DEBUG('this is DEBUG LOG', nil, nil, 1)
log:WARN('this is WARN LOG', 1, nil, nil)
log:ERROR('this is ERROR LOG', nil, nil, nil)

print()

-- 仅输出到stdout
LOG:INFO('this is INFO LOG', nil, 1, nil)
LOG:DEBUG('this is DEBUG LOG', nil, nil, 1)
LOG:WARN('this is WARN LOG', 1, nil, nil)
LOG:ERROR('this is ERROR LOG', nil, nil, nil)
