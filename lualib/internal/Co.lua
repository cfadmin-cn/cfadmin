local task = require "task"
local log  = require "log"

local co_new = coroutine.create
local co_start = coroutine.resume
local co_wait = coroutine.yield
local co_self = coroutine.running

local cos = {}

local function f(func, ...)
	-- log.info("当前内存为:", collectgarbage('count'))
	local ok, msg = pcall(func, ...)
	if not ok then
		log.error(msg)
	end
	cos[co_self()] = nil
	return
end


local Co = {}

-- 创建协程
function Co.new(f)
	return co_new(f)
end

-- 启动
function Co.start(co, ...)
	return co_start(co, ...)
end

-- 查找
function Co.self()
	return co_self()
end

-- 让出
function Co.wait()
	return co_wait()
end

-- 启动
function Co.spwan(func, ...)
	if func and type(func) == "function" then
		local co = co_new(f)
		cos[co] = task.new()
		return task.start(cos[co], co, func, ...)
	end
	error("Co Just Can Spwan a Coroutine to run in sometimes.")
end

-- 唤醒
function Co.wakeup(co, ...)
	local t = cos[assert(co, "Attemp to Pass a nil value(co).")]
	if not t then
		return log.error("Sorry, Can't find task from co list.")
	end
	return task.start(t, co, ...)
end

return Co