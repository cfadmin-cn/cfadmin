local z = require "lz"

local LOG = require "logging"

local text = [[

  Lua 轻量级网络开发框架(A lua Lightweight Network Development Framework)

  生态多 —— 集成社区库最多的框架之一, 并自行实现了一些网络协议生态.

  Multi-ecology —— Integrate most community third-party libraries and implement many protocols on their own.

  稳定性好 —— 许多领域的企业已经开始使用，并且用户数量也在逐渐增加.

  Good stability —— Enterprises in many fields have begun to use, and users are gradually increasing.

  高效率 —— 高效的静态语言与高效的虚拟机实现优秀的运行时框架.

  High efficiency - Efficient static language and efficient virtual machine to achieve excellent runtime framework.

  高可维护性 —— 通俗易懂的框架编写方式可以让开发者快速适应并且上手.

  High readability —— The easy-to-understand framework writing method allows developers to quickly adapt and get started.

  《运行》

  cf框架在整体构建完毕后会在项目根目录产生一个可执行文件: cfadmin, 它会根据当前目录环境执行对应的入口文件(script/main.lua).

  《命令与参数》

  ./cfadmin, 前台执行; 使用ctrl + z、ctrl + c、ctrl + \等组合键就能让它停止执行.

  ./cfadmin -d, 后台执行; 通常你需要使用killall cfadmin与kill -9 PID这样的命令才能终止它.

  《选择合适的运行方式》

  cf默认情况下会将日志输出在stdout. 在开发与测试期间通常会前台运行, 这样无论是打印日志还是定位问题都会变得较为简单.

  如果您将cf放置在容器内部, 前台运行通常会是一个比较好的选择. 有利于贴合容器日志生态, 合理配合日志收集器做集中式日志检索与管理.

  如果您将cf放置到原生系统下, 建议将cf至于后台运行.

]]

local cp_text = z.compress(text)

local raw_text = z.uncompress(cp_text)

assert(raw_text == text, "测试LZ77压缩/解压方法失败")

LOG:DEBUG("compress压缩前的文本长度为:" .. #raw_text, "压缩后的文本长度为:" .. #cp_text)

-- 分割线 ---

local cp_text = z.compress2(text)

local raw_text = z.uncompress2(cp_text)

assert(raw_text == text, "测试gzip压缩/解压失败")

LOG:DEBUG("compress2压缩前的文本长度为:" .. #raw_text, "压缩后的文本长度为:" .. #cp_text)

-- 分割线 ---

local cp_text = z.gzcompress(text)

local raw_text = z.gzuncompress(cp_text)

assert(raw_text == text, "测试gzip压缩/解压失败")

LOG:DEBUG("gzcompress压缩前的文本长度为:" .. #raw_text, "压缩后的文本长度为:" .. #cp_text)