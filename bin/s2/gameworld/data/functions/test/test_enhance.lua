module("test.test_misc", package.seeall)
setfenv(1, test.test_misc)

local enhance = require("systems.equipment.enhance")
require("protocol")
local sysId = SystemId.enEquipSystemID
local protocol = equipSystemProtocal

local makeItemId = 3103
local enhanceMakeLevel = 34
local repeatTimes = 100

function test_enhance(actor)
	local success = 0
	for j=1, repeatTimes do
		LActor.cleanBag(actor)
		LActor.sendDepotInfo(actor)
		LActor.addItem(actor, makeItemId, 0, enhanceMakeLevel, 1, 0)
		local item = Item.getItemById(actor, makeItemId)
		Item.setItemProperty(actor, item, Item.ipItemStage, 1)
		local old_strong = Item.getItemProperty(actor, item, Item.ipItemStrong, 0 )
		Assert(item, "equip item is add error")
		local uid = Item.getItemGuid(item)

		local pack = LDataPack.test_allocPack()
		LDataPack.writeData(pack, 3, dtInt64, uid, dtInt64, 0, dtInt, 1)
		LDataPack.setPosition(pack, 0)
		enhance.onEquipEnhance(actor, pack)
		local new_strong = Item.getItemProperty(actor, item, Item.ipItemStrong, 0 )
		if new_strong > old_strong then
			success = success + 1
		end
	end

	print("test_enhance " .. success / repeatTimes)
end

TEST("equip", "enhance", test_enhance)