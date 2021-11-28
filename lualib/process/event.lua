local cf = require "cf"
local child = require "child"

local pids = {}

local pid_cb = nil

local co = coroutine.create(function ()
  while true do
    local pid, code = coroutine.yield()
    if pid_cb then
      cf.fork(pid_cb, pid, code)
    else
      print('exit', pid, pids[pid])
    end
  end
end)
coroutine.resume(co)

local event = {}

function event.init(pid_list)
  for _, pid in ipairs(pid_list) do
    pids[pid] = child.watch(pid, co)
  end
end

function event.setcb(func)
  pid_cb = func
end

return event