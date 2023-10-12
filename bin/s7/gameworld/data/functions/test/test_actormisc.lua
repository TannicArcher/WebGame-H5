-- Actor接口移植测试
module("test.test_actormisc" , package.seeall)
setfenv(1, test.test_actormisc)

local checkFunc = require("test.assert_func")
local myMap = checkFunc.myMap

local actorsys = require("systems.actorsystem.actorsys")
local act_base = require("systems.actorsystem.actorbase")

local act_misc  = actorsys.misc
-- local act_money = actorsys.money

--***********************************************
--README---------------基本配置------------------
--***********************************************
local symbolsAtt = {
	'>', '<', '=', '0'
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

local function getMinusValue(nVal ,isMinus)
	nVal = math.abs(nVal)
	if isMinus then nVal = -nVal end
	return nVal
end

local function getVip(val)
	local vipLevel = 0
	for i,v in ipairs(VIPConfig.yuanbaos) do
		if v > val then break end
		vipLevel = i
	end
	return vipLevel
end

local function setRechargeAndVip(actor, para)
	LActor.setIntProperty(actor, P_RECHARGE, para[2])
	local vip = getVip(para[2])
	LActor.setIntProperty(actor, P_VIP_LEVEL, vip)
	return vip
end

--***********************************************
--README--------------构建环境-------------------
--***********************************************
local function test_group_charge_base(actor)
	-- * 初始化环境
	LActor.setIntProperty(actor, P_VIP_LEVEL, 0)
end

-- * func为结果执行函数，其会在初始化完成后执行
local function test_group_charge(actor, func)
	local actorList = { actor } --包装
	local initAndCallBack = createCallBack(test_group_charge_base, func)

	local VIPConfig = VIPConfig

	local ybs = { {0, 0} }

	for i,v in ipairs(VIPConfig.yuanbaos) do
		local m = VIPConfig.yuanbaos[i+1] or 300000
		local k = {i, v}
		table.insert(ybs, k)
	end

	-- * 初始化环境
	myMap(
		initAndCallBack,
		actorList,				--转换成数组的actor
		ybs,					--元宝
		symbolsAtt,				--初始元宝数量
		symbolsAtt,				--增加元宝数量
		boolAtt)				--增加的元宝为负数
end

--***********************************************
-------------------基本&环境 END-----------------
--***********************************************

--***********************************************
--README------------Recharge测试-----------------
--***********************************************

local function test_charge_callback(actor, lv_vip, nBefVal, nVal)
	local nNowVal = LActor.getIntProperty(actor, P_RECHARGE)
	local vip = LActor.getIntProperty(actor, P_VIP_LEVEL)

	if nVal <= 0 then
		Assert(nNowVal == nBefVal,"recharge value is err. nVal <= 0")

	else
		local v = getVip(nNowVal)
		Assert(v == vip ,"recharge value is err. nVal > 0")
	end
end

local function test_charge_func(actor, ybs, nDefValFlag, nValFlag, bValSymbol)
	local nDefVal = getIntVal(10000, nDefValFlag)

	ybs[2] = ybs[2] + nDefVal
	ybs[1] = setRechargeAndVip(actor, ybs)

	local nVal = getIntVal(100000, nValFlag)
	nVal = getMinusValue(nVal, bValSymbol)

	act_misc.onRecharge(actor, nVal)
	test_charge_callback(actor, lv_vip, ybs[2], nVal)
end

local function test_charge(actor)
	print("start")
	test_group_charge(actor, test_charge_func)
	print("bingo")
end

--***********************************************
--README------------OpenSys测试------------------
--***********************************************

local function changeSysStatus(actor, sysId, open)
	if open then
		act_misc.openSys(actor, sysId)
		return
	end

	if sysId < 0 or sysId >= siSysMAX then return end
	local sysOpen = LActor.getIntProperty(actor, P_SYS_OPEN)
	local mask = System.bitOpLeft(0x1, sysId)
	local maskNot = System.bitOpNot(mask)
	mask = System.bitOpAnd(maskNot, sysOpen)

	LActor.setIntProperty(actor, P_SYS_OPEN, mask)
end

local function isOpenSys(actor, sysId)
	if sysId < 0 or sysId >= siSysMAX then return end

	local sysOpen = LActor.getIntProperty(actor, P_SYS_OPEN)
	local mask = System.bitOpLeft(0x1, sysId)
	local sysOpen_t = System.bitOpAnd(sysOpen, mask)
	-- print("sysOpen_t:"..sysOpen_t)
	return sysOpen_t > 0
end

-- * func为结果执行函数，其会在初始化完成后执行
local function test_group_opensys(actor, func)
	local actorList = { actor } --包装

	-- * 初始化环境
	myMap(
		func,
		actorList,				--转换成数组的actor
		{13,5,99},				--系统编号
		boolAtt,				--开启或者关闭
		boolAtt)				--再次执行的开关操作
end

local function test_opensys_callback(actor, sysId, isOpen, times)
	local str = string.format("sysId:%s isOpen:%s num:%s ret:%s",sysId, tostring(isOpen), times, tostring(isOpenSys(actor, sysId)))
	if sysId < 0 or sysId >= siSysMAX then
		Assert(not isOpenSys(actor, sysId),string.format("%s,%s", "haven some err in openSys.", str))
		return
	end
	Assert(isOpen == isOpenSys(actor, sysId),string.format("%s,%s", "haven some err in openSys.", str))
end

local function test_opensys_init(actor, sysId, isOpen_1, isOpen_2)
	changeSysStatus(actor, sysId, false)
	changeSysStatus(actor, sysId, isOpen_1)
	test_opensys_callback(actor, sysId, isOpen_1, 1)
	changeSysStatus(actor, sysId, isOpen_2)
	test_opensys_callback(actor, sysId, isOpen_2, 2)
end

local function test_opensys(actor)
	test_group_opensys(actor, test_opensys_init)
	print("bingo")
end



TEST("actormisc", "recharge", test_charge, true)
TEST("actormisc", "opensys", test_opensys, true)




