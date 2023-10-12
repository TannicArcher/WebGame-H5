module("activity.qqplatform.turntable" , package.seeall)
setfenv(1, activity.qqplatform.turntable)

local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local mailsystem = require("systems.mail.mailsystem")
local postscripttimer = require("base.scripttimer.postscripttimer")
local actorevent = require("actorevent.actorevent")
local abase = require("systems.awards.abase")
local operations = require("systems.activity.operations")
local gmsystem    = require("systems.gm.gmsystem")


require("activity.operationsconf")
require("protocol")

local protocol = YunyingActivityProtocal
local systemId = SystemId.yunyingActivitySystem 
local Lang = Lang.ScriptTips
local subActId = SubActConf.TURN_TABLE
local postOnce = postscripttimer.postOnceScriptEvent

local ActivityConfig = operations.getSubActivitys(subActId)

function getActorVar(actor, actId)
	local var = LActor.getPlatVar(actor)
	if not var then return end

	if not var.turntable then
		var.turntable = {}
	end

	if not var.turntable[actId] then
		var.turntable[actId] = {}
	end
	return var.turntable[actId]
end

function clearActorVar(actor, actId)
	local var = getActorVar(actor, actId)
	if not var then return end

	local conf = ActivityConfig[actId].config
	if not conf then return end

	var.loteryTime = System.getNowTime()
	var.times = conf.dayLotteryTimes
end

function turnTableInit(actId, begintime, endtime)
	local list = LuaHelp.getAllActorList()
	if not list or #list <= 0 then return end

	for _, actor in ipairs(list) do
		clearActorVar(actor, actId)
	end
end

function turnTableClose(actId)
end

function getTurnTableAward(actor, packet)
	if not System.isCommSrv() then return end

	if not actor or not packet then return end

	local actId = LDataPack.readInt(packet)

	if not operations.isInTime(actId) then return end

	local conf = ActivityConfig[actId].config
	if not conf then return end

	local var = getActorVar(actor, actId)
	if not var or not var.times or not var.loteryTime then return end

	if var.event then return end

	local now = System.getNowTime()
	if var.loteryTime + conf.roundCd > now then
		LActor.sendTipmsg(actor, Lang.zp001)
		return
	end

	if var.times <= 0 then
		LActor.sendTipmsg(actor, Lang.zp002)
		return
	end

	local random = System.getRandomNumber(1000) + 1
	local rate, idx = 0

	for k, info in ipairs(conf.awards) do
		rate = rate + info.rate
		if random <= rate then
			idx = k
			break
		end
	end

	if not idx then return end

	local item = conf.awards[idx]
	local needspace = Item.getAddItemNeedGridCount(actor, item.itemid, item.amount)
	if Item.getBagEmptyGridCount(actor) < needspace then
		LActor.sendTipmsg(actor, Lang.zp003)
		return
	end

	local pack = LDataPack.allocPacket(actor, systemId, protocol.sGetTurnTableAward)
	if pack == nil then return end
	LDataPack.writeInt(pack, actId)
	LDataPack.writeInt(pack, idx)
	LDataPack.flush(pack)

	var.event = postOnce(actor, conf.interval * 1000 + 2000, delaySendAward, actId, idx)
end

function delaySendAward(actor, actId, idx)
	if not actor or not idx then return end

	local var = getActorVar(actor, actId)
	if not var or not var.times or not var.loteryTime then return end

	local conf = ActivityConfig[actId].config
	if not conf then return end

	local item = conf.awards[idx]
	abase.sendAwards(actor, {item}, "qqplatform_turntable_lottery")

	var.loteryTime = System.getNowTime()
	var.times = var.times - 1
	var.event = nil

	sendBaseInfo(actor, actId)

	if not item.broadcast then return end
	local msg = string.format(item.broadcast, LActor.getActorLink(actor), Item.getItemLink(item.itemid))
	System.broadcastTipmsg(msg, ttChatWindow)
end

function sendBaseInfo(actor, actId, isNewDay, isLogin)
	if not System.isCommSrv() then return end

	if not operations.isInTime(actId) then return end

	local conf = ActivityConfig[actId].config
	if not conf then return end

	local var = getActorVar(actor, actId)
	if not var then return end

	if isLogin and var.loteryTime then
		local tm = LActor.getLastLogoutTime(actor) - var.loteryTime
		if tm < 0 then tm = 0
		elseif tm > conf.roundCd then  tm = conf.roundCd
		end
		var.event = nil
		var.loteryTime = System.getNowTime() - tm
	end

	if isNewDay or not var.times or not var.loteryTime then
		clearActorVar(actor, actId)
	end

	local time = var.loteryTime + conf.roundCd

	local pack = LDataPack.allocPacket(actor, systemId, protocol.sSendTurnTableInfo)
	if pack == nil then return end
	LDataPack.writeInt(pack, actId)
	LDataPack.writeInt(pack, var.times)
	LDataPack.writeUInt(pack, time)
	LDataPack.flush(pack)
end

function sendTurnTableInfo(actor, packet)
	if not packet then return end
	local actId = LDataPack.readInt(packet)
	sendBaseInfo(actor, actId, false)
end

function onNewDay(actor)
	for actId, info in pairs(ActivityConfig) do
		if operations.isInTime(actId) then		
			sendBaseInfo(actor, actId, true, false)
		end
	end
end

function onUserLogin(actor)
	for actId, info in pairs(ActivityConfig) do
		if operations.isInTime(actId) then	
			sendBaseInfo(actor, actId, false, true)
		end
	end
end

function initOperations()
	for actId, info in pairs(ActivityConfig) do
		operations.regStartEvent(actId, turnTableInit)
		operations.regCloseEvent(actId, turnTableClose)
	end
end

function rstTtCount(actor)
	local actId = 14
	local var = getActorVar(actor, actId)
	if not var then return end
	var.times = 5
	sendBaseInfo(actor, actId)
end

_G.rstTtCount = rstTtCount

table.insert(InitFnTable, initOperations)

actorevent.reg(aeNewDayArrive, onNewDay)

actorevent.reg(aeUserLogin, onUserLogin, true)

netmsgdispatcher.reg(systemId, protocol.cGetTurnTableAward, getTurnTableAward)
netmsgdispatcher.reg(systemId, protocol.cGetTurnTableInfo, sendTurnTableInfo)

---鍛戒护
local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.ttOpen = function(actor, args)
	if not System.isCommSrv() then return end
	
	local begintime = "2015-11-1 0:0:0"
	local endTime = "2015-11-15 0:0:0"
	operations.onSetOperTime(14, begintime, endTime)
end

gmCmdHandlers.ttClose = function(actor)
	if not System.isCommSrv() then return end

	local begintime = "2010-9-1 0:0:0"
	local endTime = "2010-11-30 0:0:0"
	operations.onSetOperTime(14, begintime, endTime)
end

