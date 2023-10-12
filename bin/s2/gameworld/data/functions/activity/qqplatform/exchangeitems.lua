--[[
	author  = 'Roson'
	time    = 09.22.2015
	name    = 兑换
	ver     = 0.1
]]

module("activity.qqplatform.exchangeitems" , package.seeall)
setfenv(1, activity.qqplatform.exchangeitems)

local operations       = require("systems.activity.operations")
local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local actorevent       = require("actorevent.actorevent")

local ScriptTips = Lang.ScriptTips

require("protocol")
local sysId    = SystemId.yunyingActivitySystem
local protocol = YunyingActivityProtocal

require("activity.operationsconf")
local SubActConf = SubActConf
local EXCHANGE = SubActConf.EXCHANGE
local EXCHANGE_STR = tostring(EXCHANGE)

--------------------------------------------
--              ** DATA **
--------------------------------------------
function getConf(operId)
	local conf, isOnTime = operations.getConf(operId, EXCHANGE)
	if not conf or not conf.config then return end

	return conf.config, isOnTime
end

function getPlatVar(actor, operId, isClear)
	if not operId or operId <= 0 then return end

	local var = LActor.getPlatVar(actor)
	if not var then return end

	if var.exchangeitems == nil then var.exchangeitems = {} end
	local sVar = var.exchangeitems

	if sVar[operId] == nil or isClear then sVar[operId] = {} end
	return sVar[operId]
end

function clearPlatVar(actor, operId)
	if operId then
		getPlatVar(actor, operId, true)
	else
		local var = LActor.getPlatVar(actor)
		if not var then return end

		var.exchangeitems = nil
	end
end

--------------------------------------------
--               ** NET **
--------------------------------------------
function sendCountToActor(actor, operId)
	if not actor then return end

	local conf, isOnTime = getConf(operId)
	if not conf or not conf.changeConf or not isOnTime then return end

	local var = getPlatVar(actor, operId)

	if not var or not var.counts then return end

	local pack = LDataPack.allocPacket(actor, sysId, protocol.sSendExChangeCount)
	if not pack then return end

	local writeData = LDataPack.writeData
	writeData(pack, 2,
		dtInt, operId,
		dtChar, table.getnEx(conf.changeConf))

	for k,_ in pairs(conf.changeConf) do
		writeData(pack, 2,
			dtChar, k,
			dtChar, var.counts[k] or 0)
	end

	LDataPack.flush(pack)
end

function refreshCount(actor, operId)
	local conf, isOnTime = getConf(operId)
	if not conf or not conf.changeConf or not isOnTime then return end

	local var = getPlatVar(actor, operId)
	if var and not var.counts then
		var.counts = {}

		local cntVar = var.counts
		for id,c in pairs(conf.changeConf) do
			cntVar[id] = c.count
		end
 	end

	sendCountToActor(actor, operId)
end

function onGetExChangeCount(actor, pack)
	local operId = LDataPack.readData(pack, 1, dtInt)
	sendCountToActor(actor, operId)
end

--------------------------------------------
--              ** MAIN **
--------------------------------------------
function exChangeItem(actor, operId, indx)
	local conf, isOnTime = getConf(operId)

	if not conf or not isOnTime then return end

	local changeConf = conf.changeConf
	if not changeConf then return end

	--有没有可以兑换的id
	local exChangeIndxConf = changeConf[indx]
	if not exChangeIndxConf or not exChangeIndxConf.bef or not exChangeIndxConf.aft then return end

	--兑换数量检测
	local var = getPlatVar(actor, operId)
	if not var or not var.counts or not var.counts[indx] or var.counts[indx] <= 0 then return false, ScriptTips.exchange001 end

	--空格检测
	if Item.getBagEmptyGridCount(actor) < #exChangeIndxConf.aft then return false, ScriptTips.segg002 end

	--物品数量检测
	for i,itemConf in ipairs(exChangeIndxConf.bef) do
		local count = LActor.getItemCount(actor, itemConf.param, itemConf.bind or -1)
		if not (count >= itemConf.num) then return end
	end

	var.counts[indx] = var.counts[indx] - 1

	local tips = string.format("qqplatform_%d_%d", operId, EXCHANGE)
	--扣除
	for i,itemConf in ipairs(exChangeIndxConf.bef) do
		LActor.removeItem(actor, itemConf.param, itemConf.num, itemConf.quality or -1, itemConf.strong or -1, itemConf.bind or -1, tips, 783)
	end

	--兑换
	for i,itemConf in ipairs(exChangeIndxConf.aft) do
		LActor.addItem(actor, itemConf.param, itemConf.quality or 0, itemConf.strong or 0, itemConf.num, itemConf.bind or 1, tips, 784)
	end

	--发送结果
	sendCountToActor(actor, operId)

	return true
