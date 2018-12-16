--[[
-- CDN网址
--]]

local class = require "class"

local fmt = string.format


local insert = table.insert
local concat = table.concat

local Admin = class("Admin")


function Admin:ctor(opt)
    opt = opt or {}
    -- 固定内容, 此处谨慎修改 --
    self._CHARSET_ = '<meta content="text/html;charset=utf-8">'
    self._MULTIPLE_SELECT_ = '<meta name="renderer" content="webkit|ie-comp|ie-stand">'
    self._VIEWPORT_ = '<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0,minimum-scale=1.0, user-scalable=0" />'
    self._UA_COMPATIBLE_ = '<meta http-equiv="X-UA-Compatible" content="IE=edge, chrome=1">'
    self._NO_TRANSFORM_ = '<meta http-equiv="Cache-Control" content="no-siteapp" />'
    -- 固定内容, 此处谨慎修改 --

    -- Logo 图标 -- 
    self._FAVICON1_favicon = fmt('<link rel="Bookmark" href="%s" >', opt.favicon or '/favicon.ico')
    self._FAVICON2_favicon = fmt('<link rel="Shortcut Icon" href="%s" />', opt.favicon or '/favicon.ico')
    self._LOGO_ = concat({self._FAVICON1_favicon, self._FAVICON2_favicon})
    -- Logo 图标 -- 

    -- title --
    self._TITLE_ = fmt('<title>%s</title>', opt.title or 'cf-Admin 管理后台')
    -- title --

    -- keywords --
    -- TODO :)
    -- keywords --


    -- css --
    assert(not opt.csss or (type(opt.csss) == 'table' and #opt.csss > 0), '自定义css需要指定csss字段, 并且为一个路径字符串数组')
    self._HEAD_CSS_  = concat(opt.csss or {
        '<link rel="stylesheet" type="text/css" href="static/h-ui/css/H-ui.min.css" />',
        '<link rel="stylesheet" type="text/css" href="static/h-ui.admin/css/H-ui.admin.css" />',
        '<link rel="stylesheet" type="text/css" href="lib/Hui-iconfont/1.0.8/iconfont.css" />',
        '<link rel="stylesheet" type="text/css" href="static/h-ui.admin/css/style.css" />',
    })
    -- css --

    self._HTML_VERSION_  = '<!DOCTYPE HTML>'

    self._HTML_START_  = '<html>'
    self._HTML_END_    = '</html>'

    self._HEAD_START_  = '<head>'
    self._HEAD_END_    = '</head>'

    self._BODY_START_  = '<body>'
    self._BODY_END_    = '</body>'

end




-- 修改title地址
function Admin:set_title(title)
    self._TITLE_ = fmt('<title>%s</title>', title or 'cf-Admin 管理后台')
end

-- 修改logo地址
function Admin:set_logo(url)
    self._LOGO_ = concat({fmt(self._FAVICON1_favicon, url or '/favicon.ico'), fmt(self._FAVICON2_favicon, url or '/favicon.ico')})
end


function Admin:update()
    return concat({
        self._HTML_VERSION_,
        self._HTML_START_,
            -- HEAD --
            self._HEAD_START_,
            self._CHARSET_,
            self._MULTIPLE_SELECT_,
            self._VIEWPORT_,
            self._UA_COMPATIBLE_,
            self._NO_TRANSFORM_,
            self._LOGO_,
            self._TITLE_,
            self._HEAD_CSS_,
            self._HEAD_END_,
            -- HEAD --

            -- BODY --
            self._BODY_START_,

            self._BODY_END_,
            -- BODY --
        self._HTML_END_
    })
end




return Admin