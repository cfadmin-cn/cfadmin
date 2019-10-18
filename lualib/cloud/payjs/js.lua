local sign = require "cloud.payjs.sign"
local httpc = require "httpc"

local js = { __Version__ = 0.1, host = "https://payjs.cn/api/jsapi" }

-- JSAPI支付接口
function js.pay(mchid, key, opt)
  return httpc.post(js.host, nil, sign(mchid, key, opt))
end

return js