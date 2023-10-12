module("test.test_mingke", package.seeall)
setfenv(1, test.test_mingke)

function test_mingke(actor)
	local name = "abc"
	local context = "testing!"
	local time = System.getNowTime()
	LActor.addItem(actor, 1100, 0, 0, 1, 0)
	local item = Item.getItemById(actor, 1100, 0)
	if not item then return end
	Item.setSignData(item, name, context, time)
end


_G.mingke = test_mingke
TEST("equip", "mingke", test_mingke)