end

function onExChangeItem(actor, pack)
	local operId, indx = LDataPack.readData(pack, 2, dtInt, dtChar)

	local conf, isOnTime = getConf(operId)
	if not conf or not isOnTime then return end

	local ret, msg = exChangeItem(actor, operId, indx)
	if msg then
		LActor.sendTipmsg(actor, msg, ttMessage)
	end
end

function onStarOper(operId, begTime, endTime)
	local players = LuaHelp.getAllActorList()
	if not players or #players <= 0 then return end

	for _,player in ipairs(players) do
		clearPlatVar(player, operId)
		refreshCount(player, operId)
	end
end

function onCloseOper(operId, begTime, endTime)
	local players = LuaHelp.getAllActorList()
	if not players or #players <= 0 then return end

	for _,player in ipairs(players) do
		clearPlatVar(player, operId)
	end
end
--------------------------------------------
--              ** MISC **
--------------------------------------------
function refreshBaseFunc(actor, funcCallBack)
	if not System.isCommSrv() then return end

	local subConfs = operations.getSubActivitys(EXCHANGE)
	if not subConfs then return end

	for operId,_ in pairs(subConfs) do
		local conf, isOnTime = getConf(operId)
		if conf and isOnTime then
			local var = getPlatVar(actor, operId)
			if var then
				funcCallBack(actor, operId, var, conf)
			end
		else
			clearPlatVar(actor, operId)
		end
	end
end

function onNewDay(actor)
	local level = LActor.getRealLevel(actor)
	refreshBaseFunc(actor, function (actor, operId, var, conf)
		if conf.minLevel then
			if conf.minLevel <= level then
				var.counts = nil
				refreshCount(actor, operId)
			end
		else
			var.counts = nil
			refreshCount(actor, operId)
		end
	end)
end

function onLogin(actor)
	local level = LActor.getRealLevel(actor)
	refreshBaseFunc(actor, function (actor, operId, var, conf)
		if conf.minLevel then
			if conf.minLevel <= level then
				refreshCount(actor, operId)
			end
		else
			refreshCount(actor, operId)
		end
	end)
end

function onLevelUp(actor)
	local level = LActor.getRealLevel(actor)
	refreshBaseFunc(actor, function (actor, operId, var, conf)
		if conf.minLevel then
			if conf.minLevel == level then
				var.counts = nil
				refreshCount(actor, operId)
			end
		end
	end)
end
--------------------------------------------
--              ** REG **
--------------------------------------------

function regEvent( ... )
	local subConfs = operations.getSubActivitys(EXCHANGE)
	if not subConfs then return end

	for operId,_ in pairs(subConfs) do
		operations.regStartEvent(operId, onStarOper)
		operations.regCloseEvent(operId, onCloseOper)
	end
end

table.insert(InitFnTable, regEvent)

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeLevel, onLevelUp)
actorevent.reg(aeNewDayHoursArriveInCommSrv, onNewDay)

netmsgdispatcher.reg(sysId, protocol.cExChangeOne, onExChangeItem, true)
netmsgdispatcher.reg(sysId, protocol.cGetExChangeCount, onGetExChangeCount, true)

