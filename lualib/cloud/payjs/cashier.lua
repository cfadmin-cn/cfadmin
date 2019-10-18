local sign = require "cloud.payjs.sign"
local httpc = require "httpc"

local cashier = { __Version__ = 0.1, host = "https://payjs.cn/api/cashier" }

-- 收银台支付接口
function cashier.pay(mchid, key, opt)
  return httpc.post(cashier.host, nil, sign(mchid, key, opt))
end

return cashier