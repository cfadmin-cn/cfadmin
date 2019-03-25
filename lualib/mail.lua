local TCP = require "internal.TCP"
local crypt = require "crypt"

local base64encode = crypt.base64encode

local tonumber = tonumber
local tostring = tostring
local match = string.match
local fmt = string.format

local MAX_PACKET_SIZE = 1024

local mail = {}

local function read_packet(str)
	local str_code, err = match(str, "(%d+) (.+)\r\n")
	local code = tonumber(str_code)
	if not code then
		return
	end
	return code, err
end

local function check_mail(mail)
	if match(mail, '.+@.+') then
		return true
	end
	return false
end

-- hook connect 与 ssl connect
local function connect(host, port, SSL)
	local tcp = TCP:new()
	if not SSL then
		local ok, err = tcp:connect(host, port)
		if not ok then
			tcp:close()
			return ok, err
		end
	else
		local ok, err = tcp:ssl_connect(host, port)
		if not ok then
			tcp:close()
			return ok, err
		end
	end
	return tcp
end

-- hook read 与 ssl read
local function recv(session, bytes, SSL)
	if not SSL then
		return session:recv(bytes)
	end
	return session:ssl_recv(bytes)
end

-- hook send 与 ssl send
local function send(session, buf, SSL)
	if not SSL then
		return session:send(buf)
	end
	return session:ssl_send(buf)
end

local function close(session)
	return session:close()
end

-- HELO 命令
local function HELO_PACKET(session, SSL)
	local code, data, err
	data, err = recv(session, MAX_PACKET_SIZE, SSL)
	if not data then
		return nil, err
	end
	code, err = read_packet(data)
	if not code then
		return nil, "[HELO ERROR]: 不支持的协议."
	end
	-- 发送HELO命令
	send(session, "HELO CoreFramework(lua)/0.1\r\n", SSL)
	-- 发送HELO命令
	data, err = recv(session, MAX_PACKET_SIZE, SSL)
	if not data then
		return nil, err
	end
	code, err = read_packet(data)
	if code ~= 250 and code ~= 220 then
		return nil, '[HELO ERROR]: ' .. tostring(err) or '服务器关闭了连接.'
	end
	return true
end

-- 验证登录
local function AUTH_PACKET(session, username, password, SSL)
	local code, data, err
	send(session, "AUTH LOGIN\r\n", SSL)
	data, err = recv(session, MAX_PACKET_SIZE, SSL)
	if not data then
		return nil, '[AUTH LOGIN ERROR]: 1.' .. tostring(err) or '服务器关闭了连接. '
	end
	code, err = read_packet(data)
	if not code or code ~= 334 then
		return nil, '[AUTH LOGIN ERROR]: 1. 验证失败('.. tostring(code) .. (err or '未知错误') ..')'
	end
	-- 发送base64用户名
	send(session, base64encode(username)..'\r\n', SSL)
	data, err = recv(session, MAX_PACKET_SIZE, SSL)
	if not data then
		return nil, '[AUTH LOGIN ERROR]: 2.' .. tostring(err) or '服务器关闭了连接.'
	end
	code, err = read_packet(data)
	if not code or code ~= 334 then
		return nil, '[AUTH LOGIN ERROR]: 2. 验证失败('.. tostring(code) .. (err or '未知错误') ..')'
	end
	-- 发送base64密码
	send(session, base64encode(password)..'\r\n', SSL)
	data, err = recv(session, MAX_PACKET_SIZE, SSL)
	if not data then
		return nil, '[AUTH LOGIN ERROR]: 3.' .. tostring(err) or '服务器关闭了连接.'
	end
	code, err = read_packet(data)
	if not code or code ~= 235 then
		return nil, '[AUTH LOGIN ERROR]: 3. 验证失败('.. tostring(code) .. (err or '未知错误') ..')'
	end
	return code, err
end

-- 发送邮件头部
local function MAIL_HEADER(session, from, to, SSL)
	local code, data, err
	-- 邮件发送者
	send(session, fmt("MAIL FROM:<%s>\r\n", from), SSL)
	data, err = recv(session, MAX_PACKET_SIZE, SSL)
	if not data then
		return nil, '[MAIL FROM ERROR]: ' .. tostring(err) or '服务器关闭了连接. '
	end
	code, err = read_packet(data)
	if not code or code ~= 250 then
		return nil, '[MAIL FROM ERROR]: ('.. tostring(code) .. (err or '未知错误') ..')'
	end
	-- 邮件接收者
	send(session, fmt("RCPT TO:<%s>\r\n", to), SSL)
	data, err = recv(session, MAX_PACKET_SIZE, SSL)
	if not data then
		return nil, '[RCPT TO ERROR]: ' .. tostring(err) or '服务器关闭了连接. '
	end
	code, err = read_packet(data)
	if not code or code ~= 250 then
		return nil, '[RCPT TO ERROR]: ('.. tostring(code) .. (err or '未知错误') ..')'
	end
	return true
end

-- 发送邮件内容
local function MAIL_CONTENT(session, from, to, subject, content, SSL)
	local code, data, err
	-- DATA命令, 开始发送邮件实体
	send(session, "DATA\r\n", SSL)
	data, err = recv(session, MAX_PACKET_SIZE, SSL)
	if not data then
		return nil, '[MAIL CONTENT ERROR]: ' .. tostring(err) or '服务器关闭了连接. '
	end
	code, err = read_packet(data)
	if not code or code ~= 354 then
		return nil, '[MAIL CONTENT ERROR]: ('.. tostring(code) .. (err or '未知错误') ..')'
	end
	local FROM = fmt("from:<%s>\r\n", from)
	local TO = fmt("to:<%s>\r\n", to)
	local SUBJECT = fmt("subject:%s\r\n\r\n", subject)
	send(session, FROM..TO..SUBJECT..content..'\r\n\r\n.\r\n', SSL)
	data, err = recv(session, MAX_PACKET_SIZE, SSL)
	if not data then
		return nil, '[MAIL CONTENT ERROR]: ' .. tostring(err) or '服务器关闭了连接. '
	end
	code, err = read_packet(data)
	if not code or code ~= 250 then
		return nil, '[MAIL CONTENT ERROR]: ('.. tostring(code) .. (err or '未知错误') ..')'
	end
	return true
end

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
	-- 连接邮件服务器并且返回tcp session
	session, err = connect(opt.host, opt.port, opt.SSL)
	if not session then
		return nil, err
	end
	-- HELO 命令
	ok, err = HELO_PACKET(session, opt.SSL)
	if not ok then
		close(session)
		return nil, err
	end
	-- AUTH LOGIN 命令
	ok, err = AUTH_PACKET(session, opt.username, opt.password, opt.SSL)
	if not ok then
		close(session)
		return nil, err
	end

	ok, err = MAIL_HEADER(session, opt.from, opt.to, opt.SSL)
	if not ok then
		close(session)
		return nil, err
	end
	ok, err = MAIL_CONTENT(session, opt.from, opt.to, opt.subject, opt.content, opt.SSL)
	if not ok then
		close(session)
		return nil, err
	end
	close(session)
	return ok, "发送成功"
end


return mail