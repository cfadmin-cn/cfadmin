local log = require "log"
local class = require "class"
local co = require "internal.Co"
local task = require "internal.Task"

local co_new = co.new
local co_close = co.close

local task_new = task.new
local task_stop = task.stop
local task_start = task.start
local task_close = task.close

-- TASK 状态
local WAITING = 0
local RUNNING = 1

local function f()
	while 1 do 
		local ok, msg = pcall(co_wait())
		if not ok then
			log.error(msg)
		end
	end
end

local TASK = class("TASK")

function TASK:ctor(opt)
	self.co = co_new(f)
	self.task = task_new()
	self.status = WAITING
end

-- 启动一个任务
function TASK:start(func, ...)
	self.status = RUNNING
	return task_start(func, ...)
end

-- 停止一个任务
function TASK:stop()
	if self.status == RUNNING then
		return task_stop(self.task)
	end
end

-- 被动放置协程/task池
function TASK.__gc()
	co_close(self.co)
	task_close(self.task)
	self.co = nil
	self.task = nil
end

return {TASK = TASK}