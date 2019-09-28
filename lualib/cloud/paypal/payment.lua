local httpc = require "httpc"
local crypt = require "crypt"
local json = require "json"

--[[
  1. 申请token
  2. 创建订单
  3. 用户确认支付 / 取消支付
  4. 商家确认支付 / 取消支付
  5. 交易完成 / 取消
]]

local Payment = { __Version__ = 0.1 }

local function basic_auth(username, password)
  return "Basic " .. crypt.base64encode(username .. ":" .. password)
end

local function Bearer_auth (accesstoken)
  return "Bearer " .. accesstoken
end

-- 申请AccessToken
function Payment.getAccessToken (clientid, secret)
  return httpc.post("https://api.sandbox.paypal.com/v1/oauth2/token", {
    {"Accept", "application/json"}, {"Authorization", basic_auth(clientid, secret)}
  }, { {"grant_type", "client_credentials"} })
end

-- 创建账单
function Payment.createPayment (accesstoken, opt)
  return httpc.json("https://api.sandbox.paypal.com/v1/payments/payment", { {"Authorization", Bearer_auth(accesstoken)} }, json.encode({
    intent = opt.intent, payer = opt.payer,
    transactions = opt.transactions,
    not_to_payer = opt.not_to_payer,
    redirect_urls = opt.redirect_urls,
  }))
end

-- 确认支付
function Payment.confirmPayment (accesstoken, payment_id, payer_id)
  return httpc.json("https://api.sandbox.paypal.com/v1/payments/payment/".. payment_id .."/execute", { {"Authorization", Bearer_auth(accesstoken)} },
    json.encode({ payer_id = payer_id })
    )
end

-- 查询账单
function Payment.getPaymentDetails (accesstoken, order_id)
  return httpc.get("https://api.sandbox.paypal.com/v1/payments/payment/" .. order_id, { {"Authorization", Bearer_auth(accesstoken)} })
end

-- 批量查询账单
function Payment.getPaymentsDetails (accesstoken, opt)
  return httpc.get("https://api.sandbox.paypal.com/v1/payments/payment", { {"Authorization", Bearer_auth(accesstoken)} }, {
    {"count", opt.count or 10},                -- 分页数量
    {"start_index", opt.start_index or 1},     -- 第几页
    {"sort_by", opt.sort_by or "create_time"}, -- 排序字段,
    {"sort_order", opt.sort_order or "desc"},  -- 排序方式,
  })
end

return Payment
