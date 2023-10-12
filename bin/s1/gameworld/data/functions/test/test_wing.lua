module("test.test_wing", package.seeall)
setfenv(1, test.test_wing)

require("wings.wingconfig")
require("wings.wingskillconfig")
require("item.scriptitemconfig.wingitemdatas")
local actormoney = require("systems.actorsystem.actormoney")
local wingsystem = require("systems.wingsystem.wingsystem")
local common = require("systems.wingsystem.wingcommon")
local winglevelup = require("systems.wingsystem.winglevelup")
local wingstageup = require("systems.wingsystem.wingstageup")
local wingshentong = require("systems.wingsystem.wingshentong")
local wingmodel = require("systems.wingsystem.wingmodel")
local wingskill = require("systems.wingsystem.wingskill")

local Wings = Wings
local WingItems = WingItems
local SpecialWingItem = SpecialWingItem

function addWing(actor)
	--随机一个翅膀道具
	local rand = math.random(#WingItems)
	local info = WingItems[rand]
	LActor.addItem(actor, info.id, 0, 0, 1, 0)
	--获取刚刚获得的翅膀
	local item = Item.getItemById(actor, info.id, 0)
	local guid = Item.getItemGuid(item)

	LActor.useItemByGuid(actor, guid)
	
end

function takeoff(actor)
	local item = LActor.getWingItem(actor)
	local guid = Item.getItemGuid(item)
	LActor.takeoffequip(actor, guid)
end

function checkWingInfo(wingInfo)
	Assert(wingInfo.level~=nil, "checkWingInfo, level error")
	Assert(wingInfo.bless~=nil, "checkWingInfo, bless error")
	Assert(wingInfo.stage~=nil, "checkWingInfo, stage error")
	Assert(wingInfo.stage_point~=nil, "checkWingInfo, stage_point error")
	Assert(wingInfo.model~=nil, "checkWingInfo, model error")
end

function test_wingLevelUp(actor)
	LActor.cleanBag(actor)

	addWing(actor)

	local item = LActor.getWingItem(actor)
	Assert(item~=nil, "test_wingLevelUp, addWing is nil")
	local wingInfo = common.getWingInfo(actor)
	checkWingInfo(wingInfo)

	local oldLevel = wingInfo.level
	local oldBless = wingInfo.bless
	local config = Wings.levelConfig[wingInfo.level]
	Assert(config~=nil, "test_wingLevelUp, config is nil")
	local needItem = config.needItem
	local needCount = config.needCount
	local moneyCost = config.moneyCost
	--添加消耗物品
	LActor.addItem(actor, needItem, 0, 0, needCount, 0)
	--仙币充足的情况下
	LActor.changeMoney(actor, mtBindCoin, 1000000, 1, true, "test_wingLevelUp","", "","")
	local oldMoney = actormoney.getMoney(actor, mtBindCoin)
	local oldItemCnt = LActor.getItemCount(actor, needItem, 0)

	local pack = LDataPack.test_allocPack()
	LDataPack.writeChar(pack, 0)
	LDataPack.setPosition(pack, 0)
	
	winglevelup.wingLevelUp(actor, pack)

	local currMoney = actormoney.getMoney(actor, mtBindCoin)
	local currItemCnt = LActor.getItemCount(actor, needItem, 0)
	wingInfo = common.getWingInfo(actor)
	local currLevel = wingInfo.level
	local currBless = wingInfo.bless
	Assert(currBless<=Wings.maxLevelBless, "test_wingLevelUp, bless over error")
	if currLevel == oldLevel then 
		Assert_eq(currBless - oldBless, 1, "test_wingLevelUp, bless error")
	elseif currBless == oldBless then 
		Assert_eq(currLevel - oldLevel, 1, "test_wingLevelUp, level error")
	else
		Assert(false, "test_wingLevelUp, level, bless error")
	end

	Assert_eq(oldMoney-currMoney, moneyCost, "test_wingLevelUp, cost money error")
	Assert_eq(oldItemCnt-currItemCnt, needCount, "test_wingLevelUp, cost item error")

	takeoff(actor)
	item = LActor.getWingItem(actor)
	Assert(item==nil, "test_wingLevelUp, takeoffequip error")
end

function test_wingStageUp(actor)
	LActor.cleanBag(actor)
	addWing(actor)

	local item = LActor.getWingItem(actor)
	Assert(item~=nil, "test_wingStageUp, addWing is nil")
	
	local wingInfo = common.getWingInfo(actor)
	checkWingInfo(wingInfo)

	local oldStage = wingInfo.stage
	local oldStage_point = wingInfo.stage_point
	local config = Wings.stages[oldStage]
	Assert(config~=nil, "test_wingStageUp, config is nil")
	local shengwangCost = config.shengwangCost[oldStage_point+1]
	local moneyCost = config.xbCost[oldStage_point+1]
	--添加声望
	LActor.ChangeShengWang(actor, shengwangCost)
	LActor.changeMoney(actor, mtBindCoin, 1000000, 1, true, "test_wingStageUp","", "","")

	local oldShengWang = LActor.getShengWang(actor)
	local oldMoney = actormoney.getMoney(actor, mtBindCoin)

	--进阶操作
	wingstageup.wingStageUp(actor)

	local currMoney = actormoney.getMoney(actor, mtBindCoin)
	local currShengWang = LActor.getShengWang(actor)
	wingInfo = common.getWingInfo(actor)
	local currStage = wingInfo.stage
	local currStage_point = wingInfo.stage_point

	--检查进阶后,数据是否非法
	Assert(currStage<=#Wings.stages, "test_wingStageUp, stage error")
	if currStage <= #Wings.stages then 
		Assert(currStage_point<=#Wings.stages[currStage].attrList, "test_wingStageUp, stage_point error")
	end

	--检查阶数是否正确
	if currStage == oldStage then 
		Assert_eq(currStage_point-oldStage_point, 1, "test_wingStageUp, stage_point up error")
	elseif currStage - oldStage == 1 then
		Assert_eq(currStage_point, 0, "test_wingStageUp, stage_point up error")
	else
		Assert(false, "test_wingStageUp, stage up error")
	end

	Assert_eq(currMoney-oldMoney, -moneyCost, "test_wingStageUp, moneyCost error")
	Assert_eq(currShengWang-oldShengWang, -shengwangCost, "test_wingStageUp, shengwangCost error")

	takeoff(actor)
	item = LActor.getWingItem(actor)
	Assert(item==nil, "test_wingLevelUp, takeoffequip error")
end

function cleanShenTong(actor)
	local var = common.getWingVar(actor)
	var.shentong = nil
end

function test_shenTong(actor)
	cleanShenTong(actor)

	LActor.cleanBag(actor)
	addWing(actor)

	local item = LActor.getWingItem(actor)
	Assert(item~=nil, "test_shenTong, addWing is nil")

	for i=1, 100 do 
		local rand = math.random(8)
		local config = Wings.ShenTong[rand]
		Assert(config~=nil, "test_shenTong, config error")

		local needItem = config.needItem
		local needCount = config.needCount
		local moneyCost = config.moneyCost
		--添加消耗物品
		LActor.addItem(actor, needItem, 0, 0, needCount, 0)
		--仙币充足的情况下
		LActor.changeMoney(actor, mtBindCoin, moneyCost, 1, true, "test_wingLevelUp","", "","")
		local oldMoney = actormoney.getMoney(actor, mtBindCoin)
		local oldItemCnt = LActor.getItemCount(actor, needItem, 0)
		local var = common.getWingVar(actor)
		local oldVal = 0
		if var.shentong then 
			oldVal = var.shentong[rand]	or 0	
		end

		local pack = LDataPack.test_allocPack()
		LDataPack.writeByte(pack, rand)
		LDataPack.writeByte(pack, 0)
		LDataPack.setPosition(pack, 0)
	
		wingshentong.wingShenTong(actor, pack)

		local currMoney = actormoney.getMoney(actor, mtBindCoin)
		local currItemCnt = LActor.getItemCount(actor, needItem, 0)

		Assert(var.shentong~=nil, "test_shenTong, shentong is nil")
		local currVal = 0
		if var.shentong then 
			currVal = var.shentong[rand] or 0
		end
		Assert_eq(currVal-oldVal, 1, "test_shenTong, shentong add error")

		Assert_eq(oldMoney-currMoney, moneyCost, "test_shenTong, cost money error")
		Assert_eq(oldItemCnt-currItemCnt, needCount, "test_shenTong, cost item error")
	end
	local var = common.getWingVar(actor)
	local all = 0
	for i=1, 8 do
		all = all + var.shentong[i] or 0
	end
	Assert_eq(all, 100, "test_shenTong, total add error")
end

function test_info(actor)
	local pack = LDataPack.test_allocPack()
	LDataPack.writeInt(pack, LActor.getActorId(actor))
	LDataPack.setPosition(pack, 0)
	sendAllWingInfo(actor, pack)
end

function test_skillGrid(actor, count)
	wingskill.setSkillGrid(actor, count)
end

function test_wingModel(actor)
	LActor.addItem(actor, SpecialWingItem[1].itemId, 0, 0, 1, 0)
	wingmodel.getModelInfo(actor)
	local pack = LDataPack.test_allocPack()
	LDataPack.writeByte(pack, 1)
	LDataPack.writeInt(pack, 10)
	LDataPack.setPosition(pack, 0)
	wingmodel.wingChangeModel(actor,pack)
end

function test_wingSkill(actor)
	LActor.addItem(actor, WingSkillItem[1].itemId, 0, 0, 1, 0)
	LActor.useItemById(actor, WingSkillItem[1].itemId, 1, 0)
	wingskill.getSkillStoreInfo(actor)

	local skills = LActor.getWingSkillStore(actor)
	Assert(skills~=nil, "test_wingSkill, skill store error")

	local guid = skills[1]

	local pack = LDataPack.test_allocPack()
	LDataPack.writeInt64(pack, guid)
	LDataPack.setPosition(pack, 0)
	wingskill.learnSkill(actor, pack)
end

--添加一套时间为1s的时装, 测试SpecialWingTimeOut报错
function test_timeout(actor)
	wingmodel.collectSpecialWing(actor, 17, 1)
end


_G.wing = test_wingSkill
_G.grid = test_skillGrid

TEST("wing", "level", test_wingLevelUp)
TEST("wing", "stage", test_wingStageUp)
TEST("wing", "info", test_info)
TEST("wing", "model", test_wingModel)
TEST("wing", "timeout", test_timeout)