module("test.test_spirit" , package.seeall)
setfenv(1, test.test_spirit)

local spiritF = require("systems.spirit.spirit")
require("spirit.spiritconfig")
local SpiritConfig = SpiritConfig

local checkFunc = require("test.assert_func")

Assert_eq = checkFunc.Assert_eq

local test_func = {}

test_func.level = function(actor)
	spiritF.initSpirit(actor)

	local sysVar = LActor.getSysVar(actor)
	local spirit = sysVar.spirit

	spirit.ybCollectCount = 0
	spirit.coinCount = 0
	spirit.yuanbaoCount = 0
	spirit.yuanbaoMax = SpiritConfig.sYuanbaoMax

-- 金钱不足
	LActor.changeMoney(actor, mtCoin, -LActor.getMoneyCount(actor, mtCoin), 1, true, "test_spirit", "level up")
	LActor.changeMoney(actor, mtYuanbao, -LActor.getMoneyCount(actor, mtYuanbao), 1, true, "test_spirit", "level up")
	local is = false
	for i=1, 1000 do
		if spirit.level >= SpiritConfig.sLevelMax then
			is = true
		end
		local dp = LDataPack.test_allocPack()
		local random = (System.getRandomNumber(2) + 1)
		LDataPack.writeByte(dp, random)
	    LDataPack.setPosition(dp, 0)
		local ret = spiritF.awaken(actor, dp)
		if is then
			Assert_eq(1, ret, "level max err")
		else
			Assert_eq(4, ret, "money err")
		end
	end
	LActor.changeMoney(actor, mtCoin, 9999999, 1, true, "test_spirit", "level up")
	LActor.changeMoney(actor, mtYuanbao, 9999999, 1, true, "test_spirit", "level up")
	spirit.ybCollectCount = 0
	spirit.coinCount = 0
	spirit.yuanbaoCount = 0
	spirit.yuanbaoMax = SpiritConfig.sYuanbaoMax

-- 设置为满级
	spirit.level = SpiritConfig.sLevelMax
	for i=1, 1000 do
		local dp = LDataPack.test_allocPack()
		local random = (System.getRandomNumber(2) + 1)
		LDataPack.writeByte(dp, random)
	    LDataPack.setPosition(dp, 0)
		local ret = spiritF.awaken(actor, dp)
		Assert_eq(1, ret, "level max err")
	end

	local newCoin = LActor.getMoneyCount(actor, mtCoin)
	local newYuanbao = LActor.getMoneyCount(actor, mtYuanbao)
	Assert_eq(9999999, newCoin, "level max coin err")
	Assert_eq(9999999, newYuanbao, "level max YB err")


	spirit.ybCollectCount = 0
	spirit.coinCount = 0
	spirit.yuanbaoCount = 0
	spirit.yuanbaoMax = SpiritConfig.sYuanbaoMax
-- 给予足够的金钱 然后判断每日的最大的次数

	local count = 0
	for i=1, 100 do
		local oldCoin = LActor.getMoneyCount(actor, mtCoin)

		if spirit.level >= SpiritConfig.sLevelMax then
			spirit.level = 1
			spirit.exp = 0
		end

		local dp = LDataPack.test_allocPack()
		local random = 1
		LDataPack.writeByte(dp, random)
	    LDataPack.setPosition(dp, 0)
		local ret = spiritF.awaken(actor, dp)

		count = count + 1
		if count > 10 then
			Assert_eq(2, ret, "coin count err")
		else
			local newCoin = LActor.getMoneyCount(actor, mtCoin)
			Assert_eq(oldCoin - SpiritConfig.sCoin, newCoin, "coin err")
		end
	end

	spirit.ybCollectCount = 0
	spirit.coinCount = 0
	spirit.yuanbaoCount = 0
	spirit.yuanbaoMax = SpiritConfig.sYuanbaoMax
	count = 0
	for i=1, 1000 do
		local oldYB = LActor.getMoneyCount(actor, mtYuanbao)

		if spirit.level >= SpiritConfig.sLevelMax then
			spirit.level = 1
			spirit.exp = 0
		end

		local dp = LDataPack.test_allocPack()
		local random = 2
		LDataPack.writeByte(dp, random)
	    LDataPack.setPosition(dp, 0)
		local ret = spiritF.awaken(actor, dp)

		if i > 3 then
			count = count + 1
		end
		if ret then
			count = count - 1
		end
		
		if count > 10 then
			Assert_eq(2, ret, "yuanbao count err")
		end

		
	end
end

test_func.oneCollect = function(actor)
	spiritF.initSpirit(actor)
	-- 金钱不足
	for i=1, 1000 do
		local dp = LDataPack.test_allocPack()
		local random = System.getRandomNumber(10)
		local randomA = System.getRandomNumber(2)
		LDataPack.writeInt(dp, 1)
		LDataPack.writeByte(dp, 0)
		LDataPack.setPosition(dp, 0)
		ret = spiritF.oneCollect(actor, dp)
		Assert_eq(false, ret, "oneCollect")
	end
	
	-- 金钱足够
--	LActor.changeMoney(actor, mtYuanbao, 999999, 1, true, "test_spirit", "level up")

	for i=1, 1000 do
		local dp = LDataPack.test_allocPack()
		local random = System.getRandomNumber(10)
		local randomA = System.getRandomNumber(2)
		LDataPack.writeInt(dp, random)
		LDataPack.writeByte(dp, 0)
		LDataPack.setPosition(dp, 0)
		ret = spiritF.oneCollect(actor, dp)
	end

	local oldYB = LActor.getMoneyCount(actor, mtYuanbao)
	for i=1, 1000 do
		local dp = LDataPack.test_allocPack()
		local random = System.getRandomNumber(10)
		local randomA = System.getRandomNumber(2)
		LDataPack.writeInt(dp, random)
		LDataPack.writeByte(dp, 1)
		LDataPack.setPosition(dp, 0)
		ret = spiritF.oneCollect(actor, dp)
		local newYB = LActor.getMoneyCount(actor, mtYuanbao)

		Assert_eq(oldYB, newYB, "oneCollect")
	end 

LActor.clearBagSoul(actor)
LActor.recharge( actor, 555555 )
	local oldYB = LActor.getMoneyCount(actor, mtYuanbao)
	for i=1, 1000 do
		local dp = LDataPack.test_allocPack()
		local random = System.getRandomNumber(10)
		local randomA = System.getRandomNumber(2)
		LDataPack.writeInt(dp, random)
		LDataPack.writeByte(dp, 1)
		LDataPack.setPosition(dp, 0)
		ret = spiritF.oneCollect(actor, dp)
		local newYB = LActor.getMoneyCount(actor, mtYuanbao)

		Assert_eq(oldYB, newYB, "oneCollect")
	end 

end

test_func.quickCollect = function(actor)
LActor.clearBagSoul(actor)
		spiritF.initSpirit(actor)
		LActor.changeMoney(actor, mtCoin, 999999, 1, true, "test_spirit", "level up")
		LActor.changeMoney(actor, mtYuanbao, 999999, 1, true, "test_spirit", "level up")
		ret = spiritF.quickCollect(actor)

		local oldexp = LActor.getAllBagSoulExp(actor)


		local dp = LDataPack.test_allocPack()
		LDataPack.writeByte(dp, 5)
	    LDataPack.setPosition(dp, 0)
		ret = spiritF.quickDevour(actor, dp)

		local newexp = LActor.getAllBagSoulExp(actor)
		local idList = LActor.getQualityList(actor, 5)

		Assert_eq(oldexp, newexp, "quickCollect")
		Assert_eq(1, #idList, "quickCollect count")
	LActor.clearBagSoul(actor)
end

test_func.devour = function(actor)
	spiritF.initSpirit(actor)
	LActor.changeMoney(actor, mtCoin, 99999999, 1, true, "test_spirit", "level up")
	LActor.changeMoney(actor, mtYuanbao, 999999, 1, true, "test_spirit", "level up")
	for i=1, 30 do
		local dp = LDataPack.test_allocPack()
		local random = System.getRandomNumber(10)
		local randomA = System.getRandomNumber(2)
		LDataPack.writeInt(dp, random)
		LDataPack.writeByte(dp, randomA)
	    LDataPack.setPosition(dp, 0)
		ret = spiritF.collect(actor, dp)
	end

	local dp = LDataPack.test_allocPack()
	LDataPack.writeByte(dp, 0)
	LDataPack.writeInt(dp, 1)
	LDataPack.writeByte(dp, 0)
	LDataPack.writeInt(dp, 2)
    LDataPack.setPosition(dp, 0)
	ret = spiritF.devour(actor, dp)
	
	Assert_eq(1, ret, "soulInfo")
end

test_func.skillLevel = function(actor)
	LActor.changeMoney(actor, mtCoin, 99999999, 1, true, "test_spirit", "level up")
	LActor.changeMoney(actor, mtYuanbao, 999999, 1, true, "test_spirit", "level up")
	local dp = LDataPack.test_allocPack()
	local random = System.getRandomNumber(10)
	local randomA = System.getRandomNumber(2)
	LDataPack.writeInt(dp, random)
	LDataPack.writeByte(dp, randomA)
    LDataPack.setPosition(dp, 0)
	local ret = spiritF.skillup(actor, dp)

	if random > 1 then
		Assert_eq(nil, ret, "skill  Level")
	end

end

test_func.lock = function(actor)
	local dp = LDataPack.test_allocPack()
	LDataPack.writeInt(dp, 1)
	LDataPack.writeByte(dp, 1)
    LDataPack.setPosition(dp, 0)
	ret = spiritF.soulLock(actor, dp)

	Assert_eq(1, ret, "lock")
end

test_func.equip = function(actor)
	spiritF.initSpirit(actor)

	LActor.changeMoney(actor, mtCoin, 999999, 1, true, "test_spirit", "level up")
	LActor.changeMoney(actor, mtYuanbao, 999999, 1, true, "test_spirit", "level up")

	local dp = LDataPack.test_allocPack()
	local random = System.getRandomNumber(10)
	local randomA = System.getRandomNumber(2)
	LDataPack.writeInt(dp, 1)
	LDataPack.writeByte(dp, 0)
    LDataPack.setPosition(dp, 0)
	ret = spiritF.oneCollect(actor, dp)


	dp = LDataPack.test_allocPack()
	LDataPack.writeInt(dp, 2)
	LDataPack.writeInt(dp, 1)
    LDataPack.setPosition(dp, 0)
	ret = spiritF.equipSoul(actor, dp)	
end

-- TEST("test_spirit", "level", test_func.level)
-- TEST("test_spirit", "collectSoul", test_func.oneCollect)
TEST("test_spirit", "quickCollect", test_func.quickCollect)
-- TEST("test_spirit", "skillLevel", test_func.skillLevel)
-- TEST("test_spirit", "lock", test_func.lock)
-- TEST("test_spirit", "test_spirit", test_func.equip)

