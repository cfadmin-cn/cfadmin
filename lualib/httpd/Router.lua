local LOG = require "logging":new({dump = true, path = 'httpd-Router'})

local aio = require "aio"
local aio_stat = aio.stat

local url = require "url"
local url_decode = url.decode
-- local url_encode = url.encode

local new_tab = require("sys").new_tab

local string = string
local byte = string.byte
local split = string.sub
local find = string.find
local match = string.match
local splite = string.gmatch
local spliter = string.gsub

local type = type
local next = next
local pairs = pairs
local error = error
local ipairs = ipairs
local tonumber = tonumber

local slash = '\x2f'        -- '/'
local slash2 = '\x2f\x2f'   -- '//'
local point = '\x2e'        -- '.'
local point2 = '\x2e\x2e'   -- '..'

local class = require "class"

local Router = class("httpd-route")

Router.API, Router.USE, Router.STATIC, Router.WS = 1, 2, 3, 4

function Router:ctor (opt)
  self.rests = {}  -- rest路由
  self.routes = {} -- 普通路由
  self.statics = {} -- 静态文件路由
  self.enable_rest = false -- 默认关闭rest路由支持
end

function Router:enable_rest_route ()
  self.enable_rest = true
end

function Router:tonumber (v)
  return tonumber(v)
end

function Router:toarray (v, t)
  if type(v) ~= 'string' or #v < 3 then
    return v
  end
  local array = new_tab(32, 0)
  for str in splite(v, "[^,%[%]%{%}]+") do
    if not t or t == 'string[]' then
      array[#array+1] = str
    else
      array[#array+1] = tonumber(str) or tonumber(str:gsub("^0x", ""), 16)
    end
  end
  return array
end

-- 将rest路由转换匹配模式语法
function Router:to_regex (r)
  if type(r) ~= 'string' or not find(r, "[{}]") then
    return
  end
  local regex = r
    :gsub("%+", "%%+")
    :gsub("%-", "%%-")
    :gsub("%.", "%%.")
    :gsub("%*", "%%*")
    :gsub("[/]+", "/")
    :gsub("/", "[/]-")
  local args = {}
  for p in splite(r, "%{([^/]-)%}") do
    local t, v = match(p, "([^:{}]+):([^:{}]+)")
    if t ~= 'string' and t ~= 'number' and t ~= 'string[]' and t ~= 'number[]' then
      local name = match(p, "([^}{]+)")
      if not name then
        error("Invalid rest router syntex in [" .. r .. "], type is not support.")
      end
      t, v = "string", name
    end
    local reg = "([^/]+)"
    if t == 'number' then
      reg = "([%%d]+[%%.]?[%%d]-)"
    end
    regex = spliter(regex,  "{" .. spliter(t, "%[%]", "%%[%%]") .. ":" .. v .. "}", reg)
    regex = spliter(regex, "{" .. v .. "}", reg)
    args[#args+1] = { k = v, t = t }
  end
  if byte(r, #r) == byte("/") then
    regex = regex .. "$"
  else
    regex = regex .. "[/]-$"
  end
  args["route"] = r
  args["regex"] = "^" .. regex
  -- LOG:DEBUG(args)
  return regex, args
end

function Router:match_regex (route, regex)
  return match(route, regex)
end

function Router:to_route (route)
  local r = spliter(route, "([/]+)", '/')
  if byte(r, #r) ~= byte(slash) then
    return r
  end
  return split(r, 1, -2)
end

function Router:hex_route (route)
  local tab = new_tab(32, 0)
	for r in splite(route, '/([^ /%?]+)') do
    if r ~= '' then
		  tab[#tab + 1] = r
    end
	end
	return tab
end

-- 检查是路径回退是否超出静态文件根目录(是否合法路径.)
function Router:is_out_of_directory (path)
  local deep = 1
  for r in splite(path, "/([^/#%?]+)") do
    if r == point2 then
      deep = deep - 1
    elseif r ~= point then
      deep = deep + 1
    end
    if deep == 0 then
      return true
    end
  end
  return false
end

-- 路由查找
function Router:find (method, path)
  -- 检查是否能O(1)定位普通路由
  path = url_decode(split(path, 1, (find(path, '?') or 0) - 1))
	local r = self.routes[self:to_route(path)]
  if r then
    return r.class, r.type
  end
  -- 检查是否需要查找rest路由
  if self.enable_rest then
		for regex, cls in pairs(self.rests) do
			local args_list = table.pack(self:match_regex(path, regex))
			if args_list and #args_list == #cls then
				local args = new_tab(8, 0)
				for index, arg in ipairs(args_list) do
					local item = cls[index]
          local t = item.t
					local k = item.k
					if t == 'number' then
						args[k] = self:tonumber(arg)
					elseif t == 'number[]' or t == 'string[]' then
            args[k] = self:toarray(arg, t)
          else
            args[k] = arg
          end
				end
				return cls.class, cls.type, args
			end
		end
	end
  -- 查找静态文件路由(文件)
  local prefix, typ = self.statics.prefix, self.statics.type
  -- LOG:DEBUG(prefix, typ)
	if not prefix and not typ then
    return
  end
  -- 非GET/HEAD方法不查找静态文件
  if method ~= 'GET' and method ~= 'HEAD' then
    return
  end
  -- 凡是超出静态文件根目录返回404.
  if self:is_out_of_directory(path) then
    return
  end
  -- 构建静态静态文件检查器
  if not self.load_file then
    self.load_file = function ( path )
      local filepath = prefix .. url_decode(path)
      local stat = aio_stat(filepath)
      if type(stat) ~= 'table' or stat.mode ~= 'file' then
        return
      end
      return stat.size, filepath, match(filepath, '[%.]?([^%./]+)$')
    end
  end
  return self.load_file, typ
end

-- 注册rest语法路由与普通路由
function Router:registery (route, class, route_type)
  -- 过滤错误的路由输入
  if type(route) ~= 'string' or route == '' then
		return LOG:WARN('Please Do not add empty string in route registery method :)')
	end
	if find(route, slash2) then -- 不允许出现路由出现[//]
		return LOG:WARN('Please Do not add [//] in route registery method :)')
	end
  local regex, args = self:to_regex(route)
	if regex and args then
		self.rests[regex], args["class"], args["type"] = args, class, route_type
	end
  self.routes[self:to_route(route)] = {class = class, type = route_type}
end

-- 注册静态文件路由
function Router:static (route_prefix, route_type)
  if next(self.statics) then
    return
  end
  self.statics.prefix, self.statics.type = route_prefix, route_type
end

return Router
