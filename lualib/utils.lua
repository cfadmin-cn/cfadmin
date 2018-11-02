function dump (obj)
	local getIndent, quoteStr, wrapKey, wrapVal, isArray, dumpObj
	getIndent = function (level)
		return string.rep("\t", level)
	end
	quoteStr = function(str)
		str = string.gsub(str, "[%c\\\"]", {
			["\t"] = "\\t",
			["\r"] = "\\r",
			["\n"] = "\\n",
			["\""] = "\\\"",
			["\\"] = "\\\\",
		})
		return '"' .. str .. '"'
	end
	wrapKey = function (val)
		if type(val) == "number" then
			return "[" .. val .. "]"
		elseif type(val) == "string" then
			return "[" .. quoteStr(val) .. "]"
		else
			return "[" .. tostring(val) .. "]"
		end
	end
	wrapVal = function (val, level)
		if type(val) == "table" then
			return dumpObj(val, level)
		elseif type(val) == "number" then
			return val
		elseif type(val) == "string" then
			return quoteStr(val)
		else
			return tostring(val)
		end
	end
	isArray = function (arr)
		local count = 0 
		for k, v in pairs(arr) do
			count = count + 1 
		end 
		for i = 1, count do
			if arr[i] == nil then
				return false
			end 
		end 
		return true, count
	end
	dumpObj = function (obj, level)
		if type(obj) ~= "table" then
			return wrapVal(obj)
		end
		level = level + 1
		local tokens = {}
		tokens[#tokens + 1] = "{"
		local ret, count = isArray(obj)
		if ret then
			for i = 1, count do
				tokens[#tokens + 1] = getIndent(level) .. wrapVal(obj[i], level) .. ","
			end
		else
			for k, v in pairs(obj) do
				tokens[#tokens + 1] = getIndent(level) .. wrapKey(k) .. " = " .. wrapVal(v, level) .. ","
			end
		end
		tokens[#tokens + 1] = getIndent(level - 1) .. "}"
		return table.concat(tokens, "\n")
	end
	return dumpObj(obj, 0)
end

