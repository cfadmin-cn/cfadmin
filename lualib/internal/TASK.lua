-- 用于构建Task池
local task = require "task"

local task_new = task.new
local task_stop = task.stop
local task_start = task.start

local insert = table.insert
local remove = table.remove


local TASK = {}

local function new(func)
	if #TASK > 0 then
		return remove(TASK)
	end
	return task_new()
end

local function close(task)
	return insert(TASK, task)
end

return {
	new = new -- 创建Task
	close = close -- 回收Task
	stop = task_stop -- 停止Task
	start = task_start -- 启动Task
}