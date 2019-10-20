local crypt = require "crypt"
local base64urlencode = crypt.base64urlencode
local base64urldecode = crypt.base64urldecode

local Crypt = {
  hmac_sha1 = crypt.hmac_sha1,
  urlencode = crypt.urlencode,
  urldecode = crypt.urldecode,
  urlsafe_base64encode = base64urlencode,
  urlsafe_base64decode = base64urldecode,
}

return Crypt