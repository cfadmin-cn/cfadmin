local cf = require "cf"
local cf_self = cf.self
local cf_wait = cf.wait
local cf_wakeup = cf.wakeup

local dataset = require "process.dataset"
local prefixid = dataset.get("pid")
local minid, maxid = prefixid << 32 | 1, prefixid << 32 | 4294967295
local sid = minid

local assert = assert
local mtype = math.type

local session_map = {}

local session = {}

---comment 获取`sessionid`
---@return integer @返回`sessionid`
function session.getsid()
  if minid == maxid then
    sid = minid
  end
  local sessionid = sid
  sid = sid + 1
  return sessionid
end

---comment 获取进程ID
---@param sessionid integer @会话`ID`
---@return integer @返回进程`ID`
function session.get_pid(sessionid)
  assert(mtype(sessionid) == 'integer', "Invalide `sessionid`")
  return (sessionid >> 32) & 0xFFFFFFFF
end

---comment 等待`sessionid`
---@param sessionid integer @会话`ID`
function session.wait(sessionid)
  assert(mtype(sessionid) == 'integer', "Invalide `sessionid`")
  session_map[sessionid] = cf_self()
  return cf_wait()
end

---comment 唤醒`sessionid`
---@param sessionid integer @会话`ID`
function session.wakeup(sessionid, ...)
  local co = session_map[sessionid]
  if co then
    session_map[sessionid] = nil
    cf_wakeup(co, ...)
    return true
  end
  return false
end

return session