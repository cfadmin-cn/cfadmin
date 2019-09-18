local httpc = require "httpc"
local crypt = require "crypt"
local json = require "json"

local type = type

local sms = { __Version__ = 0.1 }
--[[
此为七牛云短信服务的lua版实现.
提供了包含短信的发送/记录查询/获取模板/删除模板/获取签名/删除签名/
]]

-- 生成管理凭证
function sms.newAuthorization (AccessKey, SecretKey, opt)
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

-- 获取短信模板列表
function sms.getTemplates (AccessKey, SecretKey, opt)
  if type(AccessKey) ~= 'string' or AccessKey == '' then
    return nil, "invaild AccessKey."
  end
  if type(SecretKey) ~= 'string' or SecretKey == '' then
    return nil, "invaild SecretKey."
  end
  local args
  if opt then
    args = {}
    if opt.page then
      args[#args+1] = 'page=' .. opt.page
    end
    if opt.page_size then
      args[#args+1] = 'page_size=' .. opt.page_size
    end
    if #args == 0 then
      args = nil
    end
  end
  local Authorization = sms.newAuthorization(AccessKey, SecretKey, { method = 'GET', host = 'sms.qiniuapi.com', path = '/v1/template', query = args and '?' .. table.concat(args, '&') or nil })
  local code, ret = httpc.get('https://sms.qiniuapi.com/v1/template'..(args and '?'..table.concat(args, '&') or ''), {{ 'Authorization', Authorization }})
  if code ~= 200 then
    return nil, ret
  end
  return code, json.decode(ret)
end

-- 删除短信模板列表
function sms.detTemplate (AccessKey, SecretKey, template_id)
  if type(AccessKey) ~= 'string' or AccessKey == '' then
    return nil, "invaild AccessKey."
  end
  if type(SecretKey) ~= 'string' or SecretKey == '' then
    return nil, "invaild SecretKey."
  end
  if type(template_id) ~= 'string' or template_id == '' then
    return nil, "invaild template_id."
  end
  local Authorization = sms.newAuthorization(AccessKey, SecretKey, { method = 'DELETE', host = 'sms.qiniuapi.com', path = '/v1/template/' .. template_id })
  local code, ret = httpc.delete("https://sms.qiniuapi.com" .. '/v1/template/' .. template_id, {{'Authorization', Authorization}})
  if code ~= 200 then
    return nil, ret
  end
  return code, ret
end

-- 获取短信签名列表
function sms.getSignatures (AccessKey, SecretKey, opt)
  if type(AccessKey) ~= 'string' or AccessKey == '' then
    return nil, "invaild AccessKey."
  end
  if type(SecretKey) ~= 'string' or SecretKey == '' then
    return nil, "invaild SecretKey."
  end
  local args
  if opt then
    args = {}
    if opt.page then
      args[#args+1] = 'page=' .. opt.page
    end
    if opt.page_size then
      args[#args+1] = 'page_size=' .. opt.page_size
    end
    if #args == 0 then
      args = nil
    end
  end
  local Authorization = sms.newAuthorization(AccessKey, SecretKey, { method = 'GET', host = 'sms.qiniuapi.com', path = '/v1/signature', query = args and '?' .. table.concat(args, '&') or nil })
  local code, ret = httpc.get('https://sms.qiniuapi.com/v1/signature'..(args and '?'..table.concat(args, '&') or ''), {{ 'Authorization', Authorization }})
  if code ~= 200 then
    return nil, ret
  end
  return code, json.decode(ret)
end

-- 删除短信签名列表
function sms.delSignature (AccessKey, SecretKey, signature_id)
  if type(AccessKey) ~= 'string' or AccessKey == '' then
    return nil, "invaild AccessKey."
  end
  if type(SecretKey) ~= 'string' or SecretKey == '' then
    return nil, "invaild SecretKey."
  end
  if type(signature_id) ~= 'string' or signature_id == '' then
    return nil, "invaild signature_id."
  end
  local Authorization = sms.newAuthorization(AccessKey, SecretKey, { method = 'DELETE', host = 'sms.qiniuapi.com', path = '/v1/signature/' .. signature_id })
  local code, ret = httpc.delete("https://sms.qiniuapi.com" .. '/v1/signature/' .. signature_id, {{'Authorization', Authorization}})
  if code ~= 200 then
    return nil, ret
  end
  return code, json.decode(ret)
end

-- 获取短信发送记录
function sms.getSMSRecord (AccessKey, SecretKey, opt)
  if type(AccessKey) ~= 'string' or AccessKey == '' then
    return nil, "invaild AccessKey."
  end
  if type(SecretKey) ~= 'string' or SecretKey == '' then
    return nil, "invaild SecretKey."
  end
  local args
  if opt then
    args = {}
    if opt.page then
      args[#args+1] = 'page=' .. opt.page
    end
    if opt.page_size then
      args[#args+1] = 'page_size=' .. opt.page_size
    end
    if opt.mobile then
      args[#args+1] = 'mobile=' .. opt.mobile
    end
    if opt.status then
      args[#args+1] = 'status=' .. opt.status
    end
    if opt.start then
      args[#args+1] = 'start=' .. opt.start
    end
    if opt['end'] then
      args[#args+1] = 'end=' .. opt['end']
    end
    if opt.type then
      args[#args+1] = 'type=' .. opt.type
    end
    if opt.job_id then
      args[#args+1] = 'job_id=' .. opt.job_id
    end
    if opt.message_id then
      args[#args+1] = 'message_id=' .. opt.message_id
    end
    if opt.template_id then
      args[#args+1] = 'template_id=' .. opt.template_id
    end
    if #args == 0 then
      args = nil
    end
  end
  local Authorization = sms.newAuthorization(AccessKey, SecretKey, { method = 'GET', host = 'sms.qiniuapi.com', path = '/v1/messages', query = args and '?' .. table.concat(args, '&') or nil })
  local code, ret = httpc.get('https://sms.qiniuapi.com/v1/messages'..(args and '?'..table.concat(args, '&') or ''), {{ 'Authorization', Authorization}})
  if code ~= 200 then
    return nil, ret
  end
  return code, json.decode(ret)
end

-- 发送国内短信
function sms.sendSMS (AccessKey, SecretKey, opt)
  if type(AccessKey) ~= 'string' or AccessKey == '' then
    return nil, "invaild AccessKey."
  end
  if type(SecretKey) ~= 'string' or SecretKey == '' then
    return nil, "invaild SecretKey."
  end
  if type(opt) ~= 'table' or not next(opt) then
    return nil, "invaild opt arguments."
  end
  if type(opt.template_id) ~= 'string' or type(opt.mobiles) ~= 'table' then
    return nil, "invaild template_id or mobiles."
  end
  local body = json.encode({ mobiles = opt.mobiles, template_id = opt.template_id, parameters = opt.parameters })
  local Authorization = sms.newAuthorization(AccessKey, SecretKey, {
    method = 'POST', host = 'sms.qiniuapi.com', path = '/v1/message', body = body,
  })
  local code, ret = httpc.json('https://sms.qiniuapi.com/v1/message', { { 'Authorization', Authorization } }, body)
  if code ~= 200 then
    return nil, ret
  end
  return code, json.decode(ret)
end

-- 发送国际短信
function sms.sendOverseaSMS (AccessKey, SecretKey, opt)
  if type(AccessKey) ~= 'string' or AccessKey == '' then
    return nil, "invaild AccessKey."
  end
  if type(SecretKey) ~= 'string' or SecretKey == '' then
    return nil, "invaild SecretKey."
  end
  if type(opt) ~= 'table' or not next(opt) then
    return nil, "invaild opt arguments."
  end
  if type(opt.template_id) ~= 'string' or type(opt.mobile) ~= 'string' then
    return nil, "invaild template_id or mobiles."
  end
  local body = json.encode({ mobile = opt.mobile, template_id = opt.template_id, parameters = opt.parameters })
  local Authorization = sms.newAuthorization(AccessKey, SecretKey, {
    method = 'POST', host = 'sms.qiniuapi.com', path = '/v1/message/oversea', body = body,
  })
  local code, ret = httpc.json('https://sms.qiniuapi.com/v1/message/oversea', { { 'Authorization', Authorization } }, body)
  if code ~= 200 then
    return nil, ret
  end
  return code, json.decode(ret)
end

return sms
