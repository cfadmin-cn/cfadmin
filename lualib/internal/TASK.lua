local task = require "task"
local log  = require "log"

local co_new = coroutine.create
local co_start = coroutine.resume
local co_wakeup = coroutine.resume
local co_suspend = coroutine.yield
local co_self = coroutine.running

local cos = {}

local function f(func, ...)
	local ok, msg = pcall(func, ...)
	if not ok then
		log.error(msg)
	end
	cos[co_self()] = nil
	return 
end


local TASK = {}

-- 查找
function TASK.self(...)
	return co_self()
end

-- 让出
function TASK.Wait(...)
	return co_suspend()
end

-- 启动
function TASK.start(func, ...)
	if func and type(func) == "function" then
		local co = co_new(f)
		cos[co] = task.new()
		return task.start(cos[co], co, func, ...)
	end
end

-- 唤醒
function TASK.wakeup(co, ...)
	local t = cos[assert(co, "Attemp to Pass a nil value(co).")]
	if not t then
		return log.error("Sorry, Can't find task from co list.")
	end
	return task.start(t, co, ...)
end

return TASK