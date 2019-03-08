local UDP = require "internal.UDP"
local co = require "internal.Co"
local sys = require "sys"
local log = require "log"

local prefix = '::ffff:'

local co_self = co.self
local co_wait = co.wait
local co_wakeup = co.wakeup

local check_ipv4 = sys.ipv4
local check_ipv6 = sys.ipv6

local LIMIT_HEADER_LEN = 12
local MAX_THREAD_ID = 65535

local concat = table.concat
local insert = table.insert

local now = os.time
local fmt = string.format
local match = string.match
local splite = string.gmatch
local pack = string.pack
local unpack = string.unpack
local type = type

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
    if query then
        if not query.ttl or query.ttl > now() then
            return query.ip
        end
        dns_cache[domain] = nil
    end
    return
end

local function check_ip(ip)
    if ip then
        if check_ipv4(ip) then
            return true, 4
        end
        if check_ipv6(ip) then
            return true, 6
        end
    end
end

local function gen_cache()
    local file = io.open("/etc/hosts", "r")
    dns_cache['localhost'] = {ip = '::1'}
    if file then
        for line in file:lines() do
            local ip, domain = match(line, '([^# %t]*)[%t ]*(.*)$')
            local ok, v = check_ip(ip)
            if ok then
                if v == 4 then
                    if not dns_cache[domain] then
                        dns_cache[domain] = {ip = prefix..ip}
                    end
                else
                    if not dns_cache[domain] then
                        dns_cache[domain] = {ip = ip}
                    end
                end
            end
        end
        file:close()
    end
end

if #dns_list < 1 then
    local file = io.open("/etc/resolv.conf", "r")
    if file then
        for line in file:lines() do
            local ip = match(line, "nameserver (.-)$")
            local ok = check_ip(ip)
            if ok then
                insert(dns_list, ip)
            end
        end
        file:close()
    end
    if #dns_list < 1 then
        dns_list = {"114.114.114.114", "8.8.8.8"}
    end
    gen_cache()
end

local function get_dns_client()
    if #dns_list >= 1 then
        local ip = dns_list[1]
        local udp = UDP:new():timeout(dns._timeout or 5)
        local ok, v = check_ip(ip)
        if v == 4 then
            ip = prefix..ip
        end
        local ok = udp:connect(ip, 53)
        if not ok then
            return nil, 'Create UDP Socket error.'
        end
        return udp, v
    end
    return nil, "Can't find system dns in /etc/resolve.conf."
end

local function pack_header()
    local tid = gen_id()
    local flag = 0x100
    local QCOUNT = 1
    -- QCount 永远是1, flags 永远是256
    return pack(">HHHHHH", tid, flag, QCOUNT, 0, 0, 0)
end

local function pack_question(name, version)
    -- local Query_Type  = QTYPE.A -- IPv4
    -- local Query_Type  = QTYPE.AAAA -- IPv6
    local qtype = QTYPE.A
    if version == 6 then
        qtype = QTYPE.AAAA
    end
    local Query_Type  = qtype
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
    local tid, flags, qdcount, ancount, nscount, arcount, nbyte = unpack(">HHHHHH", chunk)
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
    if qtype == QTYPE.AAAA then
        return fmt('%x:%x:%x:%x:%x:%x:%x:%x', unpack(">HHHHHHHH", chunk))
    end
    return fmt("%d.%d.%d.%d", unpack(">BBBB", chunk))
end


local cos = {}

local function dns_query(domain)
    local wlist = {}
    cos[domain] = wlist
    -- local start = os.time() + os.clock()
    -- print("开始解析域名:["..domain.."], 开始时间: ", start)
    local dns_resp, len
    local dns_client, msg = get_dns_client()
    if not dns_client then
        dns_client:close()
        return nil, msg
    end
    local header = pack_header()
    local question = pack_question(domain, msg)
    while 1 do   -- 如果一直没收到回应将会反复请求
        dns_client:send(header..question)
        dns_resp, len = dns_client:recv()
        if dns_resp then
            dns_client:close()
            dns_client = nil
            break
        end
        if type(len) == "string" then
            log.info("正在解析["..domain.."]:"..len)
        end
    end
    if not len or len < LIMIT_HEADER_LEN then
        local err = "Malformed dns response package."
        return nil, err
    end
    local answer_header, nbyte = unpack_header(dns_resp)
    if answer_header.qdcount ~= 1 then
        local err = "Malformed dns response package."
        return nil, err
    end
    if not answer_header.ancount or answer_header.ancount < 1 then
        local err = "Can't find ip addr in nameserver."
        return nil, err
    end
    local question, nbyte = unpack_question(dns_resp, nbyte)

    if question.name ~= domain then
        local err = "quetions not equal."
        return nil, err
    end
    local answer
    for i = 1, answer_header.ancount do
        answer, nbyte = unpack_answer(dns_resp, nbyte)
        if answer.atype == QTYPE.A or answer.atype == QTYPE.AAAA then
            answer.ip = unpack_rdata(answer.rdata, answer.atype)
            dns_cache[domain] = {ip = answer.ip, ttl = now() + answer.ttl}
        end
    end
    local ok, v = check_ip(answer.ip)
    if not ok then
        return nil, "unknown ip in this domain: "..domain
    end
    if ok and v == 4 then
        answer.ip = prefix..answer.ip
    end
    -- local e_n_d = os.time() + os.clock()
    -- print("解析域名["..domain.."]完成, 结束时间:", e_n_d, ip, answer.ttl)
    -- print("解析域名用时: ", tostring(e_n_d - start)..'s')
    for i = #wlist, 1, -1 do
        -- 如果有其它协程也在等待查询, 那么一起唤醒它们
        co_wakeup(wlist[i], true, answer.ip)
    end
    cos[domain] = nil
    return true, answer.ip
end

function dns.flush()
    dns_cache = {}
    gen_cache()
end

-- 这里设置每个dns查询请求的timeout与retry时间
function dns.timeout(timeout)
    dns._timeout = timeout
end

function dns.resolve(domain)
    -- 如果传进来一个空值, 则直接返回false
    if not domain or domain == '' then
        return nil, "attemp to resolve a nil or empty host name."
    end
    -- 如果是正确的ipv4地址直接返回
    local ok, v = check_ip(domain)
    if ok then
        if 6 == v then
            return ok, domain
        end
        return ok, prefix..domain
    end
    -- 如果有dns缓存直接返回
    local ip = check_cache(domain)
    if ip then
        if check_ipv6(ip) then
            return true, ip
        end
        return true, prefix..ip
    end
    -- 如果有其他协程也正巧在查询这个域名, 那么就加入到等待列表内
    local wlist = cos[domain]
    if wlist then
        local co = co_self()
        insert(wlist, co)
        return co_wait()
    end
    return dns_query(domain)
end
-- require "utils"
-- var_dump(dns_cache)
return dns