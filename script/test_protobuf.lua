local Log = require ("logging"):new()

local pb = require "protobuf"

Log:DEBUG(pb.loadfile("Person.lua"))

local pb_string = pb.encode("Person", {
  name = "CandyMi",
  age = 2^32 - 1,
  hand = {
    left = "左手",
    right = "右手",
  },
  foot = {
    left = "左脚",
    right = "右脚",
  }
})
Log:DEBUG(pb.tohex(pb_string))

Log:DEBUG(pb.decode("Person", pb_string))

Log:DEBUG(pb.clear("Person"))
