local type = type
local assert = assert
local find = string.find

local http = {}
--[[
	httpd 的 before函数本身仅根据状态码来确定具体Action
	如果使用者在函数内直接写入状态码, 请确保您非常清楚before函数的实现.
--]]


-- 成功
function http.ok()
	return 200
end

-- 重定向
function http.redirect(domain, code)
	assert(type(domain) == 'string' and domain ~= '' and find(domain, '^http[s]?://.+'), '重定向必须给出一个字符串类型的域名(http[s]://domain)')
	if type(code) == 'number' and (code == 301 or code == 302) then
		return code, domain
	end
	return 302, domain
end

-- 指定错误码
function http.throw(code, body)
	assert(type(code) == 'number' and code >= 400 and code < 500, '指定错误码必须在范围之内(400 - 499)')
	if type(body) == 'string' and body ~= '' then
		return code, body
	end
	return code
end

return http