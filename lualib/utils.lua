
-- 格式化输出(美化)
var_dump = function (data, showMetatable, lastCount)
    if type(data) ~= "table" then
        --Value
        if type(data) == "string" then
            io.write('"', data, '"')
        else
            io.write(tostring(data))
        end
    else
        --Format
        local count = lastCount or 0
        count = count + 1
        io.write("{\n")
        --Metatable
        if showMetatable then
            for i = 1,count do io.write("      ") end
            local mt = getmetatable(data)
            io.write("\"__metatable\" = ")
            var_dump(mt, showMetatable, count)    -- 如果不想看到元表的元表，可将showMetatable处填nil
            io.write(",\n")     				     --如果不想在元表后加逗号，可以删除这里的逗号
        end
        --Key
        for key,value in pairs(data) do
            for i = 1,count do io.write("      ") end
            if type(key) == "string" then
                -- io.write("\"", key, "\" = ")
				io.write('["', key, '"] = ')
            elseif type(key) == "number" then
                io.write("[", key, "] = ")
            else
                io.write(tostring(key))
            end
            var_dump(value, showMetatable, count) -- 如果不想看到子table的元表，可将showMetatable处填nil
            io.write(",\n")     					 --如果不想在table的每一个item后加逗号，可以删除这里的逗号
        end
        --Format
        for i = 1, lastCount or 0 do io.write("      ") end
        io.write("}")
    end
    --Format
    if not lastCount then
        io.write("\n")
    end
end

-- 最好不要使用原生pcall
-- 可能导致无法查看完整的出错调用栈
pcall = function(func, ...)
	local function trace(e)
		return debug.traceback(0) .. e
	end
	return xpcall(func, trace, ...)
end
