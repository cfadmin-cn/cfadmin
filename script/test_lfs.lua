local Log = require "logging":new()

local lfs = require "lfs"

-- Log:DEBUG(lfs)

local function list_logs_files ()
	local logs = {}
	for filename in lfs.dir("logs") do
		-- mode为"directory"表示为目录, mode为"file"表示文件
		if lfs.attributes(filename).mode == "file" then
			logs[#logs+1] = filename
		end
	end
	return logs
end

local function change_dir (dir)
	local old = "将当前目录路径["..lfs.currentdir().."]修改为"
	lfs.chdir(lfs.currentdir()..dir)
	local new = "["..lfs.currentdir().."]"
	return old..new
end

Log:DEBUG("lfs版本为:"..lfs._VERSION)

Log:DEBUG(change_dir("/src"))

Log:DEBUG(change_dir("/../"))

Log:DEBUG("查看LICENSE文件属性:", lfs.attributes("LICENSE"))

Log:DEBUG("创建test文件夹:", lfs.mkdir("test"))

Log:DEBUG("删除test文件夹:", lfs.rmdir("test"))

Log:DEBUG("列出logs文件夹目录", list_logs_files())
