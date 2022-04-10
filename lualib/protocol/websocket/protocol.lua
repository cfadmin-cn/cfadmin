local crypt = require "crypt"
local xor_str = crypt.xor_str

local lz = require "lz"
local wscompress = lz.wscompress
local wsuncompress = lz.wsuncompress

local new_tab = require("sys").new_tab

local error = error
local assert = assert

local strpack = string.pack
local strunpack = string.unpack
local random = math.random
local concat = table.concat
local insert = table.insert

local WS_TYPE = {
  [0x00] = "continuation",
  [0x01] = "text",
  [0x02] = "binary",
  [0x08] = "close",
  [0x09] = "ping",
  [0x0A] = "pong",
}

local function sock_recv (sock, bytes)
  local buf = sock:readbytes(bytes)
  if not buf then
    sock.closed = true
  end
  return buf
end

local function sock_send (sock, data)
  return sock:write(data)
end

local function wsdeflate(data)
  return wscompress(data)
end

local function wsinflate(data)
  return wsuncompress(data)
end


local protocol = { __VERSION__ = 0.1 }

---@comment 接收数据
---@param sock             table    @socket对象
---@param max_payload_len  integer  @最大长度限制
---@param force_masking    boolean  @强制检查掩码
---@param buffers          table    @内部的缓冲区
---@return   string    @消息数据
---@return   string    @消息类型
---@return   string    @错误信息
function protocol.recv_frame(sock, max_payload_len, force_masking, buffers)
  local hdata = sock_recv(sock, 2)
  if not hdata then
    return false, 'close'
  end

  local h1, h2 = strunpack("BB", hdata)
  -- 检查协议头部是否符合规范
  local fin, rsv = h1 & 0x80 == 0x80, (h1 >> 4) & 0x07
  if rsv ~= 0x00 and rsv ~= 0x04 then
    return false, 'error', "[WS ERROR] : Invalid RSV1 or RSV2 or RSV3."
  end

  -- 检查 OPCODE 是否有效
  local opcode = WS_TYPE[h1 & 0x0F]
  if not opcode then
    return false, 'error', "[WS ERROR] : received Invalid opcode."
  end

  -- 判断数据载荷的实际长度
  local plen = h2 & 0x7F
  if plen == 126 then
    local body_size_str = sock_recv(sock, 2)
    if not body_size_str then
      return false, 'error', "[WS ERROR] : Client Close this session when read 2 bytes body size."
    end
    plen = strunpack(">I2", body_size_str)
  elseif plen == 127 then
    local body_size_str = sock_recv(sock, 8)
    if not body_size_str then
      return false, 'error', "[WS ERROR] : Client Close this session when read 8 bytes body size."
    end
    plen = strunpack(">I8", body_size_str)
  end

  local mask_key = nil
  -- 如果最高位是1表明PAYLOAD有掩码位.
  if h2 & 0x80 == 0x80 then
    mask_key = sock_recv(sock, 4)
    if not mask_key then
      return false, 'error', "[WS ERROR] : Client Close this session when read mask_key data."
    end
  end

  -- 如果强制要求但是还是未检查
  if force_masking and not mask_key then
    return false, 'error', "[WS ERROR] : Mask must be present."
  end

  -- 需要提前断言数据长度是否超出限制
  if plen >= max_payload_len then
    return false, 'error', "[WS ERROR] : Content exceeding the length limit."
  end

  -- 控制帧必须不允许有扩展长度
  if (opcode == 'close' or opcode == 'ping' or opcode == 'pong') and plen > 125 then
    return false, 'error', "[WS ERROR] : The payload length of the control frame is too long."
  end

  local data = ""

  -- 读取数据载荷
  if plen > 0 then

    data = sock_recv(sock, plen)
    if not data then
      return false, 'error', "[WS ERROR] : Client Close this session when read real payload."
    end

    -- 如果还有后续的`CONTINUATION`帧
    if not fin or opcode == 'continuation' then

      -- 等所有buffer读取完毕后再连接起来
      if not buffers then
        buffers = new_tab(8, 0)
      end
      buffers[#buffers+1] = data

      -- 接受数据完毕.
      if opcode == 'continuation' and fin then
        return true
      end

      -- 接受数据期间产生错误, 则不再处理后续数据.
      local d, typ, errinfo = protocol.recv_frame(sock, max_payload_len, force_masking, buffers)
      if not d then
        return false, typ, errinfo
      end
      data = concat(buffers)

    end

    -- 有掩码位需要异或还原数据.
    if mask_key then
      data = xor_str(data, mask_key)
    end

    -- 支持 permessage-deflate 必须解压缩数据载荷
    if rsv == 0x04 then
      local buf = wsinflate(data)
      if not buf then
        return false, 'error', "[WS ERROR] : received Invalid deflate buffers."
      end
      data = buf
    end

    -- close帧有状态码
    if opcode == 'close' then
      data = data:sub(3)
    end

  end

  return data, opcode
end

---@comment 发送数据
---@param sock            table     @socket对象
---@param fin             boolean   @结束帧标志
---@param opcode          integer   @消息类型
---@param payload         string    @数据载荷
---@param masking         string    @数据掩码
---@param ext             string    @协议扩展
function protocol.send_frame(sock, fin, opcode, payload, masking, ext)

  local payload_len = #payload

  local opc = assert(WS_TYPE[opcode], "[WS ERROR] : attempted pass invalid websocket opcode.")
  if opc == 'close' or opc == 'ping' or opc == 'pong' then
    if payload_len > 125 then
      return error("[WS ERROR] : The payload length of the control frame is too long.")
    end
  end

  -- 结束位标志位 + 保留位 + 消息类型
  local h1 = (fin and 0x80 or 0x00) | opcode
  -- 如果有扩展协议则加上扩展响应头部
  if (opc ~= 'close' and opc ~= 'ping' and opc ~= 'pong') and payload_len > 125 and ext == 'deflate' then
    h1 = h1 | 0x40
    payload = wsdeflate(payload)
    payload_len = #payload
  end

  -- 掩码位与长度位
  local h2 = masking and 0x80 or 0x00
  local len_ext
  if payload_len < 126 then
    h2 = h2 | payload_len
  elseif payload_len < 65536 then
    h2, len_ext = h2 | 0x7E, strpack(">I2", payload_len)
  else
    h2, len_ext = h2 | 0x7F, strpack(">I8", payload_len)
  end

  local idx = 1
  local buffers = new_tab(4, 0)
  buffers[idx] = strpack(">BB", h1, h2)

  if len_ext then
    idx = idx + 1
    buffers[idx] = len_ext
  end

  -- 创建随机掩码并与数据载荷进行异或
  if masking and payload_len > 0 then
    masking = strpack(">BBBB", random(255), random(255), random(255), random(255))
    payload = xor_str(payload, masking)
    idx = idx + 1
    buffers[idx] = masking
  end

  -- 根据实际情况需要减少发送数据次数.
  buffers[idx + 1] = payload
  sock_send(sock, concat(buffers))
end

return protocol