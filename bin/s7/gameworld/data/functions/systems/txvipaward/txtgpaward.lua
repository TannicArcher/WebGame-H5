--杂七杂八特权
module("systems.txvipaward.txtgpaward", package.seeall)
setfenv(1, systems.txvipaward.txtgpaward)

require("protocol")
require("txvipaward.tgpawardconfig")
local ScriptTips = Lang.ScriptTips
local actorevent       = require("actorevent.actorevent")
local netmsgdispatcher = require("utils.net.netmsgdispatcher")

local timeRewardSystem = SystemId.timeRewardSystem
local TimeRewardSystemProtocol = TimeRewardSystemProtocol

local function getAcotrSysVar( actor, typeIdx )
	if not typeIdx then return end
	
	local var = LActor.getSysVar(actor)
	if not var.txmisawards then
		var.txmisawards = {}
	end

	local t = var.txmisawards[typeIdx] 
	if not t then
		var.txmisawards[typeIdx] = {}
		t = var.txmisawards[typeIdx]
	end

	return t
end

local function getLogStr( typeIdx )
	if typeIdx == 1 then
		return "tgp"
	end

	return ""
end

local function sendStatu( actor, typeIdx )
	local var = getAcotrSysVar(actor, typeIdx)

	local baseRecord = var.baseRecord or 0
	local levelRecord = var.levelRecord or 0

	local pack = LDataPack.allocPacket(actor, timeRewardSystem, TimeRewardSystemProtocol.sGetTxMisAward)
	if not pack then return end

	LDataPack.writeData(pack, 3, dtByte, typeIdx, dtInt, baseRecord, dtInt, levelRecord)
	LDataPack.flush(pack)
end

local function getCommonAward( actor, typeIdx, awardConf, idx, log)
	local var = getAcotrSysVar(actor, typeIdx)
	local baseRecord = var.baseRecord or 0

	if System.bitOPMask(baseRecord, idx) then
		LActor.sendTipmsg(actor, ScriptTips.oa002)
		return
	end

	if Item.getBagEmptyGridCount(actor) < awardConf.needBag then
		return LActor.sendTipmsg(actor, ScriptTips.if011, ttMessage)
	end

	var.baseRecord = System.bitOpSetMask(baseRecord, idx, true)

	--发奖励
	local clScriptGiveItem = 1
	local log = getLogStr(typeIdx).."_viponly"
	for _, iteminfo in pairs(awardConf.items) do
		LActor.giveAward(actor, iteminfo.type, iteminfo.num, clScriptGiveItem, iteminfo.param, log, iteminfo.bind)
	end

	return true
end

local function getVipOnly( actor, typeIdx )
	local config = TxCommAwardConfig[typeIdx]
	if not config then 
		print("error, getVipOnly send param error..111..", typeIdx)
		return
	end

	local log = getLogStr(typeIdx).."_viponly"
	if not getCommonAward(actor, typeIdx, config.vipOnlyItem, 0, log) then return end

	sendStatu(actor, typeIdx)
	LActor.sendTipmsg(actor, ScriptTips.oa025)
end

local function getFreshItem( actor, typeIdx )
	local config = TxCommAwardConfig[typeIdx]
	if not config then 
		print("error, getFreshItem send param error..111..", typeIdx)
		return 
	end

	local log = getLogStr(typeIdx).."_fresh_award"
	if not getCommonAward(actor, typeIdx, config.freshOnlyItem, 1, log) then return end

	sendStatu(actor, typeIdx)
	LActor.sendTipmsg(actor, ScriptTips.oa025)
end

local function getDayItem( actor, typeIdx )
	local config = TxCommAwardConfig[typeIdx]
	if not config then 
		print("error, getDayItem send param error..111..", typeIdx)
		return 
	end

	local log = getLogStr(typeIdx).."_day_award"
	if not getCommonAward(actor, typeIdx, config.dayItem, 2, log) then return end

	sendStatu(actor, typeIdx)
	LActor.sendTipmsg(actor, ScriptTips.oa025)
end

local function getLevelItem( actor, typeIdx, levelIdx )
	local config = TxCommAwardConfig[typeIdx]
	if not config then 
		print("error, getLevelItem send param error..111..", typeIdx)
		return 
	end

	local awardConf = config.levelItem[levelIdx]
	if not awardConf then
		print("error, getLevelItem send param error..222..", levelIdx)
		return
	end

	local level = LActor.getRealLevel(actor)
	if level < awardConf.val then
		return LActor.sendTipmsg(actor, ScriptTips.oa006)
	end

	local var = getAcotrSysVar(actor, typeIdx)
	local levelRecord = var.levelRecord or 0

	if System.bitOPMask(levelRecord, levelIdx - 1) then
		LActor.sendTipmsg(actor, ScriptTips.oa002)
		return
	end

	var.levelRecord = System.bitOpSetMask(levelRecord, levelIdx - 1, true)

	--发奖励
	local clScriptGiveItem = 1
	local log = getLogStr(typeIdx).."level_award"
	for _, iteminfo in pairs(awardConf.items) do
		LActor.giveAward(actor, iteminfo.type, iteminfo.num, clScriptGiveItem, iteminfo.param, log, iteminfo.bind)
	end

	sendStatu(actor, typeIdx)
	LActor.sendTipmsg(actor, ScriptTips.oa025)
end

local function getAward( actor, pack )
	local typeIdx, awardIdx, param = LDataPack.readData(pack, 3, dtByte, dtByte, dtByte)

	if awardIdx == 1 then
		return getVipOnly(actor, typeIdx)
	elseif awardIdx == 2 then
		return getFreshItem(actor, typeIdx)
	elseif awardIdx == 3 then
		return getDayItem(actor, typeIdx)
	elseif awardIdx == 4 then
		return getLevelItem(actor, typeIdx, param)
	else
		print("tgp client send param error......", awardIdx)
	end
end

local function onLogin( actor )
	for i=1, #TxCommAwardConfig do
		sendStatu(actor, i)
	end
end

local function onNewDay( actor, login )
	for i=1, #TxCommAwardConfig do
		local var = getAcotrSysVar(actor, i)
		local baseRecord = var.baseRecord or 0
		var.baseRecord = System.bitOpSetMask(baseRecord, 2, false)

		if login == 0 then
			sendStatu(actor, i)
		end
	end
end

local function getInfo( actor, pack )
	local typeIdx = LDataPack.readByte(pack)
	sendStatu(actor, typeIdx)
end


actorevent.reg(aeNewDayArrive, onNewDay)
netmsgdispatcher.reg(timeRewardSystem, TimeRewardSystemProtocol.cGetTxMisAward, getAward)
netmsgdispatcher.reg(timeRewardSystem, TimeRewardSystemProtocol.cGetTxMisAwardInfo, getInfo)

