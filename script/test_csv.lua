local csv = require "csv"

local LOG = require("logging")

LOG:DEBUG(csv.loadfile("./Excel.csv"))

LOG:DEBUG(csv.writefile("./Excel-1.csv", csv.loadfile("./Excel.csv")))
