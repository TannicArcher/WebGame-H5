-- Actor接口移植测试
module("test.test_actormoney" , package.seeall)
setfenv(1, test.test_actormoney)

local checkFunc = require("test.assert_func")
local myMap = checkFunc.myMap

local actorsys   = require("systems.actorsystem.actorsys")
local act_base   = require("systems.actorsystem.actorbase")
local actorevent = require("actorevent.actorevent")
local actorfcm   = require("systems.actorsystem.actorfcm")

local act_com   = actorsys.combat
local act_exp   = actorsys.exp
local act_misc  = actorsys.misc
local act_money = actorsys.money
local ACR_rep   = actorsys.rep

local GameLog       = act_base.GameLog
local moneyTypeDesc = act_money.moneyTypeDesc

local LDataPack = LDataPack
local LActor    = LActor
local System    = System


--***********************************************
--README---------------基本配置------------------
--***********************************************
local symbolsAtt = {
	'>', '<', '=', '0'
}

local fcmAtt = {
	0, 3, 5
}

local testAddRootExpLogId = {
	GameLog.clGetRootExp, 255,
}

local moneyTypes = {
	mtBindCoin,
	mtCoin,
	mtBindYuanbao,
	mtYuanbao,
}

local boolAtt = {
	 false,true
}

--***********************************************
--README--------------基本方法组-----------------
--***********************************************
local function createCallBack(func, callback)
	-- print("createCallBack")
	local func = func
	local callback = callback
	return function ( ... )
		func(...)
		callback(...)

	end
end

local function getIntVal(nVal, flag)
	local ret = 0
	if flag == '>' then
		ret = math.random(nVal, nVal * 5)

	elseif flag == '<' then
		ret = math.random(0, nVal)

	elseif flag == '=' then
		ret = nVal
	end
	return ret
end

local function getFloatVal(nVal, flag)
	local ret = 0

	if flag == '>' then
		ret = math.random(nVal * 100, nVal * 100 * 5) / 100

	elseif flag == '<' then
		ret = math.random(0, nVal * 100) / 100

	elseif flag == '=' then
		ret = nVal
	end
	return ret
end

local function getMinusValue(nVal ,isMinus)
	nVal = math.abs(nVal)
	if isMinus then nVal = -nVal end
	return nVal
end

local function setFcmState(actor, hour)
	local var = actorfcm.getStaticVar(actor)
	if hour == 0 then
		var.fcmHours = nil
	elseif hour == 3 then
		var.fcmHours = 1
	else
		var.fcmHours = 2
	end
end

--***********************************************
--README--------------构建环境-------------------
--***********************************************

local function test_group_changeMoney_base(actor)
	LActor.setIntProperty(actor, P_BIND_COIN, 0)
	LActor.setIntProperty(actor, P_COIN, 0)
	LActor.setIntProperty(actor, P_BIND_YB, 0)
	LActor.setIntProperty(actor, P_YB, 0)
end

local function test_group_changeMoney(actor, func)
	local actorList = { actor } --包装
	local initAndCallBack = createCallBack(test_group_changeMoney_base, func)

	myMap(
		initAndCallBack,
		actorList,	--actor列表
		moneyTypes,	--金钱类型
		symbolsAtt,	--金钱数量
		boolAtt,	--是否是负数
		symbolsAtt,	--当前金钱数量
		{ 1 },		--一般为1
		boolAtt,	--是否需要记录日志
		{"test"},	--日志LOG用
		boolAtt		--是否是充值得到的
		)	--金钱的类型
end

--***********************************************
-------------------基本&环境 END-----------------
--***********************************************

--***********************************************
--README-----------changeMoney测试---------------
--***********************************************
local function test_changeMoney_callback(actor, moneyType, nBefMoneyVal, nMoneyVal, nVal, needLog, sTest, sTest, sTest, sTest, sTest, ispay)
	local nNowVal = LActor.getMoneyCount(actor, moneyType)

	local str = string.format(" when type:%s bef:%d now:%d val:%d needLog:%s ispay:%s", moneyTypeDesc[moneyType], nBefMoneyVal, nNowVal, nMoneyVal, tostring(needLog),tostring(ispay))

	if nNowVal < 0 then
		--目前的钱币数量为负数异常
		Assert(false, string.format("%s -> %s", "code.0", str))

	elseif nMoneyVal < 0 then
		if -nMoneyVal > nBefMoneyVal then
			Assert(nNowVal == nBefMoneyVal, string.format("%s -> %s", "code.1", str))
		else
			Assert(nNowVal == (nBefMoneyVal + nMoneyVal), string.format("%s -> %s", "code.2", str))
		end
	end
end

local function test_changeMoney_func(actor, moneyType, nMoneyVal, bSymbol, nMoneyNowVal, nVal, needLog, sTest, ispay)
	--生成一个正负随机的数字
	nMoneyVal = getIntVal(10000, nMoneyVal)				--正数的随机
	nMoneyNowVal = getIntVal(nMoneyVal, nMoneyNowVal)	--产生一个数字用于当前金钱
	act_money.setMoney(actor, moneyType, nMoneyNowVal)
	local nNowVal = act_money.getMoney(actor, moneyType)

	nMoneyVal = getMinusValue(nMoneyVal, bSymbol)		--是否是正数

	coroutine.yield()
	act_money.changeMoney(actor, moneyType, nMoneyVal, nVal, needLog, sTest, sTest, sTest, sTest, sTest, ispay)

	test_changeMoney_callback(actor, moneyType, nMoneyNowVal, nMoneyVal, nVal, needLog, sTest, sTest, sTest, sTest, sTest, ispay)

end

local function test_changeMoney(actor)
	test_group_changeMoney(actor, test_changeMoney_func)
	print("bingo")
end


local function test_reg_changeYB_callBack(actor, nMoneyVal, phylum, classField)
	Assert_eq(LActor.getEntityType(actor), EntityType_Actor, "actor is err param")
	Assert_eq(nMoneyVal, 500, "nMoneyVal is err param")
	Assert_eq(phylum, "sTest", "phylum is err param")
	Assert_eq(classField, "sTest", "classField is err param")
end

local function test_reg_changeYB(actor)
	act_money.setMoney(actor, mtYuanbao, 2000)
	local sTest = "sTest"
	act_money.changeMoney(actor, mtYuanbao, -500, 1, true, sTest, sTest, sTest, sTest, sTest, true)
end


TEST("actormoney", "changemoney", test_changeMoney, true)
TEST("actormoney", "changeyb", test_reg_changeYB, true)

--注册测试调用
--actorevent.reg(aeConsumeYuanbao, test_reg_changeYB_callBack)


