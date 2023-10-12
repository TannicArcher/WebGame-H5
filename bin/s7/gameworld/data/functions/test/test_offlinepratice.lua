module("test.test_offlinepratice" , package.seeall)
setfenv(1, test.test_offlinepratice)

local offlinePraticeSystem = require("systems.practice.offlinepractice")

function test_OfflineList()
	for _, info in pairs(offlineActors) do
		print(info.actorid)
		print(info.actorname)
		print(info.status)
	end
	offlinePraticeSystem.onTime()
end

_G.test_OfflineList = test_OfflineList


