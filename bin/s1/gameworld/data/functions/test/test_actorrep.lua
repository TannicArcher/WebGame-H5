-- Actor接口移植测试
module("test.test_actorrep" , package.seeall)
setfenv(1, test.test_actorrep)

local assert_func = require("test.assert_func")
local myMap = assert_func.myMap

local actorsys = require("systems.actorsystem.actorsys")
local act_base = require("systems.actorsystem.actorbase")
local actorfcm = require("systems.actorsystem.actorfcm")

local act_rep   = actorsys.rep

local GameLog       = act_base.GameLog

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


local boolAtt = {
	 false,true
}

local renownLogIds = {
	clRenowBuyItem               = 601,	--购买物品消耗声望
	clRenowQuestAward            = 602,	--任务奖励声望
	clRenownConsumeByUpgradeCamp = 603,	--升级阵营地位消耗声望
	clFbAwardRenown              = 604,	--副本奖励声望
	clItemGetRenown              = 605,	--物品添加声望
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

local function test_group_change(actor, func)
	local actorList = { actor } --包装
	--local initAndCallBack = createCallBack(test_group_changeRenown_base, func)
	myMap(
		func,
		actorList,		--actor列表
		symbolsAtt,		--数量
		symbolsAtt,		--数量
		boolAtt,		--是否是负数
		renownLogIds,	--记录日志的id
		{ "test" }		--测试标记
		)	--金钱的类型
end

--***********************************************
-------------------基本&环境 END-----------------
--***********************************************

--***********************************************
--README-------------changeX测试-----------------
--***********************************************

local function test_change_baseFunc(actor, property, func, callback)
	local property = property
	local func = func
	local callback = callback
	local maxNum = LActor.getIntProperty(actor, P_MAX_RENOWN)

	return function (actor, nDefValFlag, nValFlag, bSymbol, nLogId, sTest)
		local nDefVal = getIntVal(maxNum, nDefValFlag)--正数~0的随机
		LActor.setIntProperty(actor, property, nDefVal)

		local nVal = getIntVal(maxNum, nValFlag)
		nVal = getMinusValue(nVal, bSymbol)

		func(actor, nVal, nLogId, sTest)
		callback(actor, nDefVal, nVal, nLogId, sTest)
	end
end

local function test_change_callBack_baseFunc(p)
	local p = p
	return function (actor, nDefVal, nVal, nLogId, sTest)
		local nNowVal = LActor.getIntProperty(actor, p)
		local ret = nDefVal + nVal
		ret = math.max(0, ret)
		Assert(ret == nNowVal, string.format("when nDefVal:%d  nVal:%d  nNowVal:%d", nDefVal, nVal, nNowVal))
	end
end

local function test_changeRenown_callback(actor, nDefVal, nVal, nLogId, sTest)
	nVal = nVal * LActor.getRenowAddRate(actor)
	local nNowVal = LActor.getIntProperty(actor, P_RENOWN)
	local ret = nDefVal + nVal
	local maxNum = LActor.getIntProperty(actor, P_MAX_RENOWN)
	ret = math.min(maxNum, ret)
	ret = math.max(0, ret)
	Assert(ret == nNowVal, string.format("when P_MAX_RENOWN:%d nDefVal:%d  nVal:%d  nNowVal:%d", maxNum, nDefVal, nVal, nNowVal))
end



local function test_changeRenown(actor)
	local func = test_change_baseFunc(actor, P_RENOWN, act_rep.changeRenown, test_changeRenown_callback)
	test_group_change(actor, func)
end

local function test_changeHonor(actor)
	local callback = test_change_callBack_baseFunc(P_HONOR)
	local func = test_change_baseFunc(actor, P_HONOR, act_rep.changeHonor, callback)
	test_group_change(actor, func)
end

local function test_changeReputation(actor)
	local callback = test_change_callBack_baseFunc(P_SHENGWANG)
	local func = test_change_baseFunc(actor, P_SHENGWANG, act_rep.changeReputation, callback)
	test_group_change(actor, func)
end

local function test_changeCharm(actor)
	local callback = test_change_callBack_baseFunc(P_CHARM)
	local func = test_change_baseFunc(actor, P_CHARM, act_rep.changeCharm, callback)
	test_group_change(actor, func)
end



TEST("actorrep", "renown", test_changeRenown, true)
TEST("actorrep", "honor", test_changeHonor, true)
TEST("actorrep", "rep", test_changeReputation, true)
TEST("actorrep", "charm", test_changeCharm, true)



