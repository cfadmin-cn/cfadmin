local sign = require "cloud.payjs.sign"
local httpc = require "httpc"

local order = {
  __Version__ = 0.1,
  check = "https://payjs.cn/api/check",
  close = "https://payjs.cn/api/close",
  reverse = "https://payjs.cn/api/reverse",
  refund = "https://payjs.cn/api/refund",
}

-- 订单查询
function order.order_check(mchid, key, payjs_order_id)
  return httpc.get(order.check, nil, sign(mchid, key, {payjs_order_id = payjs_order_id}))
end

-- 订单关闭
function order.order_close(mchid, key, payjs_order_id)
  return httpc.post(order.close, nil, sign(mchid, key, {payjs_order_id = payjs_order_id}))
end

-- 订单撤销
function order.order_reverse(mchid, key, payjs_order_id)
  return httpc.post(order.reverse, nil, sign(mchid, key, {payjs_order_id = payjs_order_id}))
end

-- 退款
function order.order_refund(mchid, key, payjs_order_id)
  return httpc.post(order.refund, nil, sign(mchid, key, {payjs_order_id = payjs_order_id}))
end

return order