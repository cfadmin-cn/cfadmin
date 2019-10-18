local token = require "cloud.qiniu.token"
local httpc = require "httpc"
local json = require "json"

local ocr = { __Version__ = 0.1, host = "ai.qiniuapi.com"}

-- 身份证识别
function ocr.idcard(AccessKey, SecretKey, uri)
  local path = "/v1/ocr/idcard"
  local body = json.encode { data = { uri = uri } }
  local Authorization = token.newAuthorization (AccessKey, SecretKey, { method = "POST", path = path, host = ocr.host, body = body })
  return httpc.json("http://ai.qiniuapi.com/v1/ocr/idcard", { {"Authorization", Authorization} }, body)
end

return ocr