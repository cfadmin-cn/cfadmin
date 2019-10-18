local sign = require "cloud.payjs.sign"
local httpc = require "httpc"

local face = { __Version__ = 0.1, host = "https://payjs.cn/api/facepay" }

-- 人脸支付接口
function face.pay(mchid, key, opt)
  return httpc.post(face.host, nil, sign(mchid, key, opt))
end

return face