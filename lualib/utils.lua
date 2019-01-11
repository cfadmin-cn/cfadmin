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

-- local co = require "internal.Co"
-- local tcp = require "internal.TCP"
-- local Timer = require "internal.Timer"
-- co.spwan(function ( ... )
--     while 1 do
--         local self = co.self()
--         local ti = Timer.timeout(0.1, function()
--             local co_count, task_count = co.count()
--             local tcp_count = tcp.count()
--             local time_count = Timer.count()
--             print("=======================")
--             print("co 数量为:", co_count)
--             print("tcp 数量为:", tcp_count)
--             print("task 数量为:", task_count)
--             print("timer 数量为:", time_count)
--             print("当前内存为:", collectgarbage('count'))
--             print("=======================")
--             co.wakeup(self)
--         end)
--         co.wait()
--     end
-- end)