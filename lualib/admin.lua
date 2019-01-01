local fmt = string.format
local insert = table.insert
local concat = table.concat

local DOCTYPE    = "<!DOCTYPE html>"
local HTML_START = "<html>"
local HTML_END   = "/<html>"
local HEAD_START = "<head>"
local HEAD_END   = "</head>"
local BODY_START = '<body class="%s">'
local BODY_END   = "</body>"

local Admin = {}

local title = "cfadmin/0.1 后台管理系统"

local css = 'static/layui/css/layui.css'
local js = 'static/layui/layui.js'

local meta = {
    '<meta charset="utf-8">',
    '<meta http-equiv="X-UA-Compatible" content="IE=edge, chrome=1">',
    '<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">',
}

-- 添加元素
local function add_to(t, txt)
    return insert(t, txt)
end

-- 表连接
local function merge(t)
    local t = {}
    for _, content in ipairs(t) do
        add_to(t, concat(concat, " "))
    end
    return concat(t, " ")
end

-- 标准输入框
local function input(opt)
    -- 输入框前置lable
    local label = opt.label or "自定义label"
    -- 内容
    local placeholder = fmt('placeholder="%s"', opt.placeholder or '自定义input内容')
    -- 自动完成
    local autocomplete = fmt('autocomplete="%s"', opt.autocomplete or 'off')
    --不能为空
    local required = opt.required or 'required lay-verify="required"'

    local name = fmt('name="%s"', opt.name or "name")

    local typ = 'type="text"'

    local class = opt.class or 'class="layui-input"'

    return concat({
        '<div class="layui-form-item">',
            fmt('<label class="layui-form-label">%s</label>', label),
            '<div class="layui-input-block">',
                '<input', typ, name, required, placeholder, autocomplete, class, '>',
            '</div>',
        'div',
    }, " ")
end

-- 邮箱输入框
local function email(opt)
    -- 输入框前置lable
    local label = opt.label or "自定义label"
    -- 内容
    local placeholder = fmt('placeholder="%s"', opt.placeholder or '自定义email内容')
    -- 自动完成
    local autocomplete = fmt('autocomplete="%s"', opt.autocomplete or 'off')
    --不能为空
    local required = opt.required or 'lay-verify="email"'

    local name = fmt('name="%s"', opt.name or "email")

    local typ = 'type="text"'

    local class = opt.class or 'class="layui-input"'

    return concat({
        '<div class="layui-form-item">',
            fmt('<label class="layui-form-label">%s</label>', label),
            '<div class="layui-input-block">',
                '<input', typ, name, required, placeholder, autocomplete, class, '>',
            '</div>',
        'div',
    }, " ")
end

-- 手机号输入框
local function phone(opt)
    -- 输入框前置lable
    local label = opt.label or "自定义label"
    -- 内容
    local placeholder = fmt('placeholder="%s"', opt.placeholder or '自定义phone内容')
    -- 自动完成
    local autocomplete = fmt('autocomplete="%s"', opt.autocomplete or 'off')
    --不能为空
    local required = opt.required or 'lay-verify="required|phone"'

    local name = fmt('name="%s"', opt.name or "phone")

    local typ = 'type="text"'

    local class = opt.class or 'class="layui-input"'

    return concat({
        '<div class="layui-form-item">',
            fmt('<label class="layui-form-label">%s</label>', label),
            '<div class="layui-input-block">',
                '<input', typ, name, required, placeholder, autocomplete, class, '>',
            '</div>',
        'div',
    }, " ")
end

-- 日期输入框
local function date(opt)
    -- 输入框前置lable
    local label = opt.label or "自定义label"
    -- 内容
    local placeholder = fmt('placeholder="%s"', opt.placeholder or '自定义date内容')
    -- 自动完成
    local autocomplete = fmt('autocomplete="%s"', opt.autocomplete or 'off')
    --不能为空
    local required = opt.required or 'lay-verify="date"'

    local name = fmt('name="%s"', opt.name or "date")

    local typ = 'type="text"'

    local class = opt.class or 'class="layui-input"'

    return concat({
        '<div class="layui-form-item">',
            fmt('<label class="layui-form-label">%s</label>', label),
            '<div class="layui-input-block">',
                '<input', typ, name, required, placeholder, autocomplete, class, '>',
            '</div>',
        'div',
    }, " ")
end

-- url输入框
local function url(opt)
    -- 输入框前置lable
    local label = opt.label or "自定义label"
    -- 内容
    local placeholder = fmt('placeholder="%s"', opt.placeholder or '自定义url内容')
    -- 自动完成
    local autocomplete = fmt('autocomplete="%s"', opt.autocomplete or 'off')
    --不能为空
    local required = opt.required or 'lay-verify="url"'

    local name = fmt('name="%s"', opt.name or "url")

    local typ = 'type="text"'

    local class = opt.class or 'class="layui-input"'

    return concat({
        '<div class="layui-form-item">',
            fmt('<label class="layui-form-label">%s</label>', label),
            '<div class="layui-input-block">',
                '<input', typ, name, required, placeholder, autocomplete, class, '>',
            '</div>',
        'div',
    }, " ")
end

-- 提交按钮
local function submit(opt)
    -- body
end

-- 重置按钮
local function reset(opt)
    -- body
end

local function form(action, cb)
    local t = {
        email = email,
        url = url,
        phone = phone,
        date = date,
        input = input,
    }
    local ok, err = pcall(cb, t)
    if not ok then
        return print(err)
    end
    return concat({
        fmt('<form class="layui-form" action="%s">', action), 
            concat(t, " "),
        '</form>',
    })
end

-- 登录页
function Admin.login()
    local html = {
        DOCTYPE,
        HTML_START,
        HEAD_START,
            concat(meta),
            fmt("<title>%s</title>", title),
            fmt('<link rel="stylesheet" href="%s">', css),
            fmt('<script type="text/javascript" src="%s"></script>', js),
        HEAD_END,
        fmt(BODY_START, 'layui-layout-body'),
            fmt('<div class="message">%s</div>', title),
            form("/b", function (content)
                
            end),
        BODY_END,
    }
    return concat(html)
end

-- 网格
function Admin.grid()
    -- body
end

-- 表单
function Admin.form()
    -- body
end

return Admin