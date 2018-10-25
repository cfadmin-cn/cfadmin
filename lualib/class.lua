-- a minimal class implementation
-- 一个精简版的类实现
function class(cls_name)
    local cls = {}
    cls.__name = cls_name
    cls.__index = cls
    cls.__call = function (cls, ...)
        if cls[cls_name] and type(cls[cls_name]) == "function" then
            return cls[cls_name](cls, ...)
        end
        local BaseClass = getmetatable(cls)
        if BaseClass and type(BaseClass[cls_name]) == "function" then
            return BaseClass[cls_name](cls, ...)
        end
    end
    cls.new = function (cls, ... )
        if not cls then
            return print("[class.lua][line:13]: Please use ':'' to index (new) method :)")
        end
        cls.__index = cls
        cls.ctor(cls, ...)
        return setmetatable({}, cls)
    end
    return cls
end

return class