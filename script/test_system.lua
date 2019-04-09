local System = require "system"

print("判断是否string类型?", System.is_string("admin"), System.is_string(1))
print("空字符串是string类型么?", System.is_string(""))
print("如果加了第二个参数后, 空字符串还是string类型么?", System.is_string("", true))

print("判断是否整数(int/long)类型?", System.is_int(100.0), math.maxinteger)

print("判断是否浮点(float)类型?", System.is_float(100.1), math.maxinteger)

print("判断字符串是否合法IP地址?", System.is_ip("0.0.0."))
print("判断字符串是否ipv4地址?", System.is_ipv4("1.1.1.1"))
print("判断字符串是否ipv6地址?", System.is_ipv6("::1"))

-- 微秒级时间返回
print(string.format("%0.6f", System.now()))

local array = {1, 2, 3, 4}

print("1 是否在array 中.", System.is_array_member(array, 1))
print("10 是否在array 中.", System.is_array_member(array, 10))

local tab = {a = 'a', b = 'b', c = 'c'}
print("a 是否在table 中.", System.is_table_member(tab, 'a'))
print("z 是否在table 中.", System.is_table_member(tab, 'z'))


print("查看今天凌晨与午夜的时间戳:", System.same_day())
print("查看今天凌晨与午夜的时间戳:", System.same_day(os.time()))
print("查看昨天凌晨与午夜的时间戳:", System.same_day(os.time() - 86400))
