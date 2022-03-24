local class = require "class"
local tcp = require "internal.TCP"

local crypt = require "crypt"
local base64encode = crypt.base64encode

local type = type
local toint = math.tointeger
local tonumber = tonumber
local tostring = tostring
local match = string.match
local fmt = string.format
local os_date = os.date
local concat = table.concat

local MAX_PACKET_SIZE = 4096

local CRLF = '\x0d\x0a'

local function read_packet(str)
	local str_code, err = match(str, "(%d+) (.+)")
	local code = tonumber(str_code)
	if not code then
		return
	end
	return code, err
end

local function time()
	return os_date("[%Y/%m/%d %H:%M:%S]")
end

local smtp = class("smtp")

function smtp:ctor (opt)
  self.ssl = opt.SSL or opt.ssl
  self.host = opt.host
  self.port = opt.port
  self.to = opt.to
  self.from = opt.from
  self.fromName = opt.fromName
  self.mime = opt.mime
  self.subject = opt.subject
  self.content = opt.content
  self.username = opt.username
  self.password = opt.password
  self.sock = tcp:new()
end

-- 发送握手包
function smtp:hello_packet ()
  local code, data, info
  -- 接收服务端信息
  data = self:readline(CRLF)
  if not data then
    return nil, "SMTP Client Can't connect to server."
  end
  code, info = read_packet(data)
  if not code then
    return nil, "[HELO ERROR]: Unsupported protocol."
  end
  -- 发送HELO命令
  if not self:sendline("HELO cf_smtp/0.1", CRLF) then
    return nil, "[HELO ERROR]: Failed to send HELO message."
  end
  -- 接收HELO回应
  data = self:recv(MAX_PACKET_SIZE)
  if not data then
    return nil, "SMTP Server Close this session."
  end
  code, info = data:sub(1, 3), data:sub(4)
  if toint(code) ~= 250 and toint(code) ~= 220 then
    return nil, "[HELO ERROR]: " .. (info or "Invalid Response." )
  end
  return true
end

-- 登录认证
function smtp:auth_packet ()
  local code, data, err
	-- 发送登录认证请求
  if not self:sendline("AUTH LOGIN", CRLF) then
    return nil, "AUTH LOGIN ERROR]: SMTP Server Close this session."
  end
  data = self:readline(CRLF)
  if not data then
    return nil, '[AUTH LOGIN ERROR]: 1. SMTP Server Close this session.'
  end
  code, err = read_packet(data)
  if not code or code ~= 334 then
    return nil, '[AUTH LOGIN ERROR]: 1. 验证失败('.. tostring(code) .. (err or '未知错误') ..')'
  end
  -- 发送base64用户名
  if not self:sendline(base64encode(self.username), CRLF) then
    return nil, "[AUTH LOGIN ERROR]: SMTP Server Close this session when sending username."
  end
  data = self:readline(CRLF)
  if not data then
    return nil, '[AUTH LOGIN ERROR]: 2. SMTP Server Close this session.'
  end
  code, err = read_packet(data)
  if not code or code ~= 334 then
    return nil, '[AUTH LOGIN ERROR]: 2. verification failed('.. (err or '未知错误') ..')'
  end
  -- 发送base64密码
  if not self:sendline(base64encode(self.password), CRLF) then
    return nil, "[AUTH LOGIN ERROR]: SMTP Server Close this session when sending password."
  end
  data = self:readline(CRLF)
  if not data then
    return nil, '[AUTH LOGIN ERROR]: 3. SMTP Server Close this session.'
  end
  code, err = read_packet(data)
  if not code or code ~= 235 then
    return nil, '[AUTH LOGIN ERROR]: ' .. (err or 'Token verification failed.')
  end
  return true
end

