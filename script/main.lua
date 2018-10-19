local timer = core_timer
local socket = core_socket

-- 测试100万定时器资源消耗 -- 
function million_timer( ... )
	local times = 1
	while times < 1000000 do
		local timeout = math.random()
		timer.timeout(timeout, function()
			-- print("timeout = ", timeout)
		end)
		times = times + 1
	end
end

socket.listen(8080, function (...)
	print "监听"
end)