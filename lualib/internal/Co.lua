-- local task = require "task"
-- local new_tab = require("sys").new_tab

-- local task_new = task.new
-- local task_stop = task.stop
-- local task_start = task.start

-- local co_new = coroutine.create
-- local co_start = coroutine.resume
-- local co_wait = coroutine.yield
-- local co_status = coroutine.status
-- local co_self = coroutine.running

-- local type = type
-- local assert = assert
-- local xpcall = xpcall
-- local error = error

-- local insert = table.insert
-- local remove = table.remove

-- local cos = new_tab(0, 1 << 10)

-- local main_co = co_self()
-- local main_task = task_new()

-- local TASK_POOL = new_tab(1 << 10, 0)

-- local function task_pop()
-- 	return remove(TASK_POOL) or task_new()
-- end

-- local function task_push(task)
-- 	return insert(TASK_POOL, task)
-- end

-- local CO_POOL = new_tab(1 << 10, 0)

-- local function co_pop(func)
-- 	local co = remove(CO_POOL)
-- 	if co then
-- 		return co
-- 	end
-- 	co = co_new(func)
-- 	co_start(co)
-- 	return co
-- end

-- local function co_push(co)
-- 	return insert(CO_POOL, co)
-- end

-- local function dbg (info)
-- 	return print(string.format("[%s] %s", os.date("%Y/%m/%d %H:%M:%S"), debug.traceback(co_self(), info, 2)))
-- end

-- local function f()
-- 	while 1 do
-- 		local func, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = co_wait()
-- 		xpcall(func, dbg, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
-- 		local co, main = co_self()
-- 		if not main then
-- 			task_push(cos[co])
-- 			co_push(co)
-- 			cos[co] = nil
-- 		end
-- 	end
-- end

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
-- 	local co = co_self()
-- 	assert(cos[co] or co == main_co, "非cf创建的协程不能让出执行权")
-- 	return co_wait()
-- end

-- -- 启动
-- function Co.spawn(func, ...)
-- 	if type(func) == "function" then
-- 		local co = co_pop(f)
-- 		cos[co] = task_pop()
-- 		return task_start(cos[co], co, func, ...)
-- 	end
-- 	error("Co Just Can spawn a Coroutine to run in sometimes.")
-- end

-- -- 唤醒
-- function Co.wakeup(co, ...)
-- 	assert(type(co) == 'thread', "试图传递一个非协程的类型的参数到wakeup内部.")
-- 	assert(co ~= co_self(), "不能唤醒当前正在执行的协程")
-- 	if main_co == co then
-- 		local status = co_status(co)
-- 		if status ~= 'suspended' then
-- 			return error('试图唤醒一个状态异常的协程')
-- 		end
-- 		return task_start(main_task, main_co, ...)
-- 	end
-- 	local t = assert(cos[co], "非cf创建的协程不能由cf来唤醒")
-- 	return task_start(t, co, ...)
-- end

-- function Co.count()
-- 	return #CO_POOL, #TASK_POOL
-- end

-- return Co


local require = require
local task = require "task"
local task_new = task.new
local task_start = task.start

local sys = require "sys"
local new_tab = sys.new_tab

local type = type
local print = print
local ipairs = ipairs
local assert = assert
local select = select

local os_date = os.date
local fmt = string.format
local dbg_traceback = debug.traceback

local tpack = table.pack
local tunpack = table.unpack

local coroutine = coroutine
local co_new = coroutine.create
local co_start = coroutine.resume
local co_wait = coroutine.yield
local co_status = coroutine.status
local co_self = coroutine.running
local co_close = coroutine.close

local main_co = nil
local main_task = nil
local empty_args = {}

local co_num = 0

local co_map = new_tab(0, 1024)
co_map[co_self()] = true

local co_wlist = new_tab(512, 0)

local function co_wrapper()
  return co_new(function ()
    local co_rlist = co_wlist
    co_wlist = new_tab(512, 0)
    while true do
      for _, obj in ipairs(co_rlist) do
        local ok, errinfo = co_start(obj.co, tunpack(obj.args or empty_args))
        -- 如果协程`执行出错`或`执行完毕`, 则去掉引用销毁
        if not ok or co_status(obj.co) ~= 'suspended' then
          co_map[obj.co] = nil
          -- 如果发生异常，则应该把异常打印出来.
          if not ok then
            print(fmt("[%s] [coroutine error] %s", os_date("%Y/%m/%d %H:%M:%S"), dbg_traceback(obj.co, errinfo, 1)))
          end
          -- 如果支持销毁协程， 则可以尝试回收资源.
          if co_close then
            co_close(obj.co)
          end
          co_num = co_num - 1
        end
      end
      -- 如果没有执行对象则应该放弃执行权.
      -- 等待有任务之后再次唤醒后再执行
      if #co_wlist == 0 then
        co_wait()
      end
      co_rlist = co_wlist
      co_wlist = new_tab(512, 0)
    end
  end)
end

local function co_check_init()
  -- 如果尚未初始化资源, 则优先初始化.
  if not main_task and not main_co then
    main_task = task_new()
    main_co = co_wrapper()
  end
  -- 如果协程未启动, 则启动协程开始运行.
  if co_status(main_co) == 'suspended' then
    task_start(main_task, main_co)
  end
end

local function co_add_queue(co, ...)
  local len, args = select("#", ...), nil
  if len > 0 then
    args = tpack(...)
  end
  co_num = co_num + 1
  co_wlist[#co_wlist+1] = { co = co, args = args}
end

local Co = {}

-- 创建协程
function Co.new(f)
  return co_new(f)
end

-- 获取协程
function Co.self()
  return co_self()
end

-- 让出协程
function Co.wait()
  assert(co_map[co_self()], "[coroutine error]: This coroutine is not associated internally, so it cannot yield.")
  return co_wait()
end

-- 唤醒协程
function Co.wakeup(co, ...)
  assert(type(co) == 'thread' and co ~= co_self() and co_map[co], "[coroutine error]: Invcalid coroutine.")
  co_check_init()
  co_add_queue(co, ...)
end

-- 创建协程
function Co.spawn(func, ...)
  assert(type(func) == "function", "[coroutine error]: Invalid callback.")
  -- 创建协程与打包参数
  local co = co_new(func)
  co_map[co] = true
  co_check_init()
  co_add_queue(co, ...)
  return co
end

-- 计算数量
function Co.count()
  return co_num
end

return Co