local log  = require "logging"
local task = require "task"

local Log = log:new()

local type = type
local assert = assert
local error = error

local task_new = task.new
local task_stop = task.stop
local task_start = task.start

local co_new = coroutine.create
local co_start = coroutine.resume
local co_wait = coroutine.yield
local co_status = coroutine.status
local co_self = coroutine.running

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

local function task_push(task)
	return insert(TASK_POOL, task)
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

local function co_push(co)
	return insert(CO_POOL, co)
end

local function f()
	while 1 do
		local ok, msg = pcall(co_wait())
		if not ok then
			Log:ERROR(msg)
		end
		local co, main = co_self()
		if not main then
			task_push(cos[co])
			co_push(co)
			cos[co] = nil
		end
	end
end

local Co = {}

-- 创建协程
function Co.new(f)
	return co_new(f)
end

-- 查找
function Co.self()
	return co_self()
end

-- 让出
function Co.wait()
	local co = co_self()
	assert(cos[co] or co == main_co, "非cf创建的协程不能让出执行权")
	return co_wait()
end

-- 启动
function Co.spwan(func, ...)
	if func and type(func) == "function" then
		local co = co_pop(f)
		cos[co] = task_pop()
		return task_start(cos[co], co, func, ...)
	end
	error("Co Just Can Spwan a Coroutine to run in sometimes.")
end

-- 唤醒
function Co.wakeup(co, ...)
	assert(type(co) == 'thread', "试图传递一个非协程的类型的参数到wakeup内部.")
	local status = co_status(co)
	if co == co_self() then
		return Log:ERROR("不能唤醒当前正在执行的协程")
	end
	if main_co == co and status == "suspended" then
		return task_start(main_task, main_co, ...)
	end
	local t = cos[co]
	assert(t, "非cf创建的协程不能由cf来唤醒")
	return task_start(t, co, ...)
end

function Co.count()
	return #CO_POOL, #TASK_POOL
end

return Co
