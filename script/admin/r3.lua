local class = require "class"


local r3 = class("r3")

function r3:ctor(opt)
    
end

function r3:get()
    return 'this request build-in '..self.__name
end

return r3