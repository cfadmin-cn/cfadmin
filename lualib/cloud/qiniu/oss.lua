local token = require "cloud.qiniu.token"

local oss = { __Version__ = 0.1, getUploadToken = token.getUploadToken, getDownloadToken = token.getDownloadToken }

--[[
此为七牛云对象存储服务的上传与下载Token生成库的原生lua实现.
此库实现了服务端根据指定算法生成临时上传/下载的授权Token后交由客户端上传文件, 服务端不负责具体业务.
具体使用方法请参考: https://developer.qiniu.com/kodo/manual/1644/security
]]

return oss
