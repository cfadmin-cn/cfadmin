local class = require "class"


local r2 = class("r2")

function r2:ctor(opt)
    
end

function r2:get()
    return 'this request build-in '..self.__name
end

return r2