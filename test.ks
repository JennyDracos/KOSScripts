set message to Lexicon().
message:add("mission","KH Fuelpod").
message:add("station","KH Highport").
message:add("missionport","bow port").
message:add("stationport","bow stb").

vessel("KH Highport"):connection:sendmessage(message).
