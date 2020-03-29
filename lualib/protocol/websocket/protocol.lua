-- Copyright (C) Yichun Zhang (agentzh)
-- modify by CandyMi in 2019.1.12

local byte = string.byte
local char = string.char
local sub = string.sub
local gsub = string.gsub
local concat = table.concat
local str_char = string.char
local rand = math.random
local tostring = tostring
local type = type
local error = error
local assert = assert

local new_tab = require("sys").new_tab

local lz = require "lz"
local compress2 = lz.compress2
local uncompress2 = lz.uncompress2

local _M = new_tab(0, 5)

_M.new_tab = new_tab
_M._VERSION = '0.07'


local types = {
    [0x0] = "continuation",
    [0x1] = "text",
    [0x2] = "binary",
    [0x8] = "close",
    [0x9] = "ping",
    [0xa] = "pong",
}

local function sock_recv (sock, byte)
  if sock.ssl then
    local tab = {}
    while 1 do
      local data, len = sock:ssl_recv(byte)
      if not data then
        return nil
      end
      tab[#tab+1] = data
      if len >= byte then
        return concat(tab)
      end
      byte = byte - len
    end
  end
  local tab = {}
  while 1 do
    local data, len = sock:recv(byte)
    if not data then
      return nil
    end
    tab[#tab+1] = data
    if len >= byte then
      return concat(tab)
    end
    byte = byte - len
  end
end

local function sock_send (sock, data)
  if sock.ssl then
    return sock:ssl_send(data)
  end
  return sock:send(data)
end

-- 压缩数据
local function compress_data(data)
  local comp = compress2(data)
  if not comp then
    return nil
  end
  return gsub(comp, ".", char(byte(comp) - 1), 1)
end

-- 解压数据
local function uncompress_data(data)
  return uncompress2(gsub(data, ".", char(byte(data) + 1), 1))
end

function _M.recv_frame(sock, max_payload_len, force_masking)
    local data, err = sock_recv(sock, 2)
    if not data then
      return nil, nil, err
    end

    local fst, snd = byte(data, 1, 2)

    local fin = fst & 0x80 ~= 0

    if fst & 0x70 ~= 0 and fst & 0x40 ~= 0x40 then
        return nil, nil, "bad RSV1, RSV2, or RSV3 bits"
    end

    local opcode = fst & 0x0f

    if opcode >= 0x3 and opcode <= 0x7 then
        return nil, nil, "reserved non-control frames"
    end

    if opcode >= 0xb and opcode <= 0xf then
        return nil, nil, "reserved control frames"
    end

    local mask = snd & 0x80 ~= 0

    if force_masking and not mask then
        return nil, nil, "frame unmasked"
    end

    local payload_len = snd & 0x7f

    if payload_len == 126 then
      local data, err = sock_recv(sock, 2)
      if not data then
          return nil, nil, "failed to receive the 2 byte payload length: " .. (err or "unknown")
      end
      payload_len = (byte(data, 1) >> 8) | byte(data, 2)
    elseif payload_len == 127 then
      local data, err = sock_recv(sock, 8)
      if not data then
        return nil, nil, "failed to receive the 8 byte payload length: " .. (err or "unknown")
      end

      if byte(data, 1) ~= 0 or byte(data, 2) ~= 0 or byte(data, 3) ~= 0 or byte(data, 4) ~= 0 then
        return nil, nil, "payload len too large"
      end

      local fifth = byte(data, 5)
      if fifth & 0x80 ~= 0 then
        return nil, nil, "payload len too large"
      end
      payload = fifth << 24 | byte(data, 6) << 16 | byte(data, 7) | byte(data, 8)
    end

    if opcode & 0x8 ~= 0 then
      -- being a control frame
      if payload_len > 125 then
          return nil, nil, "too long payload for control frame"
      end

      if not fin then
          return nil, nil, "fragmented control frame"
      end
    end

    if payload_len > max_payload_len then
        return nil, nil, "exceeding max payload len"
    end

    local rest = payload_len
    if mask then
      rest = payload_len + 4
    end

    local data = ""
    if rest > 0 then
      data, err = sock_recv(sock, rest)
      if not data then
        return nil, nil, "failed to read masking-len and payload: " .. (err or "unknown")
      end
    end

    if opcode == 0x8 then

        if payload_len > 0 then
            if payload_len < 2 then
                return nil, nil, "close frame with a body must carry a 2-byte status code"
            end

            local msg, code
            if mask then
                local fst = byte(data, 4 + 1) ~ byte(data, 1)
                local snd = byte(data, 4 + 2) ~ byte(data, 2)
                code = (fst << 8) | snd

                if payload_len > 2 then
                    -- TODO string.buffer optimizations
                    local bytes = new_tab(payload_len - 2, 0)
                    for i = 3, payload_len do
                        bytes[i - 2] = str_char(byte(data, 4 + i) ~ byte(data, (i - 1) % 4 + 1))
                    end
                    msg = concat(bytes)

                else
                    msg = ""
                end

            else
                local fst = byte(data, 1)
                local snd = byte(data, 2)
                code = (fst << 8) | snd

                if payload_len > 2 then
                    msg = sub(data, 3)

                else
                    msg = ""
                end
            end
            if fst & 0x40 == 0x40 and #msg > 0 then
              -- print("压缩后的数据长度为:" .. #msg)
              local data = uncompress_data(msg)
              if not data then
                return data, types[opcode], "invalide deflate data."
              end
              msg = data
              -- print("压缩前的数据长度为:" .. #msg)
            end
            return msg, "close"
        end
        return "", "close", nil
    end

    local msg = data
    if mask then
      -- TODO string.buffer optimizations
      local bytes = new_tab(payload_len, 0)
      for i = 1, payload_len do
          bytes[i] = str_char(byte(data, 4 + i) ~ byte(data, (i - 1) % 4 + 1))
      end
      msg = concat(bytes)
    end
    if fst & 0x40 == 0x40 and #msg > 0 then
      -- print("解压前的数据长度为:" .. #msg)
      local data = uncompress_data(msg)
      if not data then
        return msg, types[opcode], "invalide deflate data."
      end
      msg = data
      -- print("解压后的数据长度为:" .. #msg)
    end
    return msg, types[opcode], not fin and "again" or nil
end


local function build_frame(fin, opcode, payload_len, payload, masking, ext)

    local fst = opcode
    if fin then
      fst = 0x80 | (ext == 'deflate' and 0x40 or 0) | opcode
    end

    local snd, extra_len_bytes
    if payload_len <= 125 then
        snd = payload_len
        extra_len_bytes = ""

    elseif payload_len <= 65535 then
        snd = 126
        extra_len_bytes = char((payload_len >> 8) & 0xff, payload_len & 0xff)

    else
        if payload_len & 0x7fffffff < payload_len then
            return nil, "payload too big"
        end

        snd = 127

        extra_len_bytes = char(0, 0, 0, 0, (payload_len >> 24) & 0xff, (payload_len >> 16) & 0xff, (payload_len >> 8) & 0xff, payload_len & 0xff)
    end

    local masking_key = ""
    if masking then
        -- set the mask bit
        snd = snd | 0x80
        local key = rand(0xffffffff)
        masking_key = char((key >> 24)& 0xff, (key >> 16)& 0xff, (key >> 8)& 0xff, key & 0xff)

        -- TODO string.buffer optimizations
        local bytes = new_tab(payload_len, 0)
        for i = 1, payload_len do
            bytes[i] = str_char(byte(payload, i) ~ byte(masking_key, (i - 1) % 4 + 1))
        end
        payload = concat(bytes)
    end
    return char(fst, snd) .. extra_len_bytes .. masking_key .. payload
end
_M.build_frame = build_frame


function _M.send_frame(sock, fin, opcode, payload, max_payload_len, masking, ext)

  assert(type(payload) == 'string' and #payload <= max_payload_len, "Invalid data type or length exceeds expected")

  local payload_len = #payload

  -- 支持permessage-deflate压缩
  if ext == 'deflate' and payload_len > 0 then
    -- print("压缩前的数据长度为:" .. #payload)
    payload = assert(compress_data(payload), "deflate compress data error.")
    payload_len = #payload
    -- print("压缩后的数据长度为:" .. #payload)
  end

  if opcode & 0x8 ~= 0 then
    if payload_len > 125 then
      return error("The payload length of the control frame is too long.")
    end
    if not fin then
        return error("Invalid control frame.")
    end
  end

  local frame, err = build_frame(fin, opcode, payload_len, payload, masking, ext)
  if not frame then
    return error("Invalid data frame: " .. err)
  end
  return sock_send(sock, frame)
end

return _M
