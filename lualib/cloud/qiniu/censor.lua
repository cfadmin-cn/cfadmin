local token = require "cloud.qiniu.token"
local httpc = require "httpc"
local json = require "json"

local Censor = { __Version__ = 0.1, host = "ai.qiniuapi.com" }

--[[
  内容审核: image 图片审核, video 视频审核
]]

-- 图片内容审核
function Censor.newImageCensor (AccessKey, SecretKey, image_uri, params)
  local path = "/v3/image/censor"
  local body = json.encode({ data = { uri = image_uri or "" }, params = params or { scenes = {"pulp", "terror", "politician"} , detail = true } })
  local Authorization = token.newAuthorization(AccessKey, SecretKey, { method = "POST", path = path, host = Censor.host, body = body})
  return httpc.json("https://" .. Censor.host .. path, { {"Authorization", Authorization} }, body)
end

-- 视频内容审核
function Censor.newVideoCensor (AccessKey, SecretKey, video_uri, params)
  local path = "/v3/video/censor"
  local body = json.encode({ data = { uri = video_uri or "" }, params = params or { scenes = {"pulp", "terror", "politician"} , cut_param = { interval_msecs = 5000 } } })
  local Authorization = token.newAuthorization(AccessKey, SecretKey, { method = "POST", path = path, host = Censor.host, body = body})
  return httpc.json("https://" .. Censor.host .. path, { {"Authorization", Authorization} }, body)
end

-- 根据job_id检查视频审核结果
function Censor.getVideoCensorResult (AccessKey, SecretKey, job_id)
  local path = "/v3/jobs/video/" .. job_id
  local Authorization = token.newAuthorization(AccessKey, SecretKey, { method = "GET", path = path, host = Censor.host })
  return httpc.get("https://" .. Censor.host .. path, { {"Authorization", Authorization} })
end

return Censor
