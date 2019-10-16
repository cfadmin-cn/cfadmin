local csv = require "csv"

local Log = require("logging"):new()

Log:DEBUG(csv.loadfile("./Excel.csv"))


local csv.dump("./Excel-1.csv", csv.loadfile("./Excel.csv"))
