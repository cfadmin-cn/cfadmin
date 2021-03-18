local CRYPT = require "lcrypt"
local dhsecret = CRYPT.dhsecret
local dhexchange = CRYPT.dhexchange

local DH = {}

function DH.dhsecret (...)
  return dhsecret(...)
end

function DH.dhexchange (...)
  return dhexchange(...)
end

-- 初始化函数
return function (t)
  for k, v in pairs(DH) do
    t[k] = v
  end
  return DH
end