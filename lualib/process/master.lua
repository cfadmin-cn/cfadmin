local event = require "process.event"

local dataset = require "process.dataset"

local channel = require "process.channel"
local channel_send = channel.send

local lpack = require "pack"
local lpack_encode = lpack.encode

local session = require "process.session"
local session_get_pid = session.get_pid

local type = type
local pairs = pairs
local assert = assert

local mchan, channels

local process = { isMaster = true, pid = dataset.get('pid') }

---comment 由框架完成进程初始化.
function process.init(pid_list)
  -- 注册进程状态回调
  event.init(pid_list)
  -- 构建进程通信通道
  mchan = channel:new()
  channels = mchan:connect('master')
  -- 禁止二次修改
  process.init = nil
end

---comment 向所有`Worker`进程广播消息
function process.broadcast(...)
  local data = lpack_encode(nil, ...)
  for _, chan in pairs(channels) do
    channel_send(chan, data)
  end
end

---comment 响应消息
---@param sessionid integer @响应`sessionid`的消息
function process.ret(sessionid, ...)
  channel_send(channels[session_get_pid(assert(sessionid, "Invalid `sessionid`"))], lpack_encode(sessionid, ...))
end

---comment 注册进程事件
---@param msg_type string @事件类型: `message`, `exit`
---@param func     function @回调函数: function(sessionid, ...)
function process.on(msg_type, func)
  -- 注册退出事件
  if msg_type == 'exit' and type(func) == 'function'  then
    event.setcb(func)
    return
  end
  -- 注册消息事件
  if msg_type == 'message' and type(func) == 'function' then
    for _, chan in pairs(channels) do
      chan:setcb(func)
    end
    return
  end
end

return process