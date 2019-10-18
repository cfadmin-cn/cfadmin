local crypt = require "crypt"

local Crypt = {
  hmac_sha1 = crypt.hmac_sha1,
  urlencode = crypt.urlencode,
  urldecode = crypt.urldecode,
}

function Crypt.urlsafe_base64encode(data)
  return crypt.base64encode(data):gsub('+', '-'):gsub('/', '_')
end

function Crypt.urlsafe_base64decode(data)
  return crypt.base64decode(data:gsub('-', '+'):gsub("_", "/"))
end

return Crypt