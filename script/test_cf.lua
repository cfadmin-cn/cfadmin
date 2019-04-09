local cf = require "cf"

cf.fork(function()
	local co = cf.self()
	print("fork", "我现在睡眠了")
	cf.fork(function()
		return cf.wakeup(co)
	end)
	cf.wait()
	print("fork", "我现在被唤醒了")
end)

local times, timer = 0
timer = cf.at(1, function()
	if times >= 3 then
		print("循环定时器运行次数到了.")
		return timer:stop()
	end
	times = times + 1
	print("定时器运行次数:", times)
end)

local timer = cf.timeout(1, function()
	print("一次性定时器运行.")
end)

-- 想不执行timeout就取消下面的注释
-- timer:stop()

cf.wait()
