local task = require "task"
local new_tab = require("sys").new_tab

local task_new = task.new
local task_stop = task.stop
local task_start = task.start

local co_new = coroutine.create
local co_start = coroutine.resume
local co_wait = coroutine.yield
local co_status = coroutine.status
local co_self = coroutine.running

local type = type
local assert = assert
local xpcall = xpcall
local error = error

local insert = table.insert
local remove = table.remove

local cos = new_tab(0, 1 << 10)

local main_co = co_self()
local main_task = task_new()

local TASK_POOL = new_tab(1 << 10, 0)

local function task_pop()
	if #TASK_POOL > 0 then
		return remove(TASK_POOL)
	end
	return task_new()
end

local function task_push(task)
	return insert(TASK_POOL, task)
end

local CO_POOL = new_tab(1 << 10, 0)

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

local function dbg (info)
	return print(string.format("[%s] %s", os.date("%Y/%m/%d %H:%M:%S"), debug.traceback(co_self(), info, 2)))
end

local function f()
	while 1 do
		local f, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = co_wait()
		xpcall(f, dbg, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
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
function Co.spawn(func, ...)
	if type(func) == "function" then
		local co = co_pop(f)
		cos[co] = task_pop()
		return task_start(cos[co], co, func, ...)
	end
	error("Co Just Can spawn a Coroutine to run in sometimes.")
end

-- 唤醒
function Co.wakeup(co, ...)
	assert(type(co) == 'thread', "试图传递一个非协程的类型的参数到wakeup内部.")
	assert(co ~= co_self(), "不能唤醒当前正在执行的协程")
	if main_co == co then
		local status = co_status(co)
		if status ~= 'suspended' then
			return error('试图唤醒一个状态异常的协程')
		end
		return task_start(main_task, main_co, ...)
	end
	local t = assert(cos[co], "非cf创建的协程不能由cf来唤醒")
	return task_start(t, co, ...)
end

function Co.count()
	return #CO_POOL, #TASK_POOL
end

return Co
