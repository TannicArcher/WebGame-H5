module("test.test_buff", package.seeall)
setfenv(1, test.test_buff)

local function test_AddBuff(actor, id)
	--todo buff修改
	LActor.addBuff(actor, id)
end

_G.testBuff = test_AddBuff

TEST("buff", "test_AddBuff", test_AddBuff)
