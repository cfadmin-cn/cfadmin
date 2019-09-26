local sms = require "cloud.qiniu.sms"
local oss = require "cloud.qiniu.oss"

local AccessKey = 'Your_Real_AccessKey'
local SecretKey = 'Your_Real_SecretKey'

-- 发送短信
-- local ok, err = sms.sendSMS(AccessKey, SecretKey, { template_id = '1174104085482180608', mobiles = {'+8613000000000'}, parameters = { code = tostring(math.random(1, 1024)) }})
-- require"logging":DEBUG(ok, err)

-- 获取短信模板列表
-- local ok, err = sms.getTemplates(AccessKey, SecretKey, { page = 1, page_size = 100 })
-- require"logging":DEBUG(ok, err)

-- 获取短信签名列表
-- local ok, err = sms.getSignatures(AccessKey, SecretKey, { page = 1, page_size = 90 })
-- require"logging":DEBUG(ok, err)

-- 获取发送短信记录
-- local ok, err = sms.getSMSRecord(AccessKey, SecretKey, { start = '1568131200', ['end'] = '1568822399'})
-- require"logging":DEBUG(ok, err)

-- 删除模板
-- local ok, err = sms.detTemplate(AccessKey, SecretKey, '1174104085482180608')
-- require"logging":DEBUG(ok, err)

-- 删除签名
-- local ok, err = sms.delSignature(AccessKey, SecretKey, '1174104085482180608')
-- require"logging":DEBUG(ok, err)

--  ***************

-- 生成上传token
-- local upToken = oss.getUploadToken(AccessKey, SecretKey, { bucket = 'candymi' })
-- require"logging":DEBUG(upToken)

-- 生成下载token
-- local upToken = oss.getDownloadToken(AccessKey, SecretKey, { url = 'https://www.gitub.com/a.img', expires = os.time() + 180 })
-- require"logging":DEBUG(upToken)
