local url = require "url"
local urlencode = url.encode
local urldecode = url.decode

local sys = require "sys"
local new_tab = sys.new_tab

local type = type
local tonumber = tonumber

local string = string
local sub = string.sub
local find = string.find
local match = string.match
local splite = string.gmatch

local table = table
local insert = table.insert
-- require "utils"

local form = {
	FILE = 0,
	ARGS = 1,
}

function form.get_args (path)
	if type(path) ~= 'string' or path == '' then
		return
	end
	local s, e = find(path, '?'), #path
	if not s or e - s < 3 then
		return
	end
	return form.urlencode(sub(path, s + 1, e))
end

-- 将body解析为x-www-form-urlencoded
function form.urlencode(body)
	if type(body) ~= 'string' then
		return
	end
	local ARGS = {}
	for key, value in splite(body, "([^&]-)=([^&]+)") do
		local tname, keyname = match(urldecode(key), "(.+)%[(.+)%]$")
		if tname and keyname then
		  local t = ARGS[tname]
		  if not t then
		    t = new_tab(8, 8)
		    ARGS[tname] = t
		  end
		  t[tonumber(keyname) or keyname] = urldecode(value)
		else
		  ARGS[urldecode(key)] = urldecode(value)
		end
	end
	return ARGS
end

-- 将body解析为multipart-form
-- 目前支持2种格式:
-- 1 : [ {filename = filename1, file = file1 }, {filename = filename2, file = file2 } ]
-- 2 : [ [1] = {[1] = key1, [2] = value1}, [2] = {[1] = key2, [2] = value2} ]
function form.multipart(body, BOUNDARY)
	if type(body) ~= 'string' or type(BOUNDARY) ~= 'string' then
		return
	end
	local FILES = {}
	for name, file in splite(body, 'filename="([^"]*)"\r\n[^\r\n]-\r\n\r\n(.-)\r\n[%-]-'..BOUNDARY) do
		if file and file ~= '' then
			insert(FILES, {filename = name, file = file})
		end
	end
	local ARGS = {}
	for key, value in splite(body, 'name="([^"]*)"\r\n\r\n([^%-]-)\r\n[%-]-'..BOUNDARY) do
		if (key and key ~= '' ) and (value and value ~= '') then
			insert(ARGS, {key, value})
		end
	end
	return FILES, ARGS
end


return form
