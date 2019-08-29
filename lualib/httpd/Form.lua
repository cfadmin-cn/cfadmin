local url = require "url"
local urlencode = url.encode
local urldecode = url.decode

local type = type

local string = string
local sub = string.sub
local find = string.find
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
	for key, value in splite(body, "([^%?&]-)=([^%?&]+)") do
		ARGS[urldecode(key)] = urldecode(value)
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
	if #FILES > 0 then
		-- return form.FILE, FILE
		return 0, FILES
	end
	local ARGS = {}
	for key, value in splite(body, 'name="([^"]*)"\r\n\r\n([^%-]-)\r\n[%-]-'..BOUNDARY) do
		if (key and key ~= '' ) and (value and value ~= '') then
			insert(ARGS, {key, value})
		end
	end
	if #ARGS > 0 then
		-- return form.ARGS, ARGS
		return 1, ARGS
	end
	return
end


return form
