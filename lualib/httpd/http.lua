local json = require "json"
local json_encode = json.encode

local crypt = require "crypt"
local hmac_sha256 = crypt.hmac_sha256
local base64encode = crypt.base64encode
local base64urlencode = crypt.base64urlencode

local type = type
local assert = assert
local find = string.find
local concat = table.concat

local http = {}
--[[
	httpd 的 before函数本身仅根据状态码来确定具体Action
	如果使用者在函数内直接写入状态码, 请确保您非常清楚before函数的实现.
--]]


-- 成功
function http.ok()
	return 200
end

-- http base authorization
function http.basic_authorization(username, password)
	return "Authorization", "Basic " .. base64encode(username .. ":" .. password)
end

-- Json Web Token
function http.jwt(secret, payload)
	local content = {nil, nil, nil}
	-- header
	content[#content + 1] = base64urlencode(json_encode{ alg = "HS256", typ = "JWT" })
	-- payload
	content[#content + 1] = base64urlencode(payload)
	-- signature
	content[#content + 1] = hmac_sha256(secret, concat(content, "."), true)
	-- result.
	return "Authorization", "Bearer " .. concat(content, ".")
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