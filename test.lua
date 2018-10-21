local timer = core_timer
local socket = core_socket
local co = coroutine

-- 测试100万定时器稳定性与资源消耗 -- 
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

-- 测试注册接受客户端的回调 --
local function listen(port, cb)
	local function cb(fd, addr, data)
		local fd, addr = fd, addr
		while 1 do
			print("接受到来自: [", fd, addr, "] 的链接")
			cb(fd, data)
			fd, addr = co.yield()
		end
	end
	socket.listen(8080, cb)
end

listen(8080, function (fd, data)
	print "我是回调函数"
	print(fd, data)
end)