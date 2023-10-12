-- LUA定时器配置测试
module("test.test_wyyj" , package.seeall)
setfenv(1, test.test_wyyj)

local wyyjsystem = require("systems.wanyaoyiji.wyyjsystem")

-- Comments: 进入万妖遗迹
function test_activityEnter(actor)
	local npack = LDataPack.test_allocPack()
	LDataPack.setPosition(npack, 0)

	local ret = wyyjsystem.activityEnter(actor, npack)
	-- Assert(ret ~= nil, "test_activityEnter, ret is null")
	-- Assert_eq(except, ret, "test_activityEnter error")
end

_G.test_activityEnter = test_activityEnter


