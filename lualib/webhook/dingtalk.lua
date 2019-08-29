local httpc = require "httpc"
local json = require "json"

local class = require "class"

local type = type
local ipairs = ipairs

local function check_error (code, response)
  if code ~= 200 then
    return nil, "请求失败." .. (response or "")
  end
  local r = json.decode(response)
  if type(r) ~= 'table' then
    return nil, "未知的回应."
  end
  if r.errcode ~= 0 then
    return nil, r.errmsg
  end
  return true
end

local dingtalk = { __VERSION__ = 0.1, robot = "https://oapi.dingtalk.com/robot/send?access_token=" }

-- 发送text消息
function dingtalk.send_text (opt)
  assert(type(opt) == 'table', "dingtalk error: 无效的参数.")
  assert(type(opt.token) == 'string' and opt.token ~= '', "dingtalk error: 无效的Token参数.")
  assert(type(opt.content) == 'string' and opt.content ~= '', "dingtalk error: 无效的content参数.")
  local allmobiles = {}
  if type(opt.mobiles) == 'table' then
    for _, phone in ipairs(opt.mobiles) do
      allmobiles[#allmobiles+1] = tostring(phone)
    end
  end
  local code, response = httpc.json(dingtalk.robot..opt.token, nil, json.encode({ msgtype = "text", text = { content = opt.content }, at = { atMobiles = allmobiles, isAtAll = opt.atall == true} }))
  return check_error(code, response)
end

-- 发送link消息
function dingtalk.send_link (opt)
  assert(type(opt) == 'table', "dingtalk error: 无效的参数.")
  assert(type(opt.token) == 'string' and opt.token ~= '', "dingtalk error: 无效的Token参数.")
  assert(type(opt.msg_link) == 'string' and opt.msg_link ~= '', "dingtalk error: 无效的msg_link(必须为非空字符串).")
  assert(type(opt.msg_title) == 'string' and opt.msg_title ~= '', "dingtalk error: 无效的msg_title(必须为非空字符串).")
  assert(type(opt.msg_describe) == 'string' and opt.msg_describe ~= '', "dingtalk error: 无效的msg_describe(必须为非空字符串).")
  local code, response = httpc.json(dingtalk.robot..opt.token, nil, json.encode({ msgtype = "link", link = { title = opt.msg_title, text = opt.msg_describe, messageUrl = opt.msg_link, picUrl = opt.msg_pic } }))
  return check_error(code, response)
end

-- 发送markdown消息
function dingtalk.send_markdown (opt)
  assert(type(opt) == 'table', "dingtalk error: 无效的参数.")
  assert(type(opt.token) == 'string' and opt.token ~= '', "dingtalk error: 无效的Token参数.")
  assert(type(opt.msg_title) == 'string' and opt.msg_title ~= '', "dingtalk error: 无效的msg_title(必须为非空字符串).")
  assert(type(opt.msg_content) == 'string' and opt.msg_content ~= '', "dingtalk error: 无效的msg_content(必须为非空字符串).")

  local allmobiles = {}
  if type(opt.mobiles) == 'table' then
    for _, phone in ipairs(opt.mobiles) do
      allmobiles[#allmobiles+1] = tostring(phone)
    end
  end
  local code, response = httpc.json(dingtalk.robot..opt.token, nil, json.encode({
    msgtype = "markdown", markdown = { title = opt.msg_title, text = opt.msg_content }, at = { atMobiles = opt.mobiles, isAtAll = opt.atall == true }
  }))
  return check_error(code, response)
end

-- 发送actionCard消息
function dingtalk.send_actioncard (opt)
  assert(type(opt) == 'table', "dingtalk error: 无效的参数.")
  assert(type(opt.token) == 'string' and opt.token ~= '', "dingtalk error: 无效的Token参数.")
  assert(type(opt.msg_title) == 'string' and opt.msg_title ~= '', "dingtalk error: 无效的msg_title(必须为非空字符串).")
  assert(type(opt.msg_describe) == 'string' and opt.msg_describe ~= '', "dingtalk error: 无效的msg_describe(必须为非空字符串).")

  local btns, single_title, single_url = nil, nil, nil
  if type(opt.single) == 'table' and (type(opt.single.title) == 'string' and opt.single.title ~= '') and (type(opt.single.url) == 'string' and opt.single.url ~= '') then
    single_title, single_url = opt.single.title, opt.single.url
  end

  if not single_title and not single_url and type(opt.btns) == 'table' and #opt.btns >= 1 then
    btns = {}
    for index, btn in ipairs(opt.btns) do
      assert(type(btn.title) == 'string' and btn.title ~= '', 'dingtalk error: btns第'..index..'个参数title无效.')
      assert(type(btn.url) == 'string' and btn.url ~= '', 'dingtalk error: btns第'..index..'个参数url无效.')
      btns[#btns+1] = {title = btn.title, actionURL = btn.url}
    end
  end

  local code, response = httpc.json(dingtalk.robot..opt.token, nil, json.encode({ msgtype = "actionCard", actionCard = { title = opt.msg_title, text = opt.msg_describe, singleURL = single_url, singleTitle = single_title, btns = btns, hideAvatar = opt.hide_avatar and '1' or '0', btnOrientation = opt.btn_orientation and '1' or '0' }}))
  return check_error(code, response)
end

-- 发送FeedCard消息
function dingtalk.send_feedcard (opt)
  assert(type(opt) == 'table', "dingtalk error: 无效的参数.")
  assert(type(opt.token) == 'string' and opt.token ~= '', "dingtalk error: 无效的Token参数.")
  assert(type(opt.msg_links) == 'table' and #opt.msg_links >= 1, "dingtalk error: 无效的msg_links参数(内部至少有一条消息).")
  local links = {}
  for index, link in ipairs(opt.msg_links) do
    assert(type(link) == 'table', "dingtalk error: 无效的消息"..index)
    assert(type(link.msg_title) == 'string' and link.msg_title ~= '', "dingtalk error: 第"..index..'个消息的msg_title无效.')
    assert(type(link.msg_link) == 'string' and link.msg_link ~= '', "dingtalk error: 第"..index..'个消息的msg_link无效.')
    links[#links+1] = { title = link.msg_title, messageURL = link.msg_link, picURL = link.msg_pic }
  end
  local code, response = httpc.json(dingtalk.robot..opt.token, nil, json.encode({ msgtype = "feedCard", feedCard = { links = links } }))
  return check_error(code, response)
end

return dingtalk
