-- 0m0.190s
local t = {}
local insert = table.insert
for i = 1, 10000000 do
    insert(t, i)
end

-- 0m1.359s
local t = {}
for i = 1, 10000000 do
    t[#t+1] = i
end

-- 0m0.666s
local t = {}
local insert = table.insert
for i = 1, 10000 do
    insert(t, 1, i)
end
