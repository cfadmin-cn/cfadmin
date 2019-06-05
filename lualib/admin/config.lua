local config = {
  cdn = '/', -- 静态文件前缀地址
  github = 'https://github.com/candymi/core_framework', -- 跳转地址
  cache = false, -- 是否缓存模板
  locale = "ZH-CN", -- 当前语言
  display_lang = true,   -- 默认显示语言标签
  locales = require "admin.locales", -- 语言表
  secure = 'cfadmin', -- 生成token的secure
  cookie_timeout = 86400 -- Cookie超时时间
}

return config
