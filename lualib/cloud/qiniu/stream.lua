local token = require "cloud.qiniu.token"
local httpc = require "httpc"
local json = require "json"

local crypt = require "crypt"
local hmac_sha1 = crypt.hmac_sha1
local urlencode = crypt.urlencode
local base64encode = crypt.base64encode

local type = type
local time = os.time
local concat = table.concat

local Stream = { __Version__ = 0.1, domain = "https://pili.qiniuapi.com" }

-- 创建流
function Stream.createStream (AccessKey, SecretKey, hub, key)
  if type(AccessKey) ~= 'string' or AccessKey == '' then
    return nil, "invaild AccessKey."
  end
  if type(SecretKey) ~= 'string' or SecretKey == '' then
    return nil, "invaild SecretKey."
  end
  if type(hub) ~= 'string' or hub == '' then
    return nil, "invaild hub."
  end
  if type(key) ~= 'string' or key == '' then
    return nil, "invaild key."
  end
  local path = "/v2/hubs/" .. hub .. "/streams"
  local Authorization, QboxAuthorization = token.getAccessToken(AccessKey, SecretKey, {path = path})
  return httpc.json(Stream.domain .. path, { {"Authorization", QboxAuthorization } }, json.encode({ {"key", key} }))
end

-- 查询流
function Stream.queryStream (AccessKey, SecretKey, hub, key)
  if type(AccessKey) ~= 'string' or AccessKey == '' then
    return nil, "invaild AccessKey."
  end
  if type(SecretKey) ~= 'string' or SecretKey == '' then
    return nil, "invaild SecretKey."
  end
  if type(hub) ~= 'string' or hub == '' then
    return nil, "invaild hub."
  end
  if type(key) ~= 'string' or key == '' then
    return nil, "invaild key."
  end
  local path = "/v2/hubs/" .. hub .. "/streams/" .. base64encode(key)
  local Authorization, QboxAuthorization = token.getAccessToken(AccessKey, SecretKey, { path = path })
  return httpc.get(Stream.domain.. path, { {"Authorization", QboxAuthorization}, {"Content-Type", "application/x-www-form-urlencoded"} })
end

