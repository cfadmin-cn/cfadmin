local smtp = require "protocol.smtp"

local toint = math.tointeger
local match = string.match

local function check_mail(mail)
	if match(mail, '.+@.+') then
		return true
	end
	return false
end

local mail = {}

function mail.send(opt)
	if not opt.username or not opt.password or opt.username == '' or opt.password == '' then
		return nil, "Username or password cannot be empty."
	end
	if not opt.from or not opt.to or opt.from == '' or opt.to == '' or not check_mail(opt.from) or not check_mail(opt.to) then
		return nil, "The sender or receiver of the email cannot be empty."
	end
	if not opt.host or not opt.port or opt.host == '' or (not toint(opt.port)) or (toint(opt.port) <= 0 or toint(opt.port) > 65535) then
		return nil, "Invalid target mail server configuration."
	end
	if not opt.subject or opt.subject == '' then
		return nil, "The email subject is empty, please check the configuration parameters."
	end
	if not opt.content or opt.content == '' then
		return nil, "The email content is empty, please check the configuration parameters."
	end
	local s = smtp:new(opt):set_timeout(15)
	-- 开始发送邮件
	local ok, err
	-- 尝试连接服务器
	ok, err = s:connect()
	if not ok then
		return nil, err, s:close()
	end
	-- print("连接成功")
	-- 尝试握手包
	ok, err = s:hello_packet()
	if not ok then
		return nil, err, s:close()
	end
	-- print("握手成功")
	-- 身份认证
	ok, err = s:auth_packet()
	if not ok then
		return nil, err, s:close()
	end
	-- print("认证成功")
	-- 发送数据
	ok, err = s:send_mail()
	s:close()
	if not ok then
		return nil, err
	end
	return ok
end


return mail
