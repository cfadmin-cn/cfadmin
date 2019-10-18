local sign = require "cloud.payjs.sign"
local httpc = require "httpc"

local micro = { __Version__ = 0.1, host = "https://payjs.cn/api/micropay" }

-- 付款码支付接口
function micro.pay(mchid, key, opt)
  return httpc.post(micro.host, nil, sign(mchid, key, opt))
end

return micro