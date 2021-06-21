local require = require
local task = require "task"
local task_new = task.new
local task_start = task.start

local sys = require "sys"
local new_tab = sys.new_tab

local type = type
local print = print
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
local main_waited = true

local co_num = 0

local co_map = new_tab(0, 1024)
co_map[co_self()] = true

local co_wlist = new_tab(512, 0)

local function co_wrapper()
  return co_new(function ()
    -- 使用`数字索引`比`Hash索引`更快.
    local CO_INDEX, ARGS_INDEX = 1, 2
    -- 使用数字下标迭代比`ipairs`更快.
    local start, total = 1, #co_wlist
    -- 使用两级`FIFO`队列交替管理协程的运行与切换, 并且每次预分配的`FIFO`队列的大小与上次执行的协程的数量相关.
    local co_rlist = co_wlist
    co_wlist = new_tab((total & ~3) + 4, 0)
    while true do
      for index = start, total do
        local obj = co_rlist[index]
        local co, args = obj[CO_INDEX], obj[ARGS_INDEX]
        local ok, errinfo; if args then ok, errinfo = co_start(co, tunpack(args)); else ok, errinfo = co_start(co); end
        -- 如果协程`执行出错`或`执行完毕`, 则去掉引用销毁
        if not ok or co_status(co) ~= 'suspended' then
          -- 如果发生异常，则应该把异常打印出来.
          if not ok then
            print(fmt("[%s] [coroutine error] %s", os_date("%Y/%m/%d %H:%M:%S"), dbg_traceback(co, errinfo, 1)))
          end
          -- 如果支持销毁协程， 则可以尝试回收资源.
          if co_close then
            co_close(co)
          end
          co_map[co] = nil
          co_num = co_num - 1
        end
      end
      -- 如果没有执行对象则应该放弃执行权.
      -- 等待有任务之后再次唤醒后再执行
      total = #co_wlist
      if total == 0 then
        main_waited = true
        co_wait()
        total = #co_wlist
      end
      co_rlist = co_wlist
      co_wlist = new_tab((total & ~3) + 4, 0)
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
  if main_waited then
    main_waited = false
    task_start(main_task, main_co)
  end
end

local function co_add_queue(co, ...)
  local args = nil
  if select("#", ...) > 0 then
    args = tpack(...)
  end
  co_wlist[#co_wlist+1] = {co, args}
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
  assert(type(func) == 'function', "[coroutine error]: Invalid callback.")
  -- 创建协程与打包参数
  co_num = co_num + 1
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