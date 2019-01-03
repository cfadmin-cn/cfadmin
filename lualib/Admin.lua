local log = require "log"
local fmt = string.format
local insert = table.insert
local concat = table.concat

local DOCTYPE    = "<!DOCTYPE html>"
local HTML_START = "<html>"
local HTML_END   = "</html>"
local HEAD_START = "<head>"
local HEAD_END   = "</head>"
local BODY_START = '<body class="%s">'
local BODY_END   = "</body>"
local SCRIPT_START = "<script>"
local SCRIPT_END = "</script>"

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
local function add_string(t, ...)
    return insert(t, ...)
end

-- 添加字段
local function add_table(t, table)
    return insert(t, table)
end

-- 表连接
local function merge(t)
    local t = {}
    for _, content in ipairs(t) do
        add_string(t, concat(concat, " "))
    end
    return concat(t, " ")
end

-- 数组内的元素包是否含此key
local function key_in_table(key, list)
    for _, t in ipairs(list) do
        if t[key] then
            return true
        end
    end
    return false
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

local function table(cb)
    -- 表单格式
    local table_lay_data = {"id:'table'"}
    -- 字段格式
    local rows_lay_date = {}
    -- js模板
    local js_template = {
        '<script type="text/html" id="toolbar">',
        '</script>',
    }
    -- js脚本
    local js = {}

    -- 注入到回调的内部方法
    local content
    content = {
        url = "#",    -- 默认请求连接
        height = 'full', -- 默认高度
        page = 'page:true',
        limit = nil,
        limits = nil,
        tools  = nil,
        -- 行尾增加工具方法
        toolbar = function (ct, tools)
            assert(ct == content, "错误的tools方法调用")
            assert(tools and type(tools) == "table", "错误的tools方法调用")
            content['tools'] = tools
        end,
        rows = function (ct, row)
            assert(ct == content, "错误的rows方法调用")
            assert(row and type(row) == "string", "错误的row类型")
            local t, fields = nil, {
                field = row,
                name = nil,
                sorted = nil,
                align = nil,
            }
            t = {
                -- 字段名
                name = function (tab, name)
                    assert(t == tab, "错误的name方法调用")
                    fields['name'] = name
                    return t
                end,
                -- 是否为该字段排序
                sorted = function (tab)
                    assert(t == tab, "错误的sorted方法调用")
                    fields['sorted'] = true
                    return t
                end,
                -- 单元格内容
                align = function (tab, style)
                    assert(t == tab, "错误的align方法调用")
                    fields['align'] = style
                    return t
                end,
                -- 隐藏字段
                hide = function (tab)
                    assert(t == tab, "错误的hide方法调用")
                    fields['hide'] = true
                    return t
                end
            }
            add_table(rows_lay_date, fields)
            return t
        end
    }
    local ok, err = pcall(cb, content)
    if not ok then
        return err or "table unknown error.", log.error(err)
    end

    if content.url then add_string(table_lay_data, fmt("url:'%s'", content.url)) end

    if content.page then add_string(table_lay_data, "page:'true'") end

    if content.limit then add_string(table_lay_data, fmt("limit:'%s'", content.limit)) end

    if content.limits then add_string(table_lay_data, fmt("limits:%s", "["..concat(content.limits, ", ").."]")) end

    if content.height then add_string(table_lay_data, fmt("height:'%s'", content.height)) end

    local ths = {}

    for _, row in ipairs(rows_lay_date) do
        local th = '<th lay-data="{%s}">%s</th>'
        local t = {}
        if row.field then add_string(t, fmt("field:'%s'", row.field)) end

        if row.align then add_string(t, fmt("align:'%s'", row.align)) end

        if row.hide then add_string(t, fmt("hide:'%s'", row.hide)) end

        if row.sorted then add_string(t, fmt("sort:'%s'", row.sorted)) end

        add_string(ths, fmt(th, concat(t, ", "), row.name or row.field or "unknow"))
    end

    -- 加入工具行代码
    if content.tools then
        local button = {
            blue   = 'layui-btn-normal',  -- 天蓝
            yellow = 'layui-btn-warm',    -- 暖色
            red    = 'layui-btn-danger',  -- 红色
            normal = 'layui-btn-primary'  -- 急用
        }
        add_string(ths, fmt('<th lay-data="{%s}"></th>',
            concat({
                "fixed:'right'",
                "toolbar:'#toolbar'",
                "align:'center'",
            }, ", ")))
        local tool_sevent = {
            "table.on('tool(table)', function(obj){",
            "   var data = obj.data ",
            "   switch(obj.event){",
            '}})',
        }
        for _, tool in ipairs(content.tools) do
            add_string(js_template, #js_template, fmt('<a class="layui-btn layui-btn-xs %s" lay-event="%s">%s</a>',
                button[tool[3]or'normal'], -- 颜色
                tool[1],                   -- 事件名称
                tool[2]                    -- 按钮名字
            ))
            if tool[4] and type(tool[4]) == "function" then
                add_string(tool_sevent, #tool_sevent, tool[4]())
            end
        end
        add_string(js, concat(tool_sevent, "\r\n"))
    end

    return concat({
        fmt([[<table class="layui-table" lay-data="{%s}" lay-filter="%s">]], concat(table_lay_data, ", "), 'table'),
            '<thead>',
                '<tr>',
                    concat(ths, " "),
                '</tr>',
            '</thead>',
        '</table>',
        concat(js_template, "\r\n"),
        SCRIPT_START,
        '\r\nlayui.use("table", function(){\r\n\tvar table = layui.table;',
        concat(js, "\r\n"),
        '\r\n});',
        SCRIPT_END,
    }, " ")
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
            table(function (content)
                content.url = "/demo"
                content.height = '500'
                content.limit = 100
                content.limits = {10, 50, 100, 200, 500, 1000}
                content:rows("id"):name("ID"):align("Center"):sorted()
                content:rows("username"):name("用户名"):align("Center")
                content:rows("sex"):name("性别"):align("Center")
                content:rows("city"):name("城市"):align("Center")
                content:rows("phone"):name("联系电话"):align("Center")
                content:rows("birthday"):name("生日"):align("Center")
                content:toolbar({
                    {"edit", "编辑", "blue", function ()
                        return [[
                            case "edit":
                                layer.msg("编辑");
                                break;
                        ]]
                    end},
                    {"delete", "删除", "red", function ()
                        return [[
                            case "delete":
                                layer.confirm('真的删除行么', function(index){
                                    obj.del();
                                    layer.close(index);
                                });
                            break;
                        ]]
                    end}})
            end),
        BODY_END,
        HTML_END,
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