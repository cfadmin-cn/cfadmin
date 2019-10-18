local sign = require "cloud.payjs.sign"
local httpc = require "httpc"

local native = { __Version__ = 0.1, host = "https://payjs.cn/api/native" }

-- 扫码支付接口
function native.pay(mchid, key, opt)
  return httpc.post(native.host, nil, sign(mchid, key, opt))
end

return native