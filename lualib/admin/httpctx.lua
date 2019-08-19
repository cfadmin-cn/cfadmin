local class = require "class"
local Cookie = require "admin.cookie"

local xml2lua = require "xml2lua"

local json = require "json"
local json_encode = json.encode
local json_decode = json.decode

local type = type
local split = string.sub
local find = string.find

local ctx = class("ctx")

function ctx:ctor (opt)
  self._content = opt.content
end

-- 获取请求path
function ctx:get_path ()
  return split(self._content.path, 1, (find(self._content.path, '?') or 0) - 1)
end

-- 获取原始path
function ctx:get_raw_path ()
  return self._content.path
end

-- 获取请求头部
function ctx:get_headers ()
  return self._content.headers
end

-- 获取请求方法
function ctx:get_method ()
  return self._content.method
end

-- 获取Cookie
function ctx:get_cookie (name)
  return Cookie.getCookie(name)
end

-- 获取上传的文件
function ctx:get_files ()
  return self._content.files
end

-- 获取请求参数表
function ctx:get_args ()
  local args = self._content.args
  if type(args) == 'table' then
    return args
  end
  local body = self._content.body
  if body then
    local xml = self._content.xml
    local json = self._content.json
    if xml then
      args = xml2lua.parser(body)
      if type(args) == 'table' then
        return args
      end
    end
    if json then
      args = json_decode(body)
      if type(args) == 'table' then
        return args
      end
    end
  end
end

return ctx
