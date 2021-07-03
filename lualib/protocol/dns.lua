local UDP = require "internal.UDP"

local sys = require "sys"
local log = require "logging"
local Log = log:new({ dump = true, path = 'protocol-dns'})

local cf = require "cf"
local cf_fork = cf.fork
local cf_self = cf.self
local cf_wait = cf.wait
local cf_wakeup = cf.wakeup
local cf_sleep = cf.sleep

local new_tab = sys.new_tab
local check_ipv4 = sys.ipv4
local check_ipv6 = sys.ipv6

local LIMIT_HEADER_LEN = 12
local MAX_THREAD_ID = 65535

local concat = table.concat
local insert = table.insert

local now = os.time
local random = math.random
local lower = string.lower
local fmt = string.format
local find = string.find
local match = string.match
local splite = string.gmatch
local pack = string.pack
local unpack = string.unpack

local type = type
local ipairs = ipairs

local prefix = '::ffff:'

local dns = {}

local QTYPE = {
  A = 1,
  AAAA = 28,
}

local dns_cache = {}

local dns_list = {}

local thread_id = 0

local function gen_id()
  thread_id = thread_id % MAX_THREAD_ID + 1
  return thread_id
end

local function check_cache(domain)
  local query = dns_cache[domain]
  if not query then
    return
  end
  local ttl = query.ttl
  if not ttl then
    return query.ip
  end
  if ttl > now() then
    return query.ip
  end
  dns_cache[domain] = nil
  return
end

local function add_cache(domain, ip)
  dns_cache[domain] = { ip = ip }
end

local function check_ip(ip)
  if type(ip) == 'string' and ip ~= '' then
    if check_ipv4(ip) then
      return true, 4
    end
    if check_ipv6(ip) then
      return true, 6
    end
  end
  return false, "Not a valid IP address."
end

local function gen_cache()
    local file = io.open("/etc/hosts", "r")
    if file then
      for line in file:lines() do
        if not find(line, "^([%G]*)#") then
          local ip, domain = match(line, '([^#%G]*)[%G]+(.+)')
          local ok, v = check_ip(ip)
          if ok then
            for d in splite(domain or '', "([^ ]+)") do
              dns_cache[d] = { ip = v == 4 and prefix .. ip or ip }
            end
          end
        end
      end
      file:close()
    end
    if not dns_cache['localhost'] then
      dns_cache['localhost'] = {ip = prefix..'127.0.0.1'}
    end
end

if #dns_list < 1 then
  local file = io.open("/etc/resolv.conf", "r")
  if file then
    for line in file:lines() do
      if not find(line, "^[ ]*#.-") then
        local ip = match(line, "nameserver ([^ ]+)$")
        local ok, v = check_ip(ip)
        if ok and v then
          insert(dns_list, ip)
        end
      end
    end
    file:close()
  end
  if #dns_list < 1 then
    dns_list = {"1.2.4.8", "210.2.4.8"}
  end
  gen_cache()
end

