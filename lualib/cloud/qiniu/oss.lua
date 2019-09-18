local crypt = require "crypt"
local json = require "json"

local type = type

local os_time = os.time
local find = string.find
local toint = math.tointeger


local oss = { __Version__ = 0.1 }
--[[
此为七牛云对象存储服务的上传与下载Token生成库的原生lua实现.
此库实现了服务端根据指定算法生成临时上传/下载的授权Token后交由客户端上传文件, 服务端不负责具体业务.
具体使用方法请参考: https://developer.qiniu.com/kodo/manual/1644/security
]]

-- 检查url是否合法
local function check_domain (domain)
  if type(domain) == 'string' and find(domain, "http[s]?://([%w]+)") then
    return domain
  end
end

function oss.getUploadToken (AccessKey, SecretKey, roles)
  if type(AccessKey) ~= 'string' or AccessKey == '' then
    return nil, "invaild AccessKey."
  end
  if type(SecretKey) ~= 'string' or SecretKey == '' then
    return nil, "invaild SecretKey."
  end
  if type(roles) ~= 'table' or not next(roles) then
    return nil, "invaild roles."
  end
  if type(roles.bucket) ~= 'string' or roles.bucket == '' then
    return nil, "invaild roles.bucket."
  end
  local Policy = {
    scope = table.concat({roles.bucket, roles.prefix}, ':'),               -- 上传可自行是否加入上传前缀
    deadline = toint(roles.deadline) or os_time() + 180,                   -- 默认超时时间为3分钟
    callbackUrl = check_domain(roles.callbackurl),                         -- 回调地址
    callbackBody = check_domain(roles.callbackbody),                       -- 回调地址内容
    insertOnly = toint(roles.insertonly) == 1 and 1 or 0,                  -- 是否可以写入覆盖
    fsizeMin = toint(roles.fsizemin),                                      -- 限定上传文件大小最小值(单位Byte)
    fsizeLimit = toint(roles.fsizeLimit),                                  -- 限定上传文件大小最大值(单位Byte), 超过限制上传文件大小的最大值会返回 413 状态码.
    fileType = toint(roles.filetype) ~= 0 and 1 or 0,                      -- 文件存储类型(0 为普通存储,1 为低频存储) 默认为: 0
    mimeLimit = type(roles.mimeLimit) == 'string' and roles.mimeLimit or nil,  -- 限制文件类型
  }
  local encodedPutPolicy = crypt.base64encode(json.encode(Policy))
  return AccessKey .. ':' .. crypt.base64encode(crypt.hmac_sha1(SecretKey, encodedPutPolicy)) .. ':' .. encodedPutPolicy
end

function oss.getDownloadToken (AccessKey, SecretKey, opt)
  if type(AccessKey) ~= 'string' or AccessKey == '' then
    return nil, "invaild AccessKey."
  end
  if type(SecretKey) ~= 'string' or SecretKey == '' then
    return nil, "invaild SecretKey."
  end
  if type(opt) ~= 'table' or not opt.url or not toint(opt.expires) then
    return nil, "invaild roles."
  end
  return table.concat({ opt.url .. '?'..'e='.. opt.expires, 'token='.. AccessKey .. ':' .. crypt.base64encode(crypt.hmac_sha1(SecretKey, opt.url)) }, '&')
end

return oss
