local wb = require "webhook.dingtalk"
local LOG = require "logging"

-- dingtalk API文档: https://ding-doc.dingtalk.com/doc#/serverapi2/qf2nxq

local token = "just_your_token_not_url_and_token" -- such as "de2b0b8a3c4b8d454f47584354a794a12657aa9ff7ccf36b521368d566949e7f"

LOG:DEBUG(wb.send_text({
	token = token,
	content = "一条测试消息哦.",
  -- ignore mobiles if atall equal true.
	-- mobiles = {18680684684, 13000000000},
	-- atall = true,
}))

LOG:DEBUG(wb.send_link {
	token = token,
	msg_title = "这是一条测试公告",
	msg_link = "https://github.com/candymi",
	-- optional
	msg_pic = "https://avatars2.githubusercontent.com/u/13453599",
	msg_describe = "这是测试公告的描述信息, 它描述了这条公告的一些外链关键内容.",
})

LOG:DEBUG(wb.send_actioncard{
	token = token,
	msg_title = "## 消息头部",
	msg_describe = "## 消息内容",
	single = {
		title = "阅读全文",
		url = "https://www.baidu.com"
	}
})

LOG:DEBUG(wb.send_actioncard{
	token = token,
	-- 头部
	msg_title = "## 消息头部",
	-- 描述
	msg_describe = "## 消息内容",
	-- 隐藏机器人头像
	hide_avatar = true,
	-- 设置按钮
	btns = {
		{ title = "按钮1", url = "https://www.qq.com" },
		{ title = "按钮2", url = "https://www.baidu.com" },
		{ title = "点赞支持", url = "https://www.163.com" },
		{ title = "残忍关闭", url = "https://www.taobao.com" }
	}
})

LOG:DEBUG(wb.send_feedcard {
	token = token,
	msg_links = {
		{
			msg_title = "第1个公告", msg_link  = "https://www.baidu.com",
			-- msg_pic   = "https://avatars2.githubusercontent.com/u/13453599" -- optional
		},
		{
			msg_title = "第2个公告", msg_link  = "https://www.qq.com",
			-- optional
			-- msg_pic   = "https://avatars2.githubusercontent.com/u/13453599"
		}
	}
})
