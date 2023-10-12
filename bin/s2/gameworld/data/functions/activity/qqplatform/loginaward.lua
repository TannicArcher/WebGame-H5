--[[
	author  = 'Roson'
	time    = 09.22.2015
	name    = 登录有礼
	ver     = 0.1
]]

module("activity.qqplatform.loginaward" , package.seeall)
setfenv(1, activity.qqplatform.loginaward)

local operations       = require("systems.activity.operations")
local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local actorevent       = require("actorevent.actorevent")

local ScriptTips = Lang.ScriptTips

require("protocol")
local sysId    = SystemId.yunyingActivitySystem
local protocol = YunyingActivityProtocal

require("activity.operationsconf")
local SubActConf = SubActConf
local LOGIN_AWARD = SubActConf.LOGIN_AWARD
local LOGIN_AWARD_STR = tostring(LOGIN_AWARD)

local DAY_FLAG_DATA = 0x00000001
local DAY_FLAG, MAX_DAY_FLAG = 0, 30

--------------------------------------------
--              ** DATA **
--------------------------------------------
function getConf(operId)
	local conf, isOnTime = operations.getConf(operId, LOGIN_AWARD)
	if not conf or not conf.config then return end

	return conf.config, isOnTime
end

function getPlatVar(actor, operId, isClear)
	if not operId or operId <= 0 then return end

	local var = LActor.getPlatVar(actor)
	if not var then return end

	if var.loginaward == nil then var.loginaward = {} end
	local sVar = var.loginaward

	if sVar[operId] == nil or isClear then sVar[operId] = {} end
	return sVar[operId]
end

function clearPlatVar(actor, operId)
	if operId then
		getPlatVar(actor, operId, true)
	else
		local var = LActor.getPlatVar(actor)
		if not var then return end

		var.loginaward = nil
	end
end

--------------------------------------------
--               ** NET **
--------------------------------------------
function sendInfoToActor(actor, operId)
	if not actor then return end

	local conf, isOnTime = getConf(operId)
	if not conf or not isOnTime then return end

	local var = getPlatVar(actor, operId)
	if not var or not var.flagData or not var.onlineDay then return end

	local pack = LDataPack.allocPacket(actor, sysId, protocol.sSendLoginAwardInfo)
	if not pack then return end

	local writeData = LDataPack.writeData
	writeData(pack, 3,
		dtInt, operId,
		dtChar, var.onlineDay or 0,
		dtInt, var.flagData or 0)

	LDataPack.flush(pack)
end

function onSendInfoToActor(actor, pack)
	if not pack then return end

	local operId = LDataPack.readData(pack, 1, dtInt)
	sendInfoToActor(actor, operId)
end

--------------------------------------------
--              ** MAIN **
--------------------------------------------

function getAward(actor, operId, indx)
	if indx < 0 or indx > 30 then return end
	local conf, isOnTime = getConf(operId)
	if not conf or not conf.dayAward or not conf.awardConf or not isOnTime then return end

	local awardConf
	if indx == 0 then
		awardConf = conf.dayAward
	elseif conf.awardConf[indx] then
		awardConf = conf.awardConf[indx]
	end

	if not awardConf or not awardConf.award then return end

	awardConf = awardConf.award
	--空格检测
	if Item.getBagEmptyGridCount(actor) < #awardConf then return false, ScriptTips.segg002 end

	--标记判定
	local var = getPlatVar(actor, operId)
	if not var or not var.flagData then return end
	if not System.bitOPMask(var.flagData, indx) then return end

	var.flagData = System.bitOpSetMask(var.flagData, indx, false)

	local tips = string.format("qqplatform_%d_%d", operId, LOGIN_AWARD)
	for _,itemConf in pairs(awardConf) do
		LActor.addItem(actor, itemConf.param, itemConf.quality or 0, itemConf.strong or 0, itemConf.num, itemConf.bind or 1, tips, 786)
	end

	sendInfoToActor(actor, operId)
	return true
end

function onGetAward(actor, pack)
	local operId, indx = LDataPack.readData(pack, 2, dtInt, dtChar)
	if operId == 0 then return end

	local ret, msg = getAward(actor, operId, indx)
	if msg then
		LActor.sendTipmsg(actor, msg, ttMessage)
	end
end
--------------------------------------------
--              ** RESET **
--------------------------------------------

--重置
function reSet(actor)
	if not System.isCommSrv() then return end

	local subConfs = operations.getSubActivitys(LOGIN_AWARD)
	if not subConfs then return end

	local level = LActor.getRealLevel(actor)
	local timeNow = System.getNowTime()
	local timeZero = System.get0HourTime(timeNow)

	for operId,_ in pairs(subConfs) do
		local conf, endTime = getConf(operId)
		if conf and endTime then
			local var = getPlatVar(actor, operId)
			if var.closeTime and var.closeTime ~= endTime then
				clearPlatVar(actor, operId)
			end

			if var and level >= conf.minLevel then
				if not var.onlineTime or not System.isSameDay(var.onlineTime, timeZero) then
					var.onlineTime = timeZero --时间标记
					var.closeTime = endTime
					if var.onlineDay == nil then var.onlineDay = 0 end
					var.onlineDay = var.onlineDay + 1

					if var.flagData == nil then var.flagData = 0 end
					var.flagData = System.bitOpSetMask(var.flagData, DAY_FLAG, true)
					var.flagData = System.bitOpSetMask(var.flagData, var.onlineDay, true)
				end
			end
		else
			clearPlatVar(actor, operId)
		end
	end
end

function onStarOper(operId, begTime, endTime)
	local players = LuaHelp.getAllActorList()
	if not players or #players <= 0 then return end

	for _,player in ipairs(players) do
		clearPlatVar(player, operId)
		reSet(player)
	end
end

function onCloseOper(operId, begTime, endTime)
	local players = LuaHelp.getAllActorList()
	if not players or #players <= 0 then return end

	for _,player in ipairs(players) do
		clearPlatVar(player, operId)
	end
end

function regEvent( ... )
	local subConfs = operations.getSubActivitys(LOGIN_AWARD)
	if not subConfs then return end

	for operId,_ in pairs(subConfs) do
		operations.regStartEvent(operId, onStarOper)
		operations.regCloseEvent(operId, onCloseOper)
	end
end

table.insert(InitFnTable, regEvent)

actorevent.reg(aeUserLogin, reSet)
actorevent.reg(aeLevel, reSet)
actorevent.reg(aeNewDayHoursArriveInCommSrv, reSet)

netmsgdispatcher.reg(sysId, protocol.cGetLoginAwardInfo, onSendInfoToActor, true)
netmsgdispatcher.reg(sysId, protocol.cGetLoginAward, onGetAward, true)