local function get_dns_client(ip_version)
  if #dns_list >= 1 then
    local udp = UDP:new():timeout(dns._timeout or 30)
    local ip = dns_list[random(1, #dns_list)]
    local _, v = check_ip(ip)
    if v == 4 then
      ip = prefix .. ip
    end
    local ok = udp:connect(ip, 53)
    if not ok then
      return nil, 'Create UDP Socket error.'
    end
    if ip_version then
      v = ip_version
    end
    return udp, v
  end
  return nil, "Can't find system dns in /etc/resolve.conf."
end

local function pack_header()
    local tid = gen_id()
    local flag = 0x120
    local QCOUNT = 1
    -- QCount 永远是1, flags 永远是288
    return pack(">HHHHHH", tid, flag, QCOUNT, 0, 0, 0)
end

local function pack_question(name, version)
    -- local Query_Type  = QTYPE.A -- IPv4
    -- local Query_Type  = QTYPE.AAAA -- IPv6
    local Query_Type = version == 6 and QTYPE.AAAA or QTYPE.A
    local Query_Class = 0x01 -- IN internet
    local question = {}
    for sp in splite(name, "([^%.]*)") do
      insert(question, pack(">s1", sp))
    end
    insert(question, "\0")
    insert(question, pack(">HH", Query_Type, Query_Class))
    return concat(question)
end

local function unpack_header(chunk)
  local tid, flags, qdcount, ancount, _, _, nbyte = unpack(">HHHHHH", chunk)
  return { tid = tid, flags = flags, qdcount = qdcount, ancount = ancount}, nbyte
end

local function unpack_name(chunk, nbyte)
    local domain = {}
    local jump_pointer
    local tag, offset, label
    while true do
      tag, nbyte = unpack(">B", chunk, nbyte)
      if tag & 0xc0 == 0xc0 then
        offset,nbyte = unpack(">H", chunk, nbyte - 1)
        offset = offset & 0x3fff
        if not jump_pointer then
            jump_pointer = nbyte
        end
        nbyte = offset + 1
      elseif tag == 0 then
        break
      else
        label, nbyte = unpack(">s1", chunk, nbyte - 1)
        domain[#domain+1] = label
      end
    end
    return concat(domain, "."), jump_pointer or nbyte
end

local function unpack_question(chunk, nbyte)
    local name, nbyte = unpack_name(chunk, nbyte)
    local atype, aclass, nbyte = unpack(">HH", chunk, nbyte)
    return {atype = atype, aclass = aclass, name = name}, nbyte
end

local function unpack_answer(chunk, nbyte)
    local name, nbyte = unpack_name(chunk, nbyte)
    local atype, class, ttl, rdata, nbyte = unpack(">HHI4s2", chunk, nbyte)
    return { name = name, atype = atype, class = class, ttl = ttl, rdata = rdata }, nbyte
end

local function unpack_rdata(chunk, qtype)
  return qtype == QTYPE.AAAA and fmt('%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x', unpack(">HHHHHHHH", chunk)) or fmt("%u.%u.%u.%u", unpack(">BBBB", chunk))
end

local cos = {}

-- 如果有其它协程也在等待查询, 那么一起唤醒它们
local function check_wait(domain, wlist, ...)
  for _, w in ipairs(wlist) do
    cf_wakeup(w, ...)
  end
  cos[domain] = nil
end

local function dns_query(domain, ip_version)
  local wlist = new_tab(32, 0)
  cos[domain] = wlist
  local dns_client, msg = get_dns_client(ip_version)
  if not dns_client then
    check_wait(domain, wlist, nil, msg)
    return nil, msg
  end
  local responsed = false
  cf_fork(function ()
    local req = pack_header() .. pack_question(domain, msg)
    while not responsed do
      for _ = 1, 10 do
        -- 用数量来减少UDP丢包率的问题
        dns_client:send(req); dns_client:send(req); dns_client:send(req); cf_sleep(0.1)
        if responsed then
          return
        end
      end
      Log:WARN("Attempt to resolve domain name: [" .. domain .. "] failed.")
    end
  end)
  local dns_resp, len = dns_client:recv(); dns_client:close(); responsed = true;
  if not dns_resp or not len or len < LIMIT_HEADER_LEN then
    local err = "1. Malformed message length."
    check_wait(domain, wlist, nil, err)
    return nil, err
  end
  local answer_header, nbyte = unpack_header(dns_resp)
  if answer_header.qdcount ~= 1 then
    local err = "2. Malformed message response."
    check_wait(domain, wlist, nil, err)
    return nil, err
  end
  local ancount = answer_header.ancount
  if not ancount or ancount < 1 then
    if not ip_version then -- 如果IPv4无法解析则尝试ipv6, 反之亦然.
      return dns_query(domain, msg == 4 and 6 or 4)
    end
    local err = "3. Unresolved domain name."
    check_wait(domain, wlist, nil, err)
    return nil, err
  end
  local question
  question, nbyte = unpack_question(dns_resp, nbyte)
  if lower(question.name) ~= lower(domain) then
    local err = "4. Inconsistent query domain. " .. question.name
    check_wait(domain, wlist, nil, err)
    return nil, err
  end
  local answer
  local t = now()
  for _ = 1, ancount do
    answer, nbyte = unpack_answer(dns_resp, nbyte)
    if answer.atype == QTYPE.A or answer.atype == QTYPE.AAAA then
      answer.ip = unpack_rdata(answer.rdata, answer.atype)
      local cache = dns_cache[domain]
      if not cache then
        dns_cache[domain] = {ip = answer.ip, ttl = answer.ttl > 0 and (t + answer.ttl) or nil }
      elseif cache.ttl and cache.ttl < t + answer.ttl then
        dns_cache[domain] = {ip = answer.ip, ttl = t + answer.ttl}
      end
    end
  end
  answer = dns_cache[domain]
  if not answer then
    if not ip_version then -- 如果IPv4无法解析则尝试ipv6, 反之亦然.
      return dns_query(domain, msg == 4 and 6 or 4)
    end
    local err = "5. (" .. (domain) .. ") query failed."
    check_wait(domain, wlist, nil, err)
    return nil, err
  end
  local ip = answer.ip
  local _, v = check_ip(ip)
  if v == 4 then
    ip = prefix..ip
    answer.ip = ip
  end
  check_wait(domain, wlist, true, ip)
  return true, ip
end

function dns.flush()
  dns_cache = {}
  gen_cache()
end

-- 这里设置每个dns查询请求的timeout与retry时间
function dns.timeout(timeout)
  dns._timeout = timeout
end

function dns.resolve(domain, ip_version)
  -- 检查参数是否有效
  if type(domain) ~= 'string' or domain == '' then
    return nil, "attempt to pass an invalid domain."
  end
  -- 如果有dns缓存直接返回, 任何依据都要以缓存为主
  local ip = check_cache(domain)
  if ip then
    if check_ipv6(ip) then
      return true, ip
    end
    return true, prefix..ip
  end
  -- 如果是正确的ipv4地址直接返回
  local ok, v = check_ip(domain)
  if ok then
    -- 缓存IP->IP的映射, 减少查表与字符串连接次数.
    -- 这样可以降低大量的内存与CPU的使用.
    if 6 == v then
      add_cache(domain, domain)
      return ok, domain
    end
    add_cache(domain, prefix..domain)
    return ok, prefix..domain
  end
  -- 如果有其他协程也正巧在查询这个域名, 那么就加入到等待列表内
  local wlist = cos[domain]
  if wlist then
    local co = cf_self()
    insert(wlist, co)
    return cf_wait()
  end
  return dns_query(domain, ip_version)
end
-- require "utils"
-- var_dump(dns_cache)
-- var_dump(dns_list)
return dns
