module("test.test_itemcrc" , package.seeall)
setfenv(1, test.test_itemcrc)

function test_itemcrc(actor)
	local c1 = Item.getCrc16(actor, ipBag)
	local c2 = Item.getCrc16(actor, ipBag)
	-- 连续调用2次，看是否一样
	Assert(c1 == c2)

	-- 加个物品，看是否一样
	LActor.addItem(actor, 9100, 0, 0, 1, 1, "test")
	c2 = Item.getCrc16(actor, ipBag)
	Assert(c1 ~= c2)
end


TEST("crc", "test_itemcrc", test_itemcrc)


