local class = require "class"
local tcp = require "internal.TCP"

local crypt = require "crypt"
local base64encode = crypt.base64encode

local type = type
local tonumber = tonumber
local tostring = tostring
local match = string.match
local fmt = string.format
local os_date = os.date
local concat = table.concat

local MAX_PACKET_SIZE = 1024

local function read_packet(str)
	local str_code, err = match(str, "(%d+) (.+)\r\n")
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
  self.ssl = opt.SSL
  self.host = opt.host
  self.port = opt.port
  self.to = opt.to
  self.from = opt.from
  self.mime = opt.mime
  self.subject = opt.subject
  self.content = opt.content
  self.username = opt.username
  self.password = opt.password
  self.sock = tcp:new()
end

-- 发送握手包
function smtp:hello_packet ()
  local code, data, err
  data, err = self:recv(MAX_PACKET_SIZE)
  if not data then
    return nil, err
  end
  code, err = read_packet(data)
  if not code then
    return nil, time().."[HELO ERROR]: 不支持的协议."
  end
  -- 发送HELO命令
  local ok = self:send("HELO cf_smtp/0.1\r\n")
  if not ok then
    return nil, time().."[HELO ERROR]: 发送HELO失败."
  end
  -- 接收HELO回应
  data, err = self:recv(MAX_PACKET_SIZE)
  if not data then
    return nil, err
  end
  code, err = read_packet(data)
  if code ~= 250 and code ~= 220 then
    return nil, time()..'[HELO ERROR]: ' .. tostring(err) or '服务器关闭了连接.'
  end
  return true
end

-- 登录认证
function smtp:auth_packet ()
  local code, data, err
  local ok = self:send("AUTH LOGIN\r\n")
  if not ok then
    return nil, "AUTH LOGIN ERROR]: 发送AUTH LOGIN失败"
  end
  data, err = self:recv(MAX_PACKET_SIZE)
  if not data then
    return nil, time()..'[AUTH LOGIN ERROR]: 1.' .. tostring(err) or '服务器关闭了连接. '
  end
  code, err = read_packet(data)
  if not code or code ~= 334 then
    return nil, time()..'[AUTH LOGIN ERROR]: 1. 验证失败('.. tostring(code) .. (err or '未知错误') ..')'
  end
  -- 发送base64用户名
  local ok = self:send(base64encode(self.username)..'\r\n')
  if not ok then
    return nil, "[AUTH LOGIN ERROR]: 发送username失败"
  end
  data, err = self:recv(MAX_PACKET_SIZE)
  if not data then
    return nil, time()..'[AUTH LOGIN ERROR]: 2.' .. tostring(err) or '服务器关闭了连接.'
  end
  code, err = read_packet(data)
  if not code or code ~= 334 then
    return nil, time()..'[AUTH LOGIN ERROR]: 2. 验证失败('.. tostring(code) .. (err or '未知错误') ..')'
  end
  -- 发送base64密码
  local ok = self:send(base64encode(self.password)..'\r\n')
  if not ok then
    return nil, "[AUTH LOGIN ERROR]: 发送password失败"
  end
  data, err = self:recv(MAX_PACKET_SIZE)
  if not data then
    return nil, time()..'[AUTH LOGIN ERROR]: 3.' .. tostring(err) or '服务器关闭了连接.'
  end
  code, err = read_packet(data)
  if not code or code ~= 235 then
    return nil, time()..'[AUTH LOGIN ERROR]: 3. 验证失败('.. tostring(code) .. (err or '未知错误') ..')'
  end
  return code, err
end

-- 发送邮件头部
function smtp:send_header ()
  local code, data, err
  -- 邮件发送者
  local ok = self:send(fmt("MAIL FROM:<%s>\r\n", self.from))
  if not ok then
    return nil, "[MAIL FROM ERROR]: 发送FROM失败"
  end
  data, err = self:recv(MAX_PACKET_SIZE)
  if not data then
    return nil, time()..'[MAIL FROM ERROR]: ' .. tostring(err) or '服务器关闭了连接. '
  end
  code, err = read_packet(data)
  if not code or code ~= 250 then
    return nil, time()..'[MAIL FROM ERROR]: ('.. tostring(code) .. (err or '未知错误') ..')'
  end
  -- 邮件接收者
  local ok = self:send(fmt("RCPT TO:<%s>\r\n", self.to))
  if not ok then
    return nil, "[MAIL FROM ERROR]: 发送TO失败"
  end
  data, err = self:recv(MAX_PACKET_SIZE)
  if not data then
    return nil, time()..'[RCPT TO ERROR]: ' .. tostring(err) or '服务器关闭了连接. '
  end
  code, err = read_packet(data)
  if not code or code ~= 250 then
    return nil, time()..'[RCPT TO ERROR]: ('.. tostring(code) .. (err or '未知错误') ..')'
  end
  return true
end

-- 发送邮件内容
function smtp:send_content ()
  local code, data, err
  -- DATA命令, 开始发送邮件实体
  local ok = self:send("DATA\r\n")
  if not ok then
    return nil, "[MAIL CONTENT ERROR]: 发送DATA失败"
  end
  data, err = self:recv(MAX_PACKET_SIZE)
  if not data then
    return nil, time()..'[MAIL CONTENT ERROR]: ' .. tostring(err) or '服务器关闭了连接. '
  end
  code, err = read_packet(data)
  if not code or code ~= 354 then
    return nil, time()..'[MAIL CONTENT ERROR]: ('.. tostring(code) .. (err or '未知错误') ..')'
  end
  local FROM = fmt("from:<%s>\r\n", self.from)
  local TO = fmt("to:<%s>\r\n", self.to)
  local SUBJECT = fmt("subject:%s\r\n", self.subject)
  if self.mime and self.mime == 'html' then
    self.mime = concat({
      "Content-Type: text/html; charset=utf-8",
      "Content-Transfer-Encoding:base64\r\n"
    }, '\r\n')
  else
    self.mime = concat({
      "Content-Type: text/plain; charset=utf-8",
      "Content-Transfer-Encoding:base64\r\n"
    }, '\r\n')
  end
  local ok = self:send(FROM..TO..SUBJECT..self.mime..'\r\n'..base64encode(self.content)..'\r\n\r\n.\r\n')
  if not ok then
    return nil, "[MAIL CONTENT ERROR]: 发送Content失败"
  end
  data, err = self:recv(MAX_PACKET_SIZE)
  if not data then
    return nil, time()..'[MAIL CONTENT ERROR]: ' .. tostring(err) or '服务器关闭了连接. '
  end
  code, err = read_packet(data)
  if not code or code ~= 250 then
    return nil, time()..'[MAIL CONTENT ERROR]: ('.. tostring(code) .. (err or '未知错误') ..')'
  end
  return true
end

function smtp:send_mail ()
  local ok, err = self:send_header()
  if not ok then
    return ok, err
  end
  local ok, err = self:send_content()
  if not ok then
    return ok, err
  end
  return true
end

-- 超时时间
function smtp:set_timeout (timeout)
  if type(timeout) == number and number > 0 then
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

function smtp:close ()
  if self.sock then
    self.sock:close()
    self.sock = nil
  end
end

return smtp
