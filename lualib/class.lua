-- a minimal class implementation

-- 一个精简版的类实现

function class(cls_name)
	return {
		__name = cls_name,
		ctor = function (cls, ... )
			-- nothing to do 
		end,
		new = function (cls, ... )
			if not cls then
				return print("[class.lua][line:13]: Please use ':'' to index (new) method :)")
			end
			cls.ctor(cls, ...)
			return setmetatable(cls, {})
		end,
	}
end

return class