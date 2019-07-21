local csv = require "csv"

local Log = require("logging"):new()

Log:DEBUG(csv.loadfile("./Excel.csv"))
