local smtp = require "protocol.smtp"

local tonumber = tonumber
local match = string.match
local os_date = os.date

local function check_mail(mail)
	if match(mail, '.+@.+') then
		return true
	end
	return false
end

local function time()
	return os_date("[%Y/%m/%d %H:%M:%S]")
end

local mail = {}

function mail.send(opt)
	local ok, session, err
	if not opt.username or not opt.password or opt.username == '' or opt.password == '' then
		return nil, "用户名或密码不能为空"
	end
	if not opt.from or not opt.to or opt.from == '' or opt.to == '' then
		return nil, "邮箱发送者与接受者不能空"
	end
	if not check_mail(opt.from) or not check_mail(opt.to) then
		return nil, "发送者与接受者邮箱格式不正确"
	end
	if not opt.host or not opt.port or opt.host == '' or (tonumber(opt.port) <= 0 or tonumber(opt.port) > 65535) then
		return nil, "邮件server配置错误, 请检查配置参数."
	end
	if not opt.subject or opt.subject == '' then
		return nil, "邮件主题为空, 请检查配置参数."
	end
	if not opt.content or opt.content == '' then
		return nil, "邮件内容为空, 请检查配置参数"
	end

	local s = smtp:new(opt):set_timeout(15)

	-- 尝试连接服务器
	local ok, err = s:connect()
	if not ok then
		return nil, err, s:close()
	end
	-- print("连接成功")
	-- 尝试握手包
	local ok, err = s:hello_packet()
	if not ok then
		return nil, err, s:close()
	end
	-- print("握手成功")
	-- 身份认证
	local ok, err = s:auth_packet()
	if not ok then
		return nil, err, s:close()
	end
	-- print("认证成功")
	-- 发送数据
	local ok, err = s:send_mail()
	if not ok then
		return nil, err, s:close()
	end
	return ok, time()..": 邮件发送成功!", s:close()
end


return mail