-- 查询流列表
function Stream.queryStreams (AccessKey, SecretKey, hub, opt)
  if type(AccessKey) ~= 'string' or AccessKey == '' then
    return nil, "invaild AccessKey."
  end
  if type(SecretKey) ~= 'string' or SecretKey == '' then
    return nil, "invaild SecretKey."
  end
  if type(hub) ~= 'string' or hub == '' then
    return nil, "invaild hub."
  end
  local args, querys = {}
  if opt.liveonly then
    args[#args+1] = {"liveonly", "true"}
  end
  if opt.prefix then
    args[#args+1] = {"prefix", opt.prefix}
  end
  if opt.marker then
    args[#args+1] = {"marker", opt.marker}
  end
  if opt.limit then
    args[#args+1] = {"limit", opt.limit}
  end
  if #args > 1 then
    local query = {}
    for _, item in ipairs(args) do
      query[#query+1] = urlencode(item[1]) .. '=' .. urlencode(item[2])
    end
    querys = concat(query, "&")
  end
  local path = "/v2/hubs/" .. hub .. "/streams" .. (querys and '?' .. querys or '')
  local Authorization, QboxAuthorization = token.getAccessToken(AccessKey, SecretKey, { path = path, args = args })
  return httpc.get(Stream.domain.. path, { {"Authorization", QboxAuthorization}, {"Content-Type", "application/x-www-form-urlencoded"} })
end

-- 禁止推流
function Stream.disableStream (AccessKey, SecretKey, hub, key)
  if type(AccessKey) ~= 'string' or AccessKey == '' then
    return nil, "invaild AccessKey."
  end
  if type(SecretKey) ~= 'string' or SecretKey == '' then
    return nil, "invaild SecretKey."
  end
  if type(hub) ~= 'string' or hub == '' then
    return nil, "invaild hub."
  end
  if type(key) ~= 'string' or key == '' then
    return nil, "invaild key."
  end
  local path = "/v2/hubs/" .. hub .. "/streams/" .. base64encode(key) .. '/disabled'
  local Authorization, QboxAuthorization = token.getAccessToken(AccessKey, SecretKey, { path = path })
  return httpc.json(Stream.domain.. path, { {"Authorization", QboxAuthorization} }, json.encode({ {"disabledTill", key} }))
end

-- 获取指定流相关信息
function Stream.getStreamLive (AccessKey, SecretKey, hub, key)
  if type(AccessKey) ~= 'string' or AccessKey == '' then
    return nil, "invaild AccessKey."
  end
  if type(SecretKey) ~= 'string' or SecretKey == '' then
    return nil, "invaild SecretKey."
  end
  if type(hub) ~= 'string' or hub == '' then
    return nil, "invaild hub."
  end
  if type(key) ~= 'string' or key == '' then
    return nil, "invaild key."
  end
  local path = "/v2/hubs/" .. hub .. "/streams/" .. base64encode(key) .. '/live'
  local Authorization, QboxAuthorization = token.getAccessToken(AccessKey, SecretKey, { path = path })
  return httpc.get(Stream.domain.. path, { {"Authorization", QboxAuthorization }, {"Content-Type", "application/x-www-form-urlencoded"} })
end

-- 批量获取指定流相关信息
function Stream.getStreamLives (AccessKey, SecretKey, hub, lives)
  if type(AccessKey) ~= 'string' or AccessKey == '' then
    return nil, "invaild AccessKey."
  end
  if type(SecretKey) ~= 'string' or SecretKey == '' then
    return nil, "invaild SecretKey."
  end
  if type(hub) ~= 'string' or hub == '' then
    return nil, "invaild hub."
  end
  if type(lives) ~= 'table' or (#lives <= 0 or #lives > 100) then
    return nil, "invaild lives. 0 < lives < 100"
  end
  local path = "/v2/hubs/" .. hub .. "/livestreams"
  local Authorization, QboxAuthorization = token.getAccessToken(AccessKey, SecretKey, { path = path })
  return httpc.json(Stream.domain.. path, { {"Authorization", QboxAuthorization } }, json.encode(lives))
end

-- 查询直播流历史记录
function Stream.getStreamHistory (AccessKey, SecretKey, hub, key, opt)
  if type(AccessKey) ~= 'string' or AccessKey == '' then
    return nil, "invaild AccessKey."
  end
  if type(SecretKey) ~= 'string' or SecretKey == '' then
    return nil, "invaild SecretKey."
  end
  if type(hub) ~= 'string' or hub == '' then
    return nil, "invaild hub."
  end
  if type(key) ~= 'string' or key == '' then
    return nil, "invaild key."
  end
  local args = "start=" .. (type(opt) == 'table' and opt['start'] or 0) .. "&" .. "end=" .. (type(opt) == 'table' and opt['end'] or 0)
  local path = "/v2/hubs/" .. hub .. "/streams/" .. base64encode(key) .. '/historyactivity?' .. args
  local Authorization, QboxAuthorization = token.getAccessToken(AccessKey, SecretKey, { path = path, args = args })
  return httpc.get(Stream.domain.. path, { {"Authorization", QboxAuthorization }, {"Content-Type", "application/x-www-form-urlencoded"} })
end

-- 生成rtmp推流地址
function Stream.rtmpPublishUrl (AccessKey, SecretKey, domain, hub, key, expire)
  if type(AccessKey) ~= 'string' or AccessKey == '' then
    return nil, "invaild AccessKey."
  end
  if type(SecretKey) ~= 'string' or SecretKey == '' then
    return nil, "invaild SecretKey."
  end
  if type(domain) ~= 'string' or domain == '' then
    return nil, "invaild domain."
  end
  if type(hub) ~= 'string' or hub == '' then
    return nil, "invaild hub."
  end
  if type(key) ~= 'string' or key == '' then
    return nil, "invaild key."
  end
  local path = '/' .. hub .. '/' .. key .. '?' .. ( expire and 'e='..expire or '' )
  local token = AccessKey .. ':' .. base64encode(hmac_sha1(SecretKey, path))
  return "rtmp://" .. domain .. path .. ( expire and '&token=' .. token or 'token=' .. token )
end

-- 获取rtmp观播地址
function Stream.rtmpSubscribeUrl (domain, hub, key)
  if type(domain) ~= 'string' or domain == '' then
    return nil, "invaild domain."
  end
  if type(hub) ~= 'string' or hub == '' then
    return nil, "invaild hub."
  end
  if type(key) ~= 'string' or key == '' then
    return nil, "invaild key."
  end
  return concat({'rtmp://' .. domain, hub, key}, "/")
end

-- 获取HLS观播地址
function Stream.hlsSubscribeUrl (domain, hub, key)
  if type(domain) ~= 'string' or domain == '' then
    return nil, "invaild domain."
  end
  if type(hub) ~= 'string' or hub == '' then
    return nil, "invaild hub."
  end
  if type(key) ~= 'string' or key == '' then
    return nil, "invaild key."
  end
  return concat({'http://' .. domain, hub, key..".m3u8"}, "/")
end

-- 获取HDL观播地址
function Stream.hdlSubscribeUrl (domain, hub, key)
  if type(domain) ~= 'string' or domain == '' then
    return nil, "invaild domain."
  end
  if type(hub) ~= 'string' or hub == '' then
    return nil, "invaild hub."
  end
  if type(key) ~= 'string' or key == '' then
    return nil, "invaild key."
  end
  return concat({'http://' .. domain, hub, key..".flv"}, "/")
end

-- 直播快照地址
function Stream.getSnapshot (domain, hub, key)
  if type(domain) ~= 'string' or domain == '' then
    return nil, "invaild domain."
  end
  if type(hub) ~= 'string' or hub == '' then
    return nil, "invaild hub."
  end
  if type(key) ~= 'string' or key == '' then
    return nil, "invaild key."
  end
  return concat({'http://' .. domain, hub, key..".jpg"}, "/")
end

return Stream
