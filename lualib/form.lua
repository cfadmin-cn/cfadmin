local type = type
local string = string
local table = table
local splite = string.gmatch
local insert = table.insert
-- require "utils"

local form = {}

-- 将body解析为x-www-form-urlencoded
function form.urlencode(body)
	if type(body) ~= 'string' then
		return
	end
	local tab = {}
	for key, value in splite(body, "([^%?&]+)=([^%?&]+)") do
		tab[key] = value
	end
	return tab
end

-- 将body解析为file-upload
-- [ {filename = filename1, file = file1 }, {filename = filename2, file = file2 } ]
function form.file(body, BOUNDARY)
	if type(body) ~= 'string' or type(BOUNDARY) ~= 'string' then
		return
	end
	local FILES = {}
	for name, file in splite(body, 'name="([^"]-)"\r\n[^\r\n]-\r\n\r\n(.-)\r\n[%-]-'..BOUNDARY) do
		if file and file ~= '' then
			insert(FILES, {filename = name, file = file})
		end
	end
	if #FILES == 0 then
		return 
	end
	return FILES
end


return form