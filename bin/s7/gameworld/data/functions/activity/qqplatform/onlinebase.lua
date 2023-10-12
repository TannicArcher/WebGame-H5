module("activity.qqplatform.onlinebase" , package.seeall)
setfenv(1, activity.qqplatform.onlinebase)

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
local DAY_LENGTH = 24 * 3600
local subActId = SubActConf.ONLINE_AWARD
local postOnce = postscripttimer.postOnceScriptEvent

local ActivityConfig = operations.getSubActivitys(subActId)

function getSysVard(actId)
	if not actId then return end

	local var = System.getDyanmicVar()
	if not var then return end

	if not var.baseOnline then
		var.baseOnline = {}
	end

	if not var.baseOnline[actId] then
		var.baseOnline[actId] = {}
	end
	return var.baseOnline[actId]
end

function getActorVar(actor, actId)
	local var = LActor.getPlatVar(actor)
	if not var then return end

	if not var.baseOnline then
		var.baseOnline = {}
	end

	if not var.baseOnline[actId] then
		var.baseOnline[actId] = {}
	end
	return var.baseOnline[actId]
end

function clearActorVar(actor, actId)
	local var = LActor.getPlatVar(actor)
	if not var then return end

	if not var.baseOnline then return end
	var.baseOnline[actId] = {}
end

function getStepTime(time, now)
	if not time or not now then return end

	local delay = time - now
	if delay < 0 then
		delay = delay + DAY_LENGTH
	end
	return delay
end

function getStageIndex(actId, time)
	if not actId or not time then return end

	local conf = ActivityConfig[actId].config
	if not conf then return end

	local index = 0

	for k, info in ipairs(conf.awards) do
		if time < info.endtime and time >= info.begintime then
			index = k
		end
	end

	return index
end

function onlineInit(actId, begintime, endtime)
	local conf = ActivityConfig[actId].config
	if not conf then return end

	local now = System.getNowTime() % DAY_LENGTH
	local last, delay, stage = 100000
	local checkStage = {}

	for k, info in ipairs(conf.awards) do
		if now < info.endtime and now >= info.begintime then
			stage = k
		end

		checkStage[info.begintime] = k
		checkStage[info.endtime] = 0
	end

	for time, k in pairs(checkStage) do
		delay = getStepTime(time, now)
		postOnce(nil, delay * 1000, function(...) checkNewStage(...) end, actId, k)
	end

	if stage then brordcastActivity(actId, stage) end
end

function onlineClose(actId)
end

function brordcastActivity(actId, stage)
	if not actId then return end

	--print("broadcast actId:" ..actId)
	--print("broadcast stage:"..(stage or 0))

	local pack = LDataPack.allocBroadcastPacket(systemId, protocol.sOnlineStage)
	if not pack then return end
	LDataPack.writeInt(pack, actId)
	LDataPack.writeInt(pack, stage or 0)
	System.broadcastData(pack)
end

function checkNewStage(target, actId, stage)
	if not actId then return end

	local closetime = operations.isInTime(actId)
	if not closetime then return end

	local conf = ActivityConfig[actId]
	if not conf then return end

	local now = System.getNowTime()

	if closetime > now + DAY_LENGTH then
		postOnce(nil, DAY_LENGTH * 1000, function(...) checkNewStage(...) end, actId, stage)
	end

	brordcastActivity(actId, stage)
end

function getOnlineAward(actor, packet)
	if not System.isCommSrv() then return end

	if not actor then return end

	local actId = LDataPack.readInt(packet)
	local idx = LDataPack.readInt(packet)

	if not operations.isInTime(actId) then return end

	local conf = ActivityConfig[actId].config
	if not conf then return end

	if LActor.getRealLevel(actor) < conf.level then
		LActor.sendTipmsg(actor, Lang.yyhd002)
		return
	end

	local var = getActorVar(actor, actId)
	if not var then return end

	if idx <= 0 or idx > #conf.awards then return end

	local info = conf.awards[idx]
	if not info then return end

	local now = System.getNowTime() % DAY_LENGTH
	if now >= info.endtime or now < info.begintime then return end

	var.situation = var.situation or 0
	if System.getIntBit(var.situation, idx) ~= 0 then
		print("award has get ......")
		return 
	end

	local count, needspace = 0, 0
	for _, info in ipairs(info.awards) do
		if info.rewardtype == qatItem then
			needspace = Item.getAddItemNeedGridCount(actor, info.itemid, info.amount)
			count = count + needspace
		end
	end

	if Item.getBagEmptyGridCount(actor) < count then
		LActor.sendTipmsg(actor, Lang.ljcz002)
		return
	end

	var.situation = System.setIntBit(var.situation, idx, true)

	abase.sendAwards(actor,info.awards, "qqplatform_online_award")

	sendBaseInfo(actor, actId, var.situation)
end

function sendBaseInfo(actor, actId, situation)
	if not actor or not actId then return end

	local pack = LDataPack.allocPacket(actor, systemId, protocol.sSendOnlineInfo)
	if pack == nil then return end

	local now = System.getNowTime() % DAY_LENGTH
	local stage = getStageIndex(actId, now)

	--print("actId:" .. actId)
	--print("stage:" .. (stage or 0))
	--print("situation:" ..(situation or 0))

	LDataPack.writeInt(pack, actId)
	LDataPack.writeInt(pack, stage or 0)
	LDataPack.writeInt(pack, situation or 0)
	LDataPack.flush(pack)
end

function sendOnlineInfo(actor, actId)
	if not System.isCommSrv() then return end

	if not actor or not actId then return end

	local var = getActorVar(actor, actId)
	if not var then return end

	sendBaseInfo(actor, actId, var.situation)
end

function onNewDay(actor)
	for actId, info in pairs(ActivityConfig) do
		clearActorVar(actor, actId)
		if operations.isInTime(actId) then		
			sendOnlineInfo(actor, actId)
		end
	end
end

function onUserLogin(actor)
	for actId, info in pairs(ActivityConfig) do
		if operations.isInTime(actId) then	
			sendOnlineInfo(actor, actId)
		end
	end
end

function initOperations()
	for actId, info in pairs(ActivityConfig) do
		operations.regStartEvent(actId, onlineInit)
		operations.regCloseEvent(actId, onlineClose)
	end
end

function checkOnline()
	postOnce(nil, 500, function(...) delayActivityCheck(...) end)
end

function delayActivityCheck()
	for actId, info in pairs(ActivityConfig) do
		local vard = getSysVard(actId)
		if not vard then return end
		if not vard.refresh and operations.isInTime(actId) then
			onlineInit(actId)
		end
		vard.refresh = true
	end
end

engineevent.regGameStartEvent(checkOnline)

table.insert(InitFnTable, initOperations)

actorevent.reg(aeNewDayArrive, onNewDay)

actorevent.reg(aeUserLogin, onUserLogin, true)

netmsgdispatcher.reg(systemId, protocol.cOnlineAward, getOnlineAward)

---鍛戒护
local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.baifuOpen = function(actor, args)
	if not System.isCommSrv() then return end
	
	local begintime = "2015-9-1 0:0:0"
	local endTime = "2015-11-30 0:0:0"
	operations.onSetOperTime(4, begintime, endTime)
	operations.onSetOperTime(6, begintime, endTime)
end

gmCmdHandlers.baifuClose = function(actor)
	if not System.isCommSrv() then return end

	local begintime = "2010-9-1 0:0:0"
	local endTime = "2010-11-30 0:0:0"
	operations.onSetOperTime(4, begintime, endTime)
	operations.onSetOperTime(6, begintime, endTime)
end

