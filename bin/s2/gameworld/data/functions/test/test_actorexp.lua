-- Actor接口移植测试
module("test.test_actorexp" , package.seeall)
setfenv(1, test.test_actorexp)

local assert_func = require("test.assert_func")
local myMap = assert_func.myMap

local actorsys = require("systems.actorsystem.actorsys")
local act_base = require("systems.actorsystem.actorbase")
local actorfcm = require("systems.actorsystem.actorfcm")

local act_com   = actorsys.combat
local act_exp   = actorsys.exp
local act_misc  = actorsys.misc
local act_money = actorsys.money
local ACR_rep   = actorsys.rep

local GameLog = act_base.GameLog


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

local testAddExpLogIds = {
	GameLog.clCampBattleExp,
	GameLog.clKillMonsterExp,
	GameLog.clPracticeExp,
	GameLog.clCongratulation,
	255,
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
		-- print("beginCallBack")
		-- print(unpack(arg))
		callback(...)
		-- print("beginCallBack_END")
		-- coroutine.yield()
	end
end

local lastLive
local function setDeath(actor, isLive)
		-- print("setDeath")
	local maxHp = LActor.getIntProperty(actor, P_BASE_MAXHP)
	if maxHp == 0 then LActor.setIntProperty(actor, P_BASE_MAXHP, 4453) end
	local hp = LActor.getIntProperty(actor, P_BASE_MAXHP)
	if isLive == false then hp = 0 end
	if lastLive ~= isLive then
		coroutine.yield()
	end
	lastLive = isLive
	LActor.setIntProperty(actor, P_HP, hp)
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
--root_exp 测试环境
local function test_group_live_base(actor, isLive)
	-- print("actor is live -->"..tostring(isLive))
	setDeath(actor, isLive)
end

local function test_group_decExp_base(actor)
	LActor.setIntProperty(actor, P_LEVEL, 60)
	LActor.setIntProperty(actor, P_EXP, 0)
end

-- * func为结果执行函数，其会在初始化完成后执行
local function test_group_rootExp(actor, func)
	-- print("test_group_rootExp")
	local actorList = { actor } --包装
	local initAndCallBack = createCallBack(test_group_live_base, func)
	-- * 初始化环境
	LActor.setIntProperty(actor, P_ROOT_EXP, math.random(0, 10000))
	myMap(
		initAndCallBack,
		actorList,				--转换成数组的actor
		boolAtt,				--人物是否是活着的
		testAddRootExpLogId,	--日志ID
		symbolsAtt,				--增加的经验
		boolAtt,				--增加的经验是否为负数(异常)
		symbolsAtt,				--增加经验的倍率
		boolAtt)				--增加经验的倍率是否为负数(异常)
	setDeath(actor, true)
	-- print("test_group_rootExp_end")
end

local function test_group_addExp(actor, func)
	local actorList = { actor } --包装
	local initAndCallBack = createCallBack(test_group_live_base, func)
	LActor.setIntProperty(actor, P_LEVEL, 60)
	LActor.setIntProperty(actor, P_EXP, math.random(0, 10000))
	setFcmState(actor, 0)
	myMap(
		initAndCallBack,	--初始化方法
		actorList,			--actor列表
		boolAtt,			--是否活着
		symbolsAtt,			--增加的经验
		testAddExpLogIds,	--经验增加的方式
		boolAtt,			--世界经验加成
		-- --boolAtt,			--是否有棒棒糖
		-- --boolAtt,			--是否有经验buff
		fcmAtt)				--处于防沉迷的状态
end

local function test_group_decExp(actor, func)
	local actorList = { actor } --包装
	local initAndCallBack = createCallBack(test_group_decExp_base, func)
	myMap(
		initAndCallBack,
		actorList,	--actor列表
		symbolsAtt)	--经验是否满足扣除
end



--***********************************************
-------------------基本&环境 END-----------------
--***********************************************

--***********************************************
--README--------------combat测试-----------------
--***********************************************

local function test_anger(actor)
	--for i=1,100 do
		local anger = math.random(-100, 100)
		act_com.changeAnger(actor, anger)
		--coroutine.yield()
	--end
end

--***********************************************
--README-------------rootExp测试-----------------
--***********************************************
local function test_rootExp_callback(actor, isLive, nWay, nBefExpVal, nExpVal, fRate)
	local  nNowVal = LActor.getIntProperty(actor, P_ROOT_EXP)
	if fRate <= 0 then fRate = 0 end
	local offset =  (nBefExpVal - nNowVal)
	if nWay == GameLog.clGetRootExp or nWay == GameLog.clMapAreaRoot then
		offset = math.floor(offset * fRate)
	end
	Assert((offset == 0) or (isLive ~= (offset == nExpVal)), string.format("rootExp add Exp haven some err. when actor live is %s BefVal:%d , NowVal: %d, addVal:%d,  rate:%s", tostring(isLive), nBefExpVal, nNowVal, nExpVal, fRate))
end

local function test_rootExp_func(actor, isLive, nLogId, nExpValSymbol, isMinusExpVal, nRateSymbol, isMinusRate)
	local nExpVal = getIntVal(1000, nExpValSymbol)
	nExpVal = getMinusValue(nExpVal, isMinusExpVal)

	local fRate = getFloatVal(1, nRateSymbol)
	fRate = getMinusValue(fRate, isMinusRate)

	local nBefExpVal = LActor.getIntProperty(actor, P_ROOT_EXP)
	-- print(act_exp.addRootExp)
	act_exp.addRootExp(actor, nExpVal, nLogId, nRate)
	-- coroutine.yield()
	test_rootExp_callback(actor, isLive, nLogId, nBefExpVal ,nExpVal, fRate)
	-- print("test_rootExp_func_end")
end

local function test_rootExp(actor)
	test_group_rootExp(actor, test_rootExp_func)
end

--***********************************************
--README---------------Exp测试-------------------
--***********************************************
--TODO 测试有问题，暂时暂停
local function test_addExp_callback(actor, isLive, nLogId, nBefExpVal ,nExpVal, bWorldRate, fcm)
	-- print("test_addExp_callback")
	local  nNowVal = LActor.getIntProperty(actor, P_EXP)
	local offset = nNowVal - nBefExpVal
	if not isLive then offset = 0 end

	local str = string.format("actor live is %s, longID %s, BefVal:%s , NowVal: %s, addVal:%s,  rate:%s, fcm %s ", tostring(isLive), nLogId, nBefExpVal, nNowVal, nExpVal, tostring(bWorldRate), fcm)
	Assert(((not isLive or fcm == 5) and (offset == 0)) or (fcm > 0 and fcm < 5 and offset ~= nExpVal) or (offset == nExpVal), str)
end

local function test_addExp_func(actor, isLive, nExpValSymbol, nLogId, bWorldRate, fcm)
	-- print("test_addExp_func")
	local nExpVal = getIntVal(1000, nExpValSymbol)
	local nBefExpVal = LActor.getIntProperty(actor, P_EXP)

	setFcmState(actor, fcm)
	act_exp.addExp(actor, nExpVal, nLogId, 0, bWorldRate)
	test_addExp_callback(actor, isLive, nLogId, nBefExpVal ,nExpVal, bWorldRate, fcm)
end

local function test_decExp_callBack(actor,nBefExpVal, decExpVal)
	local nNowVal = LActor.getIntProperty(actor, P_EXP)
	if decExpVal > nBefExpVal then
		Assert(nNowVal == nBefExpVal, "error, never dec Exp.")
	else
		local offset = nBefExpVal - nNowVal
		Assert(offset == decExpVal, "error, dec Exp haven some err.")
	end
end

local function test_decExp_func(actor, isEnough)
	local exp = math.random(10000, 100000)
	LActor.setIntProperty(actor, P_EXP, exp)
	local decExpVal = getIntVal(exp, isEnough)
	act_exp.decExp(actor, decExpVal)
	test_decExp_callBack(actor, exp, decExpVal)
	--local nBefExpVal = LActor.getIntProperty(actor, P_EXP)

end

local function test_addExp(actor)
	test_group_addExp(actor, test_addExp_func)
	--TODO 后续补充宠物经验测试
end

local function test_decExp(actor)
	test_group_decExp_base(actor, test_decExp_func)
	--print("bingo")
end


--***********************************************
--README---------------升级测试------------------
--***********************************************
local testLv = {5, 20, 50, #LevelUpExp}

local function test_upLv(actor)
	for _,v in pairs(testLv) do
		local exp = LevelUpExp[v + 1]
		if not exp then break end

		LActor.setIntProperty(actor, P_LEVEL, v)
		LActor.setIntProperty(actor, P_EXP, exp - 2)

		act_exp.addExp(actor, 102, GameLog.clKillMonsterExp, 0, false)

		local nowLv = LActor.getIntProperty(actor, P_LEVEL)
		local nowExp = LActor.getIntProperty(actor, P_EXP)
		local str = string.format("befLv:%s nowLv:%s, befExp:%s nowExp:%s",v, nowLv, exp - 2, nowExp)

		if v == #LevelUpExp then
			Assert(nowLv == #LevelUpExp, string.format("%s%s","[max] up level haven some err.", str))
			Assert(nowExp == LevelUpExp[v], string.format("%s%s","[max] add exp haven some err.", str))
		else
			Assert(nowLv == v + 1, string.format("%s%s","[lv] up level haven some err.", str))
			Assert(nowExp == 100, string.format("%s%s","[lv] sadd exp haven some err.", str))
		end
	end
end

local function test_uplv_more(actor)
	local maxLevel = GlobalConfig.maxPlayerLevel
	local maxExp = LevelUpExp[#LevelUpExp]

	for _,v in pairs(testLv) do

		LActor.setIntProperty(actor, P_LEVEL, v)
		LActor.setIntProperty(actor, P_EXP, 0)

		local exp = math.random(1000000, 1000000000)
		act_exp.addExp(actor, exp, GameLog.clKillMonsterExp, 0, false)

		local uplv = 0
		for i = v, 255 do
			local up_exp = LevelUpExp[i + 1]
			if not up_exp then break end
			if exp >= up_exp and v < maxLevel then
				exp = exp - up_exp
				uplv = uplv + 1
			else
				if exp > maxExp then
					exp = maxExp
				end
				break
			end
		end

		local nowLv = LActor.getIntProperty(actor, P_LEVEL)
		local nowExp = LActor.getIntProperty(actor, P_EXP)

		local str = string.format("befLv:%s nowLv:%s, befExp:%s nowExp:%s",v, nowLv, 0, nowExp)

		if v == #LevelUpExp then
			Assert(nowLv == #LevelUpExp, string.format("%s%s","[max] up level haven some err.", str))
			Assert(nowExp == exp, string.format("%s%s","[max] add exp haven some err.", str))
		else
			Assert(nowLv == v + uplv, string.format("%s%s","[lv] up level haven some err.", str))
			Assert(nowExp == exp, string.format("%s%s","[lv] sadd exp haven some err.", str))
		end
	end
end

--TEST("actorsys", "test_anger",  test_anger, true)
TEST("actorexp", "rootexp", test_rootExp, true)
TEST("actorexp", "addexp", test_addExp, true)
TEST("actorexp", "decexp", test_decExp, true)
TEST("actorexp", "uplv", test_upLv, true)
TEST("actorexp", "uplvmore", test_uplv_more, true)



