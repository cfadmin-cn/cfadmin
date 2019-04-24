local xml2lua = require "xml2lua"
require "utils"

local xml = [[
<xml>
	<Tiger id="1">
		<name type="text">老虎</name>
		<food>meta</food>
	</Tiger>
	<Lion id="2">
		<name>狮子</name>
		<food>meta</food>
	</Lion>
	<People>
		<man cn="男人">
			<item>水果糖</item>
			<item>車先生</item>
		</man>
		<woman cn="女人">
			<dream>
				<item>买买买</item>
				<item>玩玩玩</item>
				<item>逛逛逛</item>
			</dream>
			<item>肉肉</item>
			<item>小宝贝</item>
			<item>小QQ</item>
			<item>車爪鱼</item>
		</woman>
	</People>
	<Et/>
</xml>
]]

-- benchmark time: ./cfadmin 耗时:3.6xx/Sec
for i = 1, 10000 do
	xml2lua.parser(xml)
end

-- 打印解析后的表结构
local tab = xml2lua.parser(xml)
var_dump(tab)

-- 原版xml2lua打印会出现相等的情况
-- 这在cf中可能导致不可预知的情况.
local tab1 = xml2lua.parser(xml)
local tab2 = xml2lua.parser(xml)
print(tab1, tab2)
