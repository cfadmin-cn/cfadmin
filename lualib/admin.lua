local fmt = string.format
local insert = table.insert
local concat = table.concat

local DOCTYPE    = "<!DOCTYPE html>"
local HTML_START = "<html>"
local HTML_END   = "/<html>"
local HEAD_START = "<head>"
local HEAD_END   = "</head>"
local BODY_START = "<head>"
local HEAD_END   = "</head>"

local Admin = {}

-- 登录页
function Admin.login(db, ...)
    local html = {
        DOCTYPE,
        HTML_START,
        '<meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">',
        fmt("<title>%s</title>", title),
        fmt('<link rel="stylesheet" href="%s">', css),
        fmt('<script type="text/javascript" src="%s"></script>', js),
    }
end

-- 网格
function Admin.grid(db, ...)
    -- body
end

-- 表单
function Admin.form(db, ...)
    -- body
end

return Admin