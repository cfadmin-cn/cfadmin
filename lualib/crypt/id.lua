local CRYPT = require "lcrypt"
local uuid = CRYPT.uuid
local guid = CRYPT.guid

local sys = require "sys"
local now = sys.now
local hostname = sys.hostname

local modf = math.modf

local ID = {}

-- UUID v4实现
function ID.uuid()
  return uuid()
end

-- hash(主机名)-时间戳-微秒-(1~65535的随机数)
function ID.guid(host)
  local hi, lo = modf(now())
  return guid(host or hostname(), hi, lo * 1e4 // 1)
end

-- 初始化函数
return function (t)
  for k, v in pairs(ID) do
    t[k] = v
  end
  return ID
end