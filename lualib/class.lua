-- a minimal class implementation
-- 一个精简版的类实现
local log = require 'log'
function class(cls_name)
    local cls = { }
    cls.__index = cls
    cls.__name = cls_name
    cls.__call = function (cls, ...)
        if cls[cls.__name] then
            return cls[cls.__name](cls, ...)
        end
        return nil
    end
    cls.new = function (c, ...)
        if cls ~= c then
            log.error("Please use ':' to index (new) method :)")
            return
        end
        local t = {}
        if not c.ctor then
            log.error("Can't Find ctor to init.")
        else
            c.ctor(t, ...)
        end
        return setmetatable(t, c)
    end
    return cls
end

return class