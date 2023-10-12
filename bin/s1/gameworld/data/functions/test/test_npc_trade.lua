module("test.test_npc_trade" , package.seeall)
setfenv(1, test.test_npc_trade)

local npctradesystem = require("systems.npctrade.npctradesystem")
local lottery = require("systems.lottery.lotterysystem")
local actormoney = require("systems.actorsystem.actormoney")

local getItemProperty = Item.getItemProperty
local getItemPropertyById = Item.getItemPropertyById

require("protocol")
local NpcTradeSystem = NpcTradeSystem


local test_func = {}

local items = {18300, 18301, 18302, 18303, 18310, 18311, 18312, 18313}

test_func.test_buy_item = function(actor)

	--测试金钱循环1000次
	for i = 1, 1000 do
		print("----------------"..i.."----------------1")
		--选出一个道具
		local itemId = items[math.random(1, #items)]
		local itemCount = math.random(1, 99)
		local npcId = 0
		--购买花费类型
		local dtype = getItemPropertyById(itemId, Item.ipItemDealMoneyType)
		local dprice = getItemPropertyById(itemId, Item.ipItemDealMoneyCount) * 3
		local totalCount = dprice * itemCount 
		--把钱与背包清0
		LActor.changeMoney(actor, dtype, -(LActor.getMoneyCount(actor, dtype)), 1, true, "gm", "GmAddMoney", "", LActor.getName(actor))
		

		LActor.cleanBag(actor)  --这个函数没用
		

		local money = math.random(1, totalCount * 2)
		LActor.changeMoney(actor, dtype, money, 1, true, "gm", "GmAddMoney", "", LActor.getName(actor))
		local dp = LDataPack.test_allocPack()
		LDataPack.writeWord(dp, itemId)
		LDataPack.writeWord(dp, itemCount)
		LDataPack.writeWord(dp, npcId)
	    LDataPack.setPosition(dp, 0)
		local ret = npctradesystem.buyItem(actor, dp)
		if money < totalCount then
			Assert_eq(2, ret, "buy failure")
		else
			--扣钱是否出错
			local nextMoney = LActor.getMoneyCount(actor, dtype)
			Assert_eq((money - totalCount), nextMoney, "money failure")
		end
	end

	--目前无法获取剩余格子数



	-- if cMoney < totalCount then
	-- 	Assert_eq(2, ret, "buy failure")
	-- 	--随机给予金钱 可能够也可能不够
		
	-- end
	-- --测试背包不足
	-- if (LActor.canAddItem(actor, itemId, itemCount) == false) then
	-- 	Assert_eq(1, ret, "buy failure")
	-- 	break
	-- end
	-- --测试正常情况
	-- Assert_eq(3, ret, "buy failure")
	-- local nextMoney = LActor.getMoneyCount(actor, dtype)
	-- local nextBagCnt = Item.getBagEmptyGridCount(actor, ipBag)
	-- print("nextMoney="..nextMoney.."nextBagCnt="..nextBagCnt)
end

--加入+7以上强化装备不允许售卖
--五级或五级以上宝石不允许售卖
local items1 = {{itemId = 1100, quality = 0, strong = 6, count = 1, bind = 1, ret = 4},
				{itemId = 7100, quality = 0, strong = 7, count = 1, bind = 1, ret = 2},
				{itemId = 4100, quality = 0, strong = 8, count = 1, bind = 1, ret = 2},
				{itemId = 8100, quality = 0, strong = 9, count = 1, bind = 1, ret = 2},
				{itemId = 6100, quality = 0, strong = 0, count = 1, bind = 1, ret = 4},
				{itemId = 3100, quality = 0, strong = 1, count = 1, bind = 1, ret = 4},

				{itemId = 18543, quality = 0, strong = 0, count = 1, bind = 1, ret = 4},
				{itemId = 18540, quality = 0, strong = 0, count = 1, bind = 1, ret = 4},
				{itemId = 18544, quality = 0, strong = 0, count = 1, bind = 1, ret = 3},
				{itemId = 18545, quality = 0, strong = 0, count = 1, bind = 1, ret = 3},
				{itemId = 18542, quality = 0, strong = 0, count = 1, bind = 1, ret = 4},
			   }
test_func.test_sell_item = function(actor)
	for i,v in ipairs(items1) do
		print("----------------"..i.."----------------1")
		local addCount = LActor.addItem(actor, v.itemId, v.quality, v.strong, v.count, v.bind, "gm", 12)
		local item = Item.getItemById(actor, v.itemId, v.bind)
		local itemPtr = Item.getItemGuid(item)
		local dp = LDataPack.test_allocPack()
		LDataPack.writeUint64(dp, itemPtr)
	    LDataPack.setPosition(dp, 0)
	    local ret = npctradesystem.sellItem(actor, dp)
	    local str = string.format("id=%d, strong=%d", v.itemId, v.strong)
	    Assert_eq(v.ret, ret, str)
	end
end


local function test_assert_exchangeItemOp(actor, itemID, itemCount, itemQuality, itemStrong, GroupId, pid, except)
	--封装包
	local package = LDataPack.test_allocPack()
	LDataPack.writeWord(package, itemID)
	LDataPack.writeWord(package, itemCount)
	LDataPack.writeByte(package, itemQuality)
	LDataPack.writeByte(package, itemStrong)
	LDataPack.writeByte(package, GroupId)
	LDataPack.setPosition(package, 0)	

	-- 待测  需要测试的值改变，有以下情况
	-- 货币（元宝、仙币）
	-- 声望、荣誉 12、16  giveAward
	-- 聚仙令  changeTeamToken
	-- 跨服荣誉

	local oldMjScore = lottery.getMjScore(actor)                                        --梦境积分
	local oldBagCnt = LActor.getBagItemCount(actor)	                                    --背包数量

	local ret = npctradesystem.exchangeItemOp(actor, package, pid)
	Assert(ret ~= nil, "test_assert_exchangeItemOp, ret is null")				        --不允许不返回或者返回nil
	Assert_eq(except, ret, "test_assert_exchangeItemOp error")   

	local currMjScore = lottery.getMjScore(actor)
	local currBagCnt = LActor.getBagItemCount(actor)

	if except == ret and ret == true then
		local sellconfig = npctradesystem.findItem(actor, itemID, itemCount, 4)
		local priceInfos = sellconfig.price
		local nTotal = 0
		for _,priceInfo in ipairs(priceInfos) do
			nTotal = nTotal + priceInfo.price * itemCount 
		end
		Assert_eq(nTotal , oldMjScore - currMjScore, "exchangeItemOp fail but MjScore change error")
		Assert_eq(itemCount , currBagCnt - oldBagCnt, "exchangeItemOp fail but BagCnt change error")
	else
		Assert_eq(oldMjScore, currMjScore, "exchangeItemOp fail but MjScore change")
		Assert_eq(oldBagCnt, currBagCnt, "exchangeItemOp fail but BagCnt change")
	end

end

local test_exchangeItemOp_values = {
	--itemID, itemCount, itemQuality, itemStrong, GroupId, pid, except
	--错误值
	{18003, 3, 0, 0, 0,9,false},   --设置一个在配置表中不存在的物品

	--正确
	{18603, 3, 0, 0, 0,9,true},    --设置一个在配置表中存在的物品
}

local function test_exchangeItemOp_unit(actor)	
	--测试输入值
	LActor.setIntProperty(actor, P_LEVEL,100) 								--设置一个超过最大等级限制的值 
	for _,value in ipairs(test_exchangeItemOp_values) do	
		test_assert_exchangeItemOp(actor, value[1], value[2], value[3],value[4],value[5],value[6],value[7])	
	end
	
	-- 测试等级
	-- 用户随机一个不满足的等级，判断是否程序有判断等级开放条件	
	-- 满足条件的物品
	itemID = 18603 
	itemCount = 3
	itemQuality = 0
	itemStrong = 0
	GroupId = 0

	local sellconfig = npctradesystem.findItem(actor, itemID, itemCount, 4)
	for i=1,20 do	--测试20次
		local randLevel = System.getRandomNumber(sellconfig.buyLevel - 1) + 1
		LActor.setIntProperty(actor, P_LEVEL,randLevel)
		test_assert_exchangeItemOp(actor,itemID, itemCount, itemQuality, itemStrong, GroupId, NpcTradeSystem.cMjScoreItem, false)
	end	
end

TEST("npc_trade", "test_buy_item", test_func.test_buy_item)
TEST("npc_trade", "test_sell_item", test_func.test_sell_item)
TEST("npc_trade", "test_exchangeItemOp_unit", test_exchangeItemOp_unit)




