local class = require "class"
local task = require "task"

local task_new = task.new
local task_stop = task.stop
local task_start = task.start

local coroutine = coroutine
local co_new = coroutine.create
local co_start = coroutine.resume
local co_wait = coroutine.yield
local co_status = coroutine.status
local co_self = coroutine.running

-- TASK 状态
local T_STATUS = {
	WAIT     = 0,
	PENDDING = 1,
	RUNNING  = 2
}

local insert = table.insert
local remove = table.remove

local cos = {}


local main_co = co_self()
local main_task = task_new()

local TASK_POOL = {}

local function task_pop()
	if #TASK_POOL > 0 then
		return remove(TASK_POOL)
	end
	return task_new()
end

local function task_add(task)
	TASK_POOL[#TASK_POOL + 1] = task
end

local CO_POOL = {}

local function co_pop(func)
	if #CO_POOL > 0 then
		return remove(CO_POOL)
	end
	local co = co_new(func)
	co_start(co)
	return co
end

local function co_add(co)
	CO_POOL[#CO_POOL + 1] = co
end

local TASK = class("TASK")

function TASK:ctor(opt)
	self.co = opt.co or co_pop()
	self.task = opt.task or task_pop()
	self.status = T_STATUS.WAIT
end

-- 启动一个任务
function TASK:start(...)

end

-- 停止一个任务
function TASK:stop(...)

end

function TASK:close(...)
	if self.status ~= T_STATUS.WAIT then
		task_stop(self.task)
	end
end

-- local Co = {}

-- -- 创建协程
-- function Co.new(f)
-- 	return co_new(f)
-- end

-- -- 查找
-- function Co.self()
-- 	return co_self()
-- end

-- -- 让出
-- function Co.wait()
-- 	return co_wait()
-- end

-- -- 启动
-- function Co.spwan(func, ...)
-- 	if func and type(func) == "function" then
-- 		local co = co_pop(f)
-- 		cos[co] = task_pop()
-- 		return task_start(cos[co], co, func, ...)
-- 	end
-- 	error("Co Just Can Spwan a Coroutine to run in sometimes.")
-- end

-- -- 唤醒
-- function Co.wakeup(co, ...)
-- 	assert(co, "Attemp to Pass a nil value (need a co).")
-- 	local status = co_status(co)
-- 	if co == co_self() then
-- 		return log.error("Can't wakeup current co.")
-- 	end
-- 	if main_co == co and status == "suspended" then
-- 		return task_start(main_task, main_co, ...)
-- 	end
-- 	local t = cos[co]
-- 	if not t then
-- 		return log.error("Can't find co in co list.")
-- 	end
-- 	return task_start(t, co, ...)
-- end

-- function Co.count()
-- 	return #CO_POOL, #TASK_POOL
-- end

return TASK