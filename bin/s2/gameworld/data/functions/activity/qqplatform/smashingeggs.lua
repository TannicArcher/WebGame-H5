--[[
	author  = 'Roson'
	time    = 09.19.2015
	name    = 砸蛋
	ver     = 0.1
]]

module("activity.qqplatform.smashingeggs" , package.seeall)
setfenv(1, activity.qqplatform.smashingeggs)

local operations       = require("systems.activity.operations")
local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local actorevent       = require("actorevent.actorevent")

local ScriptTips = Lang.ScriptTips

local FULL_EGGS = 0xFF
local BASE_EGG_COUNT, MAX_EGG_COUNT = 1, 8

require("protocol")
local sysId    = SystemId.yunyingActivitySystem
local protocol = YunyingActivityProtocal

require("activity.operationsconf")
local SubActConf = SubActConf
local SMASHING_EGG = SubActConf.SMASHING_EGG
local SMASHING_EGG_STR = tostring(SMASHING_EGG)

function getConf(operId)
	local conf, isOnTime = operations.getConf(operId, SMASHING_EGG)
	if not conf or not conf.config then return end

	return conf.config, isOnTime
end

function getPlatVar(actor, operId, isClear)
	if not operId or operId <= 0 then return end

	local var = LActor.getPlatVar(actor)
	if not var then return end

	if var.smashingeggs == nil then var.smashingeggs = {} end
	local sVar = var.smashingeggs

	if sVar[operId] == nil or isClear then sVar[operId] = {} end
	return sVar[operId]
end

function clearPlatVar(actor, operId)
	if operId then
		getPlatVar(actor, operId, true)
	else
		local var = LActor.getPlatVar(actor)
		if not var then return end

		var.smashingeggs = nil
	end
end

function sendPosToActor(actor, operId)
	local var = getPlatVar(actor, operId)
	if not var or not var.eggPos then return end

	local pack = LDataPack.allocPacket(actor, sysId, protocol.sEggState)
	if not pack then return end

	LDataPack.writeData(pack, 3,
		dtInt, operId,
		dtChar, var.eggPos,
		dtChar, var.refreshCount or 0)

	LDataPack.flush(pack)
end

function sendItemToActor(actor, operId)
	local var = getPlatVar(actor, operId)
	if not var or not var.itemList or not var.eggPos then return end

	local eggCount, fullEgg, hasEgg = getEggCount(var.eggPos)
	local hasCount = MAX_EGG_COUNT - eggCount
	if hasCount <= 0 then return end

	local pack = LDataPack.allocPacket(actor, sysId, protocol.sSmashingEggRet)
	if not pack then return end

	local writeData = LDataPack.writeData
	writeData(pack, 1,
		dtChar, hasCount)

	for _,pos in ipairs(hasEgg) do
		writeData(pack, 2,
			dtChar, pos,
			dtInt, var.itemList[pos] or 0)
	end

	LDataPack.flush(pack)
end

function refreshEggPos(actor, operId)
	local conf, isOnTime = getConf(operId)
	if not conf or not isOnTime then return end

	local level = LActor.getRealLevel(actor)
	if conf.minLevel and conf.minLevel > level then
		return
	end

	local var = getPlatVar(actor, operId)
	if not var then return end

	var.eggPos = FULL_EGGS
	var.itemList = {}
	sendPosToActor(actor, operId)
end

--随机给予奖励
function sendAwards(actor, count, awardsConf, pos, usingItemCount, tips)
	local itemList = {}

	for i=1,count do
		local itemConf = table.getrandomitem(awardsConf)
		if itemConf then
			local bindFlag = false
			if usingItemCount and usingItemCount > 0 then
				usingItemCount = usingItemCount - 1
				bindFlag = true
			end
			LActor.addItem(actor, itemConf.param, itemConf.quality or 0, itemConf.strong or 0, itemConf.num, bindFlag and 1 or 0, tips, 788)
			table.insert(itemList, itemConf.param)
			if itemConf.broad then
				System.broadcastTipmsg(string.format(ScriptTips.segg004, LActor.getActorLink(actor), Item.getItemLink(itemConf.param)), ttHearsay)
			end
		end
	end

	return itemList
end

function getEggCount(eggPos)
	local count = 0
	local fullEgg = {}
	local hasEgg = {}

	for i=0,MAX_EGG_COUNT - 1 do
		if System.bitOPMask(eggPos, i) then
			count = count + 1
			table.insert(fullEgg, i + 1)
		else
			table.insert(hasEgg, i + 1)
		end
	end

	return count, fullEgg, hasEgg
end

function doSmashing(actor, operId, pos)
	local conf, isOnTime = getConf(operId)
	if not conf or not conf.awardsConf or not isOnTime then return end

	local level = LActor.getRealLevel(actor)
	if conf.minLevel and conf.minLevel > level then
		return
	end

	local var = getPlatVar(actor, operId)
	if not var or not var.eggPos or not var.refreshCount then return end

	if var.eggPos == 0 then
		return false, ScriptTips.segg003
	end

	--验证
	if pos ~= 0 and not System.bitOPMask(var.eggPos, pos - 1) then
		--如果位置上是空则
		return false, ScriptTips.segg003
	end

	local count = BASE_EGG_COUNT
	local fullEgg = {pos}
	if pos == 0 then
		count, fullEgg = getEggCount(var.eggPos)
	end

	if Item.getBagEmptyGridCount(actor) < count then return false, ScriptTips.segg002 end

	--这里修改为优先使用锤子
	local usingMoneyCount = count
	local usingItemCount = 0

	local goldenHammerId = conf.goldenHammerId
	if goldenHammerId then
		local itemCount = LActor.getItemCount(actor, goldenHammerId)
		if itemCount > 0 then
			usingMoneyCount = math.max(usingMoneyCount - itemCount, 0)
			usingItemCount = count - usingMoneyCount
		end
	end

	local min_Count = usingMoneyCount * conf.onceCnt
	local moneyCount = LActor.getMoneyCount(actor, conf.moneyType)

	if moneyCount < min_Count then
		return false, ScriptTips.segg001
	end

	local tips = string.format("qqplatform_%d_%d", operId, SMASHING_EGG_STR)
	LActor.changeMoney(actor, conf.moneyType, -min_Count, 1, true, tips, "smashingeggs")

	if usingItemCount > 0 then
		LActor.removeItem(actor, goldenHammerId, usingItemCount, -1, -1, -1, tips, 787)
	end

	if pos == 0 then
		var.eggPos = 0
	else
		var.eggPos = System.bitOpSetMask(var.eggPos, pos - 1, false)
	end

	local itemList = sendAwards(actor, count, conf.awardsConf, pos, usingItemCount, tips)

	--保存砸蛋的记录
	if var.itemList == nil then var.itemList = {} end

	for i=1,#fullEgg do
		local pos = fullEgg[i]
		local itemId = itemList[i] or 0
		var.itemList[pos] = itemId
	end

	sendPosToActor(actor, operId)
	sendItemToActor(actor, operId)

	return true
end

function onDoSmashing(actor, pack)
	if not System.isCommSrv() then return end
	if not pack then return end

	local operId, pos = LDataPack.readData(pack, 2, dtInt, dtChar)

	if pos > 8 then return end
	local ret, msg = doSmashing(actor, operId, pos)
	if msg then
		LActor.sendTipmsg(actor, msg, ttMessage)
	end
end

function onRefeshEggState(actor, pack)
	if not System.isCommSrv() then return end

	local operId = LDataPack.readData(pack, 1, dtInt)

	local conf, isOnTime = getConf(operId)
	if not conf or not isOnTime then return end

	local var = getPlatVar(actor, operId)
	if not var or var.eggPos ~= 0 then return end
	if not var.refreshCount or var.refreshCount <= 0 then
		LActor.sendTipmsg(actor, ScriptTips.segg005, ttMessage)
		return
	end

	var.refreshCount = var.refreshCount - 1
	refreshEggPos(actor, operId)
end

--砸蛋
--当前蛋的属性
function onStarOper(operId, begTime, endTime)
	local players = LuaHelp.getAllActorList()
	if not players or #players <= 0 then return end

	local conf, isOnTime = getConf(operId)
	if not conf or not isOnTime then return end

	for _,player in ipairs(players) do
		local var = getPlatVar(player, operId)
		if var then
			var.refreshCount = conf.refreshCount
		end
		refreshEggPos(player, operId)
	end
end

function onCloseOper(operId, begTime, endTime)
	local players = LuaHelp.getAllActorList()
	if not players or #players <= 0 then return end

	for _,player in ipairs(players) do
		clearPlatVar(player, operId)
	end
end

function onLogin(actor)
	if not System.isCommSrv() then return end

	local subConfs = operations.getSubActivitys(SMASHING_EGG)
	if not subConfs then return end

	for operId,_ in pairs(subConfs) do
		local conf, isOnTime = getConf(operId)
		if not conf or not isOnTime then
			clearPlatVar(actor, operId)
		elseif isOnTime then
			local var = getPlatVar(actor, operId)
			if var and var.closeTime ~= isOnTime then
				var.refreshCount = conf.refreshCount
				var.closeTime = isOnTime
				refreshEggPos(actor, operId)
			end
			sendPosToActor(actor, operId)
			sendItemToActor(actor, operId)
		end
	end
end

function onLevelUp(actor)
	if not System.isCommSrv() then return end

	local subConfs = operations.getSubActivitys(SMASHING_EGG)
	if not subConfs then return end

	local level = LActor.getRealLevel(actor)
	for operId,_ in pairs(subConfs) do
		local conf, isOnTime = getConf(operId)
		if conf and isOnTime then
			if conf.minLevel then
				if conf.minLevel == level then
					refreshEggPos(actor, operId)
				end
			end
		end
	end
end

function onReset(actor)
	if not System.isCommSrv() then return end

	local subConfs = operations.getSubActivitys(SMASHING_EGG)
	if not subConfs then return end

	local level = LActor.getRealLevel(actor)
	for operId,_ in pairs(subConfs) do
		local conf, isOnTime = getConf(operId)
		if not conf or not isOnTime then
			clearPlatVar(actor, operId)
		elseif isOnTime then
			local var = getPlatVar(actor, operId)
			if var then
				var.refreshCount = conf.refreshCount
				refreshEggPos(actor, operId)
			end
			sendPosToActor(actor, operId)
			sendItemToActor(actor, operId)
		end
	end
end

function regEvent( ... )
	local subConfs = operations.getSubActivitys(SMASHING_EGG)
	if not subConfs then return end

	for operId,_ in pairs(subConfs) do
		operations.regStartEvent(operId, onStarOper)
		operations.regCloseEvent(operId, onCloseOper)
	end
end

table.insert(InitFnTable, regEvent)

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeLevel, onLevelUp)
actorevent.reg(aeNewDayHoursArriveInCommSrv, onReset)

netmsgdispatcher.reg(sysId, protocol.cSmashingEgg, onDoSmashing, true)
netmsgdispatcher.reg(sysId, protocol.cRefreshEggState, onRefeshEggState, true)
