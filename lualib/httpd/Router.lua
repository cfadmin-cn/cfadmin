local log = require "logging"
local Log = log:new({dump = true, path = 'httpd-Router'})

local new_tab = require("sys").new_tab

local math = math
local string = string
local split = string.sub
local find = string.find
local match = string.match
local splite = string.gmatch
local spliter = string.gsub

local type = type
local next = next
local assert = assert
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local io_open = io.open
local concat = table.concat
local toint = math.tointeger

local Router = {
	API = 1,
	USE = 2,
	STATIC = 3,
	WS = 4,
}

local routes = {} -- 存储路由

local static = {} -- 静态文件路由

local typ = {
	int = toint,
	float = tonumber,
	string = tostring,
}

-- 分割路径后进行hex, 得到key后一次查表即可完成
local function hex_route(route)
	local tab = new_tab(32, 0)
	for r in splite(route, '/([^/%?]+)') do
		tab[#tab + 1] = r
	end
	return tab
end

-- 检查是路径回退是否超出静态文件根目录
local function check_path_deep (paths)
	-- 判断是否/..
	local head = paths[1]
	if head == '..' then
		return true
	end
	-- 判断是否/./..
	local second = paths[2]
	if second == '..' and head == '.' then
		return true
	end
	-- 结尾是特殊文件[夹]直接返回.
	local tail = paths[#paths]
	if tail == '.' or tail == '..' then
		return true
	end
	local deep = 1
	for index, path in ipairs(paths) do
		if path == '..'  then
			deep = deep - 1
		elseif path == '.' then
			deep = deep + 0
		else
			deep = deep + 1
		end
		if deep <= 0 then
			return true
		end
	end
	return false
end

local function registery_static (prefix, route_type)
	if not next(static) then
		static.prefix = prefix
		static.type = route_type
	end
	return
end

local load_file

local function registery_router (route, class, route_type)
	routes[concat(hex_route(route))] = {class = class, type = route_type}
end

local function find_route (path)
	local tab = hex_route(split(path, 1, (find(path, '?') or 0) - 1))
	local hex = concat(tab)
	local t = routes[hex]
	if t then
		return t.class, t.type
	end
	local prefix, type = static.prefix, static.type
	if not prefix and not type then
		return
	end
	-- 凡是找到'../'并且检查路径回退已经超出静态文件根目录返回404
	if find(path, '%.%./') and check_path_deep(tab) then
		return
	end
	load_file = load_file or function (path)
		local f, error = io_open(prefix..path, 'rb')
		if not f then
			return
		end
		local file = f:read('*a')
		f:close()
		return file, match(path, '.+%.([%a]+)')
	end
	return load_file, type
end

-- 查找路由
function Router.find(path)
	-- 凡是不以'/'开头的path都返回404
	if not find(path, '^(/)') then
		return
	end
	return find_route(path)
end

-- 注册静态文件查找路径
function Router.static (...)
	return registery_static(...)
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
