-- a minimal class implementation
-- 一个精简版的类实现
function class(cls_name)
    local cls = { }
    cls.__name = cls_name
    -- cls.__index = cls
    cls.__call = function (cls, ...)
        local call = cls[cls.__name]
        if call then
            return call(cls, ...)
        end
        return
    end
    cls.new = function (c, ...)
        if cls ~= c then
            return print("Please use ':' to create new object :)")
        end
        local t = {}
        if not c.ctor then
            print("Can't find ctor to init.")
        else
            c.ctor(t, ...)
        end
        return setmetatable(t, {__index = cls})
    end
    return cls
end

return class