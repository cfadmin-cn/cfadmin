-- 用于构建协程池

local coroutine = coroutine
local co_new = coroutine.create
local co_start = coroutine.resume
local co_wait = coroutine.yield
local co_status = coroutine.status
local co_self = coroutine.running

local insert = table.insert
local remove = table.remove

local Co = {}

local function co_pop(func)
	if #Co > 0 then
		return remove(Co)
	end
	local co = co_new(func)
	co_start(co)
	return co
end

local function co_push(co)
	Co[#Co + 1] = co
end

local function new(func)
	return co_pop(func)
end

local function close(co)
	return co_push(co)
end

return {
	new = new,
	close = close,
	self = co_self,
	wait = co_wait,
	wakeup = co_start,
	status = co_status,
}