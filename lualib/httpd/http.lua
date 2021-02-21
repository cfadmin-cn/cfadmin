local type = type
local assert = assert
local find = string.find

---comment 可以用来控制`before`方法内的行为.
local HTTP = {}

---comment 允许`httpd.before`通过(passed)
function HTTP.ok()
	return 200
end

---comment 此方法可以让开发者在`httpd.before`函数内重定向.
---@param code integer @重定向的HTTP状态码(301,302,303,307,308)
---@param url string   @重定向的url(`https://cfadmin.cn` or `/api`)
---@return integer @此方法只可用在`httpd:bedore`方法内.
---@return string  @调用方法必须是`return http.redirect(code, url)`
function HTTP.redirect(code, url)
	assert(type(url) == 'string' and url ~= '' and (find(url, '^http[s]?://.+') or find(url, '^/.*')), 'Redirection must give a string type domain name ("http[s]://domain" or "/")')
	if type(code) == 'number' and (code == 301 or code == 302 or code == 303 or code == 307 or code == 308) then
		return code, url
	end
	return 302, url
end

---comment 此方法可以让开发者在`httpd.before`函数内抛出异常.
---@param code integer @`HTTP`异常状态码(`400`-`600`之间)
---@param body string  @异常的具体内容(optional)
---@return integer @此方法只可用在`httpd:bedore`方法内.
---@return string  @调用方法必须是`return http.throw(code, body)`
function HTTP.throw(code, body)
	assert(type(code) == 'number' and code >= 400 and code < 600, 'The specified error code must be within the range (400-600).')
	if type(body) == 'string' and body ~= '' then
		return code, body
	end
	return code
end

return HTTP