local log = require "logging"
local Log = log:new({dump = true, path = 'httpd-Router'})

local math = math
local string = string
local find = string.find
local match = string.match
local splite = string.gmatch

local type = type
local assert = assert
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local toint = math.tointeger

local Router = {
	API = 1,
	USE = 2,
	STATIC = 3,
	WS = 4,
}

local routes = {} -- 存储路由

local typ = {
	int = toint,
	float = tonumber,
	string = tostring,
}

-- 路由分割: /a/b/c/d = {'a', 'b', 'c', 'd'}
local function splite_route(route)
	local tab = {}
	for r in splite(route, '/([^/?]+)') do
		tab[#tab + 1] = r
	end
	return tab
end

local function registery_router(route, class, route_type)
	local tab = splite_route(route)
	if route == '/' then -- 如果注册路由为'/', 则转义为:''
		tab = {''}
	end
	for index, r in ipairs(tab) do
		if not routes[index] then
			routes[index] = {}
		end
		if not routes[index][r] then
			routes[index][r] = true
		end
		if #tab == index then
			routes[index][r] = {class = class, type = route_type}
		end
	end
end

local function find_route(path)
	local tab = splite_route(path)
	if #tab == 0 then -- 如果路由为/[/]{0, n}, 则转义为: ''
		tab[1] = ''
	end
	for index, route in ipairs(routes) do
		local r = tab[index]
		if not r then
			return false
		end
		local t = route[r]
		if type(t) == 'table' then
			if #tab == index then
				return t.class, t.type
			end
			if t.type == Router.STATIC then
				return t.class, t.type
			end
		end
	end
end

-- 查找路由
function Router.find(path)
	return find_route(path)
end

-- 注册路由
function Router.registery(route, class, route_type)
	if type(route) ~= 'string' or route == '' then -- 过滤错误的路由输入
		return Log:WARN('Please Do not add empty string in route registery method :)')
	end
	if find(route, '//') then -- 不允许出现路由出现[//]
		return Log:WARN('Please Do not add [//] in route registery method :)')
	end
	if find(route, '^/%[%w+:.+%]$') then -- 不允许顶层路由注册rest模式.
		return Log:WARN('Please Do not add [/[type:key] in root route :)]')
	end
	return registery_router(route, class, route_type)
end

return Router