-- 发送邮件头部
function smtp:send_header ()
  local code, data, err
  -- 发送邮件来源
  if not self:sendline(fmt("MAIL FROM: <%s>", self.from), CRLF) then
    return nil, "[MAIL FROM ERROR]: Sending `MAIL FROM` Failed."
  end
  data = self:readline(CRLF)
  if not data then
    return nil, '[MAIL FROM ERROR]: SMTP Server Close this session.'
  end
  code, err = read_packet(data)
  if not code or code ~= 250 then
    return nil, '[MAIL FROM ERROR]: ('.. tostring(code) .. (err or 'Unknown Error.') ..')'
  end
  -- 发送邮件接收者
  local ok = self:sendline(fmt("RCPT TO: <%s>", self.to), CRLF)
  if not ok then
    return nil, "[RCPT TO ERROR]: Sending `RCPT TO` Failed."
  end
  data = self:readline(CRLF)
  if not data then
    return nil, '[RCPT TO ERROR]: SMTP Server Close this session.'
  end
  code, err = read_packet(data)
  if not code or code ~= 250 then
    return nil, '[RCPT TO ERROR]: ('.. tostring(code) .. (err or '未知错误') ..')'
  end
  return true
end

-- 发送邮件内容
function smtp:send_content ()
  local code, data, err
  -- 发送DATA命令, 开始发送邮件实体
  if not self:sendline("DATA", CRLF) then
    return nil, "[MAIL CONTENT ERROR]: Sending `DATA` Failed."
  end
  data = self:readline(CRLF)
  if not data then
    return nil, '[MAIL CONTENT ERROR]: SMTP Server Close this session.'
  end
  code, err = read_packet(data)
  if not code or code ~= 354 then
    return nil, '[MAIL CONTENT ERROR]: ('.. tostring(code) .. (err or '未知错误') ..')'
  end
  if self.mime and self.mime == 'html' then
    self.mime = "MIME-Version: 1.0\r\nContent-Type: text/html; charset=utf-8\r\nContent-Transfer-Encoding: base64\r\n"
  else
		self.mime = "MIME-Version: 1.0\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: base64\r\n"
  end
	-- 发送邮件实体头部
	local ok = self:send(concat({fmt("From: %s <%s>\r\n", self.fromName or "", self.from), fmt("To: <%s>\r\n", self.to), fmt("Subject: %s\r\n", self.subject), self.mime, CRLF}))
	if not ok then
		return nil, "[MAIL CONTENT ERROR]: 发送Content Headers失败."
	end
	-- 发送邮件实体内容
  if not self:sendline(base64encode(self.content), "\r\n\r\n.\r\n") then
    return nil, "[MAIL CONTENT ERROR]: 发送Content Body失败."
  end
  data = self:readline(CRLF)
  if not data then
    return nil, time()..'[MAIL CONTENT ERROR]: ' .. (err or '服务器关闭了连接. ')
  end
  code, err = read_packet(data)
  if not code or code ~= 250 then
    return nil, time()..'[MAIL CONTENT ERROR]: ('.. tostring(code) .. (err or '未知错误') ..')'
  end
  return self:sendline("QUIT", CRLF)
end

function smtp:send_mail ()
  local ok, err
  ok, err = self:send_header()
  if not ok then
    return false, err
  end
  ok, err = self:send_content()
  if not ok then
    return false, err
  end
  return true
end

-- 超时时间
function smtp:set_timeout (timeout)
  if type(timeout) == 'number' and timeout > 0 then
    self.timeout = timeout
  end
  return self
end

-- 连接到smtp服务器
function smtp:connect ()
  self.sock:timeout(self.timeout or 15)
  if self.ssl then
    return self.sock:ssl_connect(self.host, self.port)
  end
  return self.sock:connect(self.host, self.port)
end

-- 接收数据
function smtp:recv (bytes)
  if self.ssl then
    return self.sock:ssl_recv(bytes)
  end
  return self.sock:recv(bytes)
end

-- 发送数据
function smtp:send (data)
  if self.ssl then
    return self.sock:ssl_send(data)
  end
  return self.sock:send(data)
end

-- sendline
function smtp:readline(sp)
  if self.ssl then
    return self.sock:ssl_readline(sp, true)
  end
  return self.sock:readline(sp, true)
end

-- sendline
function smtp:sendline(data, sp)
  return self.sock:send(data) and self.sock:send(sp)
end

function smtp:close ()
  if self.sock then
    self.sock:close()
    self.sock = nil
  end
end

return smtp
