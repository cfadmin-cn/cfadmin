local json = require "json"
local crypt = require "crypt"
local hmac_sha1 = crypt.hmac_sha1
local urlencode = crypt.urlencode
local base64encode = crypt.base64encode

local type = type
local next = next
local ipairs = ipairs
local os_time = os.time
local find = string.find
local toint = math.tointeger
local concat = table.concat

local function build_sign (path, args, body)
  local req = path
  if type(args) == 'table' then
    local query = {}
    for _, item in ipairs(args) do
      query[#query+1] = urlencode(item[1]) .. '=' .. urlencode(item[2])
    end
    if #query > 0 then
      req = req .. '?' .. concat(query, "&")
    end
  end
  return req .. '\n' .. (type(body) == 'string' and body or '')
end

local Token = { __Version__ = 0.1 }

-- 检查url是否合法
local function check_domain (domain)
  if type(domain) == 'string' and find(domain, "http[s]?://([%w]+)") then
    return domain
  end
end

-- 管理凭证
--[[
  opt.path : 请求路径(必填)
  opt.args : 请求参数(选填)
  opt.body : 请求体内容(选填)
]]
function Token.getAccessToken (AccessKey, SecretKey, opt)
  if type(AccessKey) ~= 'string' or AccessKey == '' then
    return nil, "invaild AccessKey."
  end
  if type(SecretKey) ~= 'string' or SecretKey == '' then
    return nil, "invaild SecretKey."
  end
  if type(opt) ~= 'table' or not next(opt) then
    return nil, "invaild opt."
  end
  local sign_str = build_sign(opt.path, opt.args, opt.body)
  local hash_sign = hmac_sha1(SecretKey, sign_str)
  local Authorization = AccessKey .. ':' .. base64encode(hash_sign)
  return Authorization, "QBox " .. Authorization
end

-- Auth凭证
function Token.newAuthorization (AccessKey, SecretKey, opt)
  local auth = opt.method .. ' ' .. opt.path
  if opt.query then
    auth = auth .. opt.query
  end
  auth = auth .. '\nHost: ' .. opt.host
  if opt.body then
    auth = auth .. '\nContent-Type: application/json\n\n' .. opt.body
  else
    auth = auth .. '\n\n'
  end
  return 'Qiniu'.. ' ' .. AccessKey .. ':' .. crypt.base64encode(crypt.hmac_sha1(SecretKey, auth))
end

-- 上传凭证
function Token.getUploadToken (AccessKey, SecretKey, roles)
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
    scope = concat({roles.bucket, roles.prefix}, ':'),                     -- 上传可自行是否加入上传前缀
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

-- 下载凭证
function Token.getDownloadToken (AccessKey, SecretKey, opt)
  if type(AccessKey) ~= 'string' or AccessKey == '' then
    return nil, "invaild AccessKey."
  end
  if type(SecretKey) ~= 'string' or SecretKey == '' then
    return nil, "invaild SecretKey."
  end
  if type(opt) ~= 'table' or not opt.url or not toint(opt.expires) then
    return nil, "invaild roles."
  end
  return concat({ opt.url .. '?'..'e='.. opt.expires, 'token='.. AccessKey .. ':' .. crypt.base64encode(crypt.hmac_sha1(SecretKey, opt.url)) }, '&')
end

return Token
