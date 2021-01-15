local aio = require "aio"
local aio_open = aio.open

local sys = require "sys"
local newtab = sys.new_tab

local setmetatable = setmetatable
local tostring = tostring
local concat = table.concat
local assert = assert
local pcall = pcall
local load = load
local type = type
local dump = string.dump
local find = string.find
local gsub = string.gsub
local byte = string.byte
local null = null
local sub = string.sub
local print_view = io.write

local HTML_ENTITIES = {
    ["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ['"'] = "&quot;",
    ["'"] = "&#39;",
    ["/"] = "&#47;"
}

local CODE_ENTITIES = {
    ["{"] = "&#123;",
    ["}"] = "&#125;",
    ["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ['"'] = "&quot;",
    ["'"] = "&#39;",
    ["/"] = "&#47;"
}

local ESC    = byte("\27")
local NUL    = byte("\0")
local HT     = byte("\t")
local VT     = byte("\v")
local LF     = byte("\n")
local SOL    = byte("/")
local BSOL   = byte("\\")
local SP     = byte(" ")
local AST    = byte("*")
local NUM    = byte("#")
local LPAR   = byte("(")
local LSQB   = byte("[")
local LCUB   = byte("{")
local MINUS  = byte("-")
local PERCNT = byte("%")

local EMPTY  = ""

local VIEW_ENV = { __index = function(t, k)
      return t.context[k] or t.template[k] or _ENV[k]
  end
}

local function enabled(val)
    if val == nil then return true end
    return val == true or (val == "1" or val == "true" or val == "on")
end

local function trim(s)
    return gsub(gsub(s, "^%s+", EMPTY), "%s+$", EMPTY)
end

local function rpos(view, s)
    while s > 0 do
        local c = byte(view, s, s)
        if c == SP or c == HT or c == VT or c == NUL then
            s = s - 1
        else
            break
        end
    end
    return s
end

local function escaped(view, s)
    if s > 1 and byte(view, s - 1, s - 1) == BSOL then
        if s > 2 and byte(view, s - 2, s - 2) == BSOL then
            return false, 1
        else
            return true, 1
        end
    end
    return false, 0
end

local function read_file(path)
    local f, err = aio_open(path)
    if not f then
      return nil, err
    end
    local content = f:readall()
    f:close()
    f = nil
    return content
end

local function load_view(template)
    return function(view, plain)
        if plain == true then
          return view
        end
        local path, root = view, template.root
        if root and root ~= EMPTY then
            if byte(root, -1) == SOL then
              root = sub(root, 1, -2)
            end
            if byte(view,  1) == SOL then
              path = sub(view, 2)
            end
            path = root .. "/" .. path
        end
        return plain == false and assert(read_file(path)) or read_file(path) or view
    end
end

local function load_file(func)
    return function(view) return func(view, false) end
end

local function load_string(func)
    return function(view) return func(view, true) end
end

local function loader(template)
    return function(view)
        return assert(load(view, nil, nil, setmetatable({ template = template }, VIEW_ENV)))
    end
end

local function visit(visitors, content, tag, name)
    if not visitors then
        return content
    end

    for i = 1, visitors.n do
        content = visitors[i](content, tag, name)
    end

    return content
end

local function new(template, safe)
    template = template or newtab(0, 26)

    template._VERSION    = "2.0"
    template.cache       = {}
    template.load        = load_view(template)
    template.load_file   = load_file(template.load)
    template.load_string = load_string(template.load)
    template.print       = print_view

    local load_chunk = loader(template)

    local caching = true

    local visitors
    function template.visit(func)
        if not visitors then
            visitors = { func, n = 1 }
            return
        end
        visitors.n = visitors.n + 1
        visitors[visitors.n] = func
    end

    function template.caching(enable)
        if enable ~= nil then caching = enable == true end
        return caching
    end

    function template.output(s)
        if s == nil or s == null then return EMPTY end
        if type(s) == "function" then return template.output(s()) end
        return tostring(s)
    end

    function template.escape(s, c)
        if type(s) == "string" then
            if c then return gsub(s, "[}{\">/<'&]", CODE_ENTITIES) end
            return gsub(s, "[\">/<'&]", HTML_ENTITIES)
        end
        return template.output(s)
    end

    function template.new(view, layout)

        local vt = type(view)

        if vt == "boolean" then
          return new(nil,  view)
        end
        if vt == "table"   then
          return new(view, safe)
        end
        if vt == "nil"     then
          return new(nil,  safe)
        end

        local render
        local process
        if layout then
            if type(layout) == "table" then
                render = function(self, context)
                    context = context or self
                    context.blocks = context.blocks or {}
                    context.view = template.process(view, context)
                    layout.blocks = context.blocks or {}
                    layout.view = context.view or EMPTY
                    layout:render()
                end
                process = function(self, context)
                    context = context or self
                    context.blocks = context.blocks or {}
                    context.view = template.process(view, context)
                    layout.blocks = context.blocks or {}
                    layout.view = context.view
                    return tostring(layout)
                end
            else
                render = function(self, context)
                    context = context or self
                    context.blocks = context.blocks or {}
                    context.view = template.process(view, context)
                    template.render(layout, context)
                end
                process = function(self, context)
                    context = context or self
                    context.blocks = context.blocks or {}
                    context.view = template.process(view, context)
                    return template.process(layout, context)
                end
            end
        else
            render = function(self, context)
                return template.render(view, context or self)
            end
            process = function(self, context)
                return template.process(view, context or self)
            end
        end

        if safe then
            return setmetatable({
                render = function(...)
                    local ok, err = pcall(render, ...)
                    if not ok then
                        return nil, err
                    end
                end,
                process = function(...)
                    local ok, output = pcall(process, ...)
                    if not ok then
                        return nil, output
                    end
                    return output
                end,
             }, {
                __tostring = function(...)
                    local ok, output = pcall(process, ...)
                    if not ok then
                        return ""
                    end
                    return output
            end })
        end

        return setmetatable({
            render = render,
            process = process
        }, {
            __tostring = process
        })
    end

    function template.precompile(view, path, strip, plain)
        local chunk = dump(template.compile(view, nil, plain), strip ~= false)
        if path then
          local f = aio_open(path)
          f:write(chunk)
          f:close()
          f = nil
        end
        return chunk
    end

    function template.precompile_string(view, path, strip)
        return template.precompile(view, path, strip, true)
    end

    function template.precompile_file(view, path, strip)
        return template.precompile(view, path, strip, false)
    end

    function template.compile(view, cache_key, plain)
        assert(view, "view was not provided for template.compile(view, cache_key, plain)")
        if cache_key == "no-cache" then
            return load_chunk(template.parse(view, plain)), false
        end
        cache_key = cache_key or view
        local cache = template.cache
        if cache[cache_key] then return cache[cache_key], true end
        local func = load_chunk(template.parse(view, plain))
        if caching then cache[cache_key] = func end
        return func, false
    end

    function template.compile_file(view, cache_key)
        return template.compile(view, cache_key, false)
    end

    function template.compile_string(view, cache_key)
        return template.compile(view, cache_key, true)
    end

    function template.parse(view, plain)
        assert(view, "view was not provided for template.parse(view, plain)")
        if plain ~= true then
            view = template.load(view, plain)
            if byte(view, 1, 1) == ESC then return view end
        end
        local j = 2
        local c = {[[
context=... or {}
local ___,blocks,layout={},blocks or {}
local function include(v, c) return template.process(v, c or context) end
local function echo(...) for i=1,select("#", ...) do ___[#___+1] = tostring(select(i, ...)) end end
]] }
        local i, s = 1, find(view, "{", 1, true)
        while s do
            local t, p = byte(view, s + 1, s + 1), s + 2
            if t == LCUB then
                local e = find(view, "}}", p, true)
                if e then
                    local z, w = escaped(view, s)
                    if i < s - w then
                        c[j] = "___[#___+1]=[=[\n"
                        c[j+1] = visit(visitors, sub(view, i, s - 1 - w))
                        c[j+2] = "]=]\n"
                        j=j+3
                    end
                    if z then
                        i = s
                    else
                        c[j] = "___[#___+1]=template.escape("
                        c[j+1] = visit(visitors, trim(sub(view, p, e - 1)), "{")
                        c[j+2] = ")\n"
                        j=j+3
                        s, i = e + 1, e + 2
                    end
                end
            elseif t == AST then
                local e = find(view, "*}", p, true)
                if e then
                    local z, w = escaped(view, s)
                    if i < s - w then
                        c[j] = "___[#___+1]=[=[\n"
                        c[j+1] = visit(visitors, sub(view, i, s - 1 - w))
                        c[j+2] = "]=]\n"
                        j=j+3
                    end
                    if z then
                        i = s
                    else
                        c[j] = "___[#___+1]=template.output("
                        c[j+1] = visit(visitors, trim(sub(view, p, e - 1)), "*")
                        c[j+2] = ")\n"
                        j=j+3
                        s, i = e + 1, e + 2
                    end
                end
            elseif t == PERCNT then
                local e = find(view, "%}", p, true)
                if e then
                    local z, w = escaped(view, s)
                    if z then
                        if i < s - w then
                            c[j] = "___[#___+1]=[=[\n"
                            c[j+1] = visit(visitors, sub(view, i, s - 1 - w))
                            c[j+2] = "]=]\n"
                            j=j+3
                        end
                        i = s
                    else
                        local n = e + 2
                        if byte(view, n, n) == LF then
                            n = n + 1
                        end
                        local r = rpos(view, s - 1)
                        if i <= r then
                            c[j] = "___[#___+1]=[=[\n"
                            c[j+1] = visit(visitors, sub(view, i, r))
                            c[j+2] = "]=]\n"
                            j=j+3
                        end
                        c[j] = visit(visitors, trim(sub(view, p, e - 1)), "%")
                        c[j+1] = "\n"
                        j=j+2
                        s, i = n - 1, n
                    end
                end
            elseif t == LPAR then
                local e = find(view, ")}", p, true)
                if e then
                    local z, w = escaped(view, s)
                    if i < s - w then
                        c[j] = "___[#___+1]=[=[\n"
                        c[j+1] = visit(visitors, sub(view, i, s - 1 - w))
                        c[j+2] = "]=]\n"
                        j=j+3
                    end
                    if z then
                        i = s
                    else
                        local f = visit(visitors, sub(view, p, e - 1), "(")
                        local x = find(f, ",", 2, true)
                        if x then
                            c[j] = "___[#___+1]=include([=["
                            c[j+1] = trim(sub(f, 1, x - 1))
                            c[j+2] = "]=],"
                            c[j+3] = trim(sub(f, x + 1))
                            c[j+4] = ")\n"
                            j=j+5
                        else
                            c[j] = "___[#___+1]=include([=["
                            c[j+1] = trim(f)
                            c[j+2] = "]=])\n"
                            j=j+3
                        end
                        s, i = e + 1, e + 2
                    end
                end
            elseif t == LSQB then
                local e = find(view, "]}", p, true)
                if e then
                    local z, w = escaped(view, s)
                    if i < s - w then
                        c[j] = "___[#___+1]=[=[\n"
                        c[j+1] = visit(visitors, sub(view, i, s - 1 - w))
                        c[j+2] = "]=]\n"
                        j=j+3
                    end
                    if z then
                        i = s
                    else
                        c[j] = "___[#___+1]=include("
                        c[j+1] = visit(visitors, trim(sub(view, p, e - 1)), "[")
                        c[j+2] = ")\n"
                        j=j+3
                        s, i = e + 1, e + 2
                    end
                end
            elseif t == MINUS then
                local e = find(view, "-}", p, true)
                if e then
                    local x, y = find(view, sub(view, s, e + 1), e + 2, true)
                    if x then
                        local z, w = escaped(view, s)
                        if z then
                            if i < s - w then
                                c[j] = "___[#___+1]=[=[\n"
                                c[j+1] = visit(visitors, sub(view, i, s - 1 - w))
                                c[j+2] = "]=]\n"
                                j=j+3
                            end
                            i = s
                        else
                            y = y + 1
                            x = x - 1
                            if byte(view, y, y) == LF then
                                y = y + 1
                            end
                            local b = trim(sub(view, p, e - 1))
                            if b == "verbatim" or b == "raw" then
                                if i < s - w then
                                    c[j] = "___[#___+1]=[=[\n"
                                    c[j+1] = visit(visitors, sub(view, i, s - 1 - w))
                                    c[j+2] = "]=]\n"
                                    j=j+3
                                end
                                c[j] = "___[#___+1]=[=["
                                c[j+1] = visit(visitors, sub(view, e + 2, x))
                                c[j+2] = "]=]\n"
                                j=j+3
                            else
                                if byte(view, x, x) == LF then
                                    x = x - 1
                                end
                                local r = rpos(view, s - 1)
                                if i <= r then
                                    c[j] = "___[#___+1]=[=[\n"
                                    c[j+1] = visit(visitors, sub(view, i, r))
                                    c[j+2] = "]=]\n"
                                    j=j+3
                                end
                                c[j] = 'blocks["'
                                c[j+1] = b
                                c[j+2] = '"]=include[=['
                                c[j+3] = visit(visitors, sub(view, e + 2, x), "-", b)
                                c[j+4] = "]=]\n"
                                j=j+5
                            end
                            s, i = y - 1, y
                        end
                    end
                end
            elseif t == NUM then
                local e = find(view, "#}", p, true)
                if e then
                    local z, w = escaped(view, s)
                    if i < s - w then
                        c[j] = "___[#___+1]=[=[\n"
                        c[j+1] = visit(visitors, sub(view, i, s - 1 - w))
                        c[j+2] = "]=]\n"
                        j=j+3
                    end
                    if z then
                        i = s
                    else
                        e = e + 2
                        if byte(view, e, e) == LF then
                            e = e + 1
                        end
                        s, i = e - 1, e
                    end
                end
            end
            s = find(view, "{", s + 1, true)
        end
        s = sub(view, i)
        if s and s ~= EMPTY then
            c[j] = "___[#___+1]=[=[\n"
            c[j+1] = visit(visitors, s)
            c[j+2] = "]=]\n"
            j=j+3
        end
        c[j] = "return layout and include(layout,setmetatable({view=table.concat(___),blocks=blocks},{__index=context})) or table.concat(___)" -- luacheck: ignore
        return concat(c)
    end

    function template.parse_file(view)
        return template.parse(view, false)
    end

    function template.parse_string(view)
        return template.parse(view, true)
    end

    function template.process(view, context, cache_key, plain)
        assert(view, "view was not provided for template.process(view, context, cache_key, plain)")
        return template.compile(view, cache_key, plain)(context)
    end

    function template.process_file(view, context, cache_key)
        assert(view, "view was not provided for template.process_file(view, context, cache_key)")
        return template.compile(view, cache_key, false)(context)
    end

    function template.process_string(view, context, cache_key)
        assert(view, "view was not provided for template.process_string(view, context, cache_key)")
        return template.compile(view, cache_key, true)(context)
    end

    function template.render(view, context, cache_key, plain)
        assert(view, "view was not provided for template.render(view, context, cache_key, plain)")
        template.print(template.process(view, context, cache_key, plain))
    end

    function template.render_file(view, context, cache_key)
        assert(view, "view was not provided for template.render_file(view, context, cache_key)")
        template.render(view, context, cache_key, false)
    end

    function template.render_string(view, context, cache_key)
        assert(view, "view was not provided for template.render_string(view, context, cache_key)")
        template.render(view, context, cache_key, true)
    end

    if safe then
        return setmetatable({}, {
            __index = function(_, k)
                if type(template[k]) == "function" then
                    return function(...)
                        local ok, a, b = pcall(template[k], ...)
                        if not ok then
                            return nil, a
                        end
                        return a, b
                    end
                end
                return template[k]
            end,
            __new_index = function(_, k, v)
                template[k] = v
            end,
        })
    end

    return template
end

return new()