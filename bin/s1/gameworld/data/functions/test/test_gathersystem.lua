-- 采集系统测试
module("test.test_gathersystem" , package.seeall)
setfenv(1, test.test_gathersystem)
local gsys = require("systems.gathersystem.gathersystem") --采集系统
local checkFunc = require("test.assert_func") --测试方法

local LDataPack = LDataPack
local LActor    = LActor
local Fuben     = Fuben
local System    = System
local LuaHelp   = LuaHelp

local FIX_RONDOM = 5
--***********************************************
--README--------------基本方法组-----------------
--***********************************************
--采集后不会死亡的怪物
local gatherIdsLive = {
	12, 18, 2, 22, 253, 254,
}

local normalIds = {
	938, 1010, 1019
}

--采集后会死亡的怪物
local gatherIdsDie = {
	1071,
}

local boolAtt = {
	true, false
}

--在人物附近创建一个怪物
local function createMonster(actor, x, y, monId)
	--local x, y = LActor.getEntityPosition(actor)
	local hScene = LActor.getSceneHandle(actor)
	return Fuben.createMonster(hScene, monId, x ,y, 0)
end


--清除人物附近的怪物
local function clearMonster(actor, monId)
	local pScene = LActor.getScenePtr(actor)
	if not pScene then return end
	local x, y = LActor.getEntityPosition(actor)
	local range = 30
	local etyList = LuaHelp.getEntityListFromRange(pScene, x - range, y - range, x + range, y + range)
	if etyList == nil or #etyList < 1 then return end
	for _,ety in pairs(etyList) do
		local mHandle = LActor.getHandle(ety)
		local mType = LActor.getEntityType(ety)
		if monId and Fuben.getMonsterId(ety) == monId then
			Fuben.clearEntity(mHandle, false)
		elseif mType == EntityType_GatherMonster or mType == EntityType_Monster then
			Fuben.clearEntity(mHandle, false)
		end
	end
end


--获取人物所在位置
local getPos = LActor.getEntityPosition

local function getFixNumber(num)
	if checkFunc.getRandomOne(boolAtt) then return num
	else
		return -num
	end
end
--计算一个偏移
local function getFixRet(defx, defy, fix)
	local x = defx + getFixNumber(math.random(fix, 2 * fix))
	local y = defy + getFixNumber(math.random(fix, 2 * fix))
	return x, y
end
--获取在人物范围内的点
local function getActorfixPos(actor, fix)
	if not fix then fix = FIX_RONDOM end
	local x, y = getPos(actor)
	return getFixRet(x, y, fix)
end

--***********************************************
--README--------------构建环境-------------------
--***********************************************

local mountAtt = boolAtt --上下马测试

--怪物生成配置
local groupAtt = {
	--没有怪物
	{ state = "no gather", monIds = {}, isfar = false, ret =false },
	--可以采集怪物,过远
	{ state = "gather too far", monIds = gatherIdsLive, isfar = true, ret = false },
	--不可采集怪物,在采集范围内
	{ state = "isn't gather", monIds = normalIds, isfar = false, ret = false },
	--不可采集怪物,不在采集范围内
	{ state = "isn't gather and too far", monIds = normalIds, isfar = true, ret = false },
	--可以采集怪物,在采集范围内,采集判定结果
	{ state = "can gather", monIds = gatherIdsLive, isfar = false, ret = true },
}

--**设置其上下马**
local function setMount(actor, isRide)
	if isRide then LActor.addState(actor, esStateRide)
	else LActor.removeState(actor, esStateRide)
	end
	coroutine.yield()
end

--**创建一个怪在人物周围**
--not isfar -->重合创建
--isfar     -->距离5-10创建
local function createGather(actor, monIds, isfar)
	local fix = 5
	if not monIds then monIds = gatherIdsLive end
	if not isfar then fix = 0 end
	local x, y = getActorfixPos(actor, fix)
	local monId = checkFunc.getRandomOne(monIds)
	local monster
	if monId then monster = createMonster(actor, x, y, monId) end
	return x, y, monId, monster
end

--README **产生不同的测试环境**
--***************************
--范围内木有怪物
--范围内有怪物但是不可采集
--范围外有怪物且可以采集
--有可采集的怪物但是在范围外
--有不可采集的怪物且在范围外
--上下马逻辑在C++内处理
--***************************
local function test_Group(actor, checkFunc, ... )
	--local mon_last
	for _,conf in pairs(groupAtt) do
		for _,state in pairs(mountAtt) do
			--清除场景内的怪物
			--设置骑乘状态
			setMount(actor, state)
			local x, y, monId, mon = createGather(actor, conf.monIds, conf.isfar)
			coroutine.yield()
			checkFunc(actor, x, y, monId, mon, conf, ...)
			clearMonster(actor)
			--mon_last = monId
		end
	end
end

--***********************************************
-------------------基本&环境 END-----------------
--***********************************************

--***********************************************
--README--------------采集测试-------------------
--***********************************************

local function get_normal_pack(actor, mon, x, y)
	local mHandle = LActor.getHandle(mon)
	local pack = LDataPack.test_allocPack()
	LDataPack.writeData(pack, 4,
		dtInt64, mHandle,
		dtInt, x,
		dtInt, y,
		dtInt, 1)
	LDataPack.setPosition(pack, 0)
	return pack
end

--TODO 正常采集测试
local function test_gather_normal(actor, x, y, monId, mon, conf, ...)
	if mon then
		LActor.setEntityTarget(actor, mon)
	end
	local pack = get_normal_pack(actor, mon, x, y)
	gsys.onStartGather(actor, pack)
	Assert(gsys.isGathering(actor) == conf.ret , string.format("[Bef]:Actor gather state is %s.<--%s", tostring(conf.ret), conf.state))
	coroutine.yield()
	--README 采集结果延后判定
	local checkTime = System.getNowTime() + 2
	local time_now
	-- TODO 延后到执行完成后再检测
	repeat
		time_now = System.getNowTime()
		coroutine.yield()
	until checkTime <= time_now
	Assert(not gsys.isGathering(actor), string.format("[Aft]:Actor still in the gather state.<--%s",conf.state))
	--Assert(gsys.isThisGatherFinish(actor) == conf.ret, "[NORMAL]:Actor no gather is complete.")
end

--测试采集的方法
local function test_gather(actor)
	test_Group(actor, test_gather_normal)
	clearMonster(actor)
end

TEST("gather", "test_gather", test_gather, true)



