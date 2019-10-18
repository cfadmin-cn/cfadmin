local sign = require "cloud.payjs.sign"
local httpc = require "httpc"

local utils = {
  __Version__ = 0.1,
  info = "https://payjs.cn/api/info",
  bank = "https://payjs.cn/api/bank",
  openid = "https://payjs.cn/api/openid",
}

-- 查询商户信息
function utils.mch_info(mchid, key)
  return httpc.get(utils.info, nil, sign(mchid, key, {}))
end

-- 查询银行编码
function utils.bank_code(mchid, key, bank)
  return httpc.get(utils.bank, nil, sign(mchid, key, {bank = bank}))
end

-- 获取用户 OPENID
function utils.mch_openid(mchid, key, callback_url)
  return httpc.get(utils.openid, nil, sign(mchid, key, {callback_url = callback_url}))
end

return utils