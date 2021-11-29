local dataset = require "process.dataset"

local channel = require "process.channel"
local channel_send = channel.send

local lpack = require "pack"
local lpack_encode = lpack.encode

local session = require "process.session"
local session_getsid = session.getsid
local sessionid_wait = session.wait

local process = { isWorker = true, pid = dataset.get('pid') }

local mchan = nil

---comment 由框架完成进程初始化.
function process.init()
  -- 构建进程通信通道
  mchan = channel:new()
  mchan:connect('worker')
end

---comment 向`Master`进程发送消息(非阻塞)
function process.send(...)
  channel_send(mchan, lpack_encode(nil, ...))
end

---comment 向`Master`进程发送消息(会阻塞)
function process.call(...)
  local sessionid = session_getsid()
  channel_send(mchan, lpack_encode(sessionid, ...))
  return sessionid_wait(sessionid)
end

---comment 注册进程事件
---@param msg_type string   @事件类型: `message`
---@param func     function @回调函数: function(sessionid, ...)
function process.on(msg_type, func)
  -- 注册消息事件
  if msg_type == 'message' and type(func) == 'function' then
    mchan:setcb(func)
    return
  end
end

return process