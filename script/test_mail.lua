local mail = require "mail"

local ok, err = mail.send {
	host = 'smtp.qq.com', -- 收件服务器
	port = 465,	 -- 收件服务器端口
	username = "869646063", -- 用户名
	-- password = "qovppnukdbcabcdg", -- 密码或客户端授权码
	from = '869646063@qq.com', -- 发件人地址
	to   = 'xwmrzg@163.com',   -- 收件人地址
	subject = "测试邮件主题",	   -- 主题
	SSL = true,				   -- 该端口是否安全连接端口
	content = "这是一封测试邮件!", -- 邮件内容
}

print(ok, err)