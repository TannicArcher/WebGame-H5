module("test.test_ziyousai", package.seeall)
setfenv(1, test.test_ziyousai)

local zysSystem = require("systems.xiandaohui.ziyousai")

function test_ziyousaiStart(actor, round)
	zysSystem.ZysStart(round)
end
