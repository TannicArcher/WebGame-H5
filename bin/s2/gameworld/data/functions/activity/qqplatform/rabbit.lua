--玉兔降临
module("activity.qqplatform.rabbit", package.seeall)
setfenv(1, activity.qqplatform.rabbit)

require("protocol")
require("activity.operationsconf")

local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local actorevent = require("actorevent.actorevent")
local monevent = require("monevent.monevent")
local operations = require("systems.activity.operations")
local actorfunc = require("utils.actorfunc")
local postscripttimer = require("base.scripttimer.postscripttimer")


local config = operations.getSubActivitys(SubActConf.RABBIT)

local sysid = SystemId.yunyingActivitySystem
local protocol = YunyingActivityProtocal

local lang = Lang.ScriptTips

local DAY_LENGTH = 24 * 3600

local function getRabbitVar(actor, activityid)
	if actor == nil or activityid == nil then return end
	local var = actorfunc.getPlatVar(actor)
	if var == nil then return end

	if var.rabbit == nil then
		var.rabbit = {}
	end
	if var.rabbit[activityid] == nil then
		var.rabbit[activityid] = {}
	end

	return var.rabbit[activityid]
end
local function resetRabbitVar(actor, activityid)
	if not actor or not activityid then return end

	local var = LActor.getPlatVar(actor)
	if var and var.rabbit and var.rabbit[activityid] then
		var.rabbit[activityid] = nil
	end
end

--玩家参加该活动的时间
function setActorActivityTime(actor, activityid)
	local var = getRabbitVar(actor, activityid)
	if not var then return end

	var.opentime = operations.getActivityTime(activityid)
end
function getActorActivityTime(actor, activityid)
	local var = getRabbitVar(actor, activityid)
	if not var then return 0 end

	return var.opentime or 0
end

local function getStaticVar(activityid)
	local var = System.getStaticVar()
	if var == nil then return end

	if var.rabbit == nil then
		var.rabbit = {}
	end
	if var.rabbit[activityid] == nil then
		var.rabbit[activityid] = {}
	end

	return var.rabbit[activityid]
end

function openActivity(activityid)
	if not config[activityid] or not config[activityid].config then return end
	local activityConf = config[activityid].config

	local nowTime = math.mod(System.getNowTime(), DAY_LENGTH)
	local beginTime = activityConf.beginTime
	local endTime = activityConf.endTime
	local beforeTime = activityConf.beforeTime

	if nowTime > beginTime and nowTime < endTime then
		refreshRabbit(nil, activityid)
	elseif nowTime < beginTime then
		postscripttimer.postOnceScriptEvent(nil, (beginTime-nowTime)*1000, function(...) refreshRabbit(...) end, activityid)
		postscripttimer.postOnceScriptEvent(nil, (beginTime-nowTime-beforeTime)*1000, function(...) onBroadBefore(...) end, activityid)
	elseif nowTime > endTime then
		postscripttimer.postOnceScriptEvent(nil, (endTime+DAY_LENGTH-nowTime)*1000, function(...) refreshRabbit(...) end, activityid)
		postscripttimer.postOnceScriptEvent(nil, (endTime+DAY_LENGTH-nowTime-beforeTime)*1000, function(...) onBroadBefore(...) end, activityid)
	end
	local players = LuaHelp.getAllActorList()
	if players then
		for _, player in ipairs(players) do
			resetRabbitVar(player, activityid)
			onSendInfo(player, activityid)
			setActorActivityTime(player, activityid)
		end
	end
end

function closeActivity(activityid)
	clearMonster(nil, activityid)

	local var = System.getStaticVar()
	if var == nil or var.rabbit == nil then return end

	var.rabbit[activityid] = nil
end

--广播通知开启活动
function onBroadBefore(actor, activityid)
	if not System.isCommSrv() then return end
	local closetime = operations.isInTime(activityid)
	if not closetime then return end

	System.broadcastTipmsg(lang.rabbit003, ttChatWindow)
end

--刷新兔子
function refreshRabbit(actor, activityid)
	if not System.isCommSrv() then return end
	local closetime = operations.isInTime(activityid)
	if not closetime then return end

	local var = getStaticVar(activityid)
	if var == nil then return end
	if not config[activityid] or not config[activityid].config or not config[activityid].config.rabbitMonster then return end
	
	local conf = config[activityid].config.rabbitMonster
	local now = System.getNowTime()
	if var.refreshTime == nil or not System.isSameDay(var.refreshTime, now) then
		var.hasRefresh = 0
	elseif var.hasRefresh >= conf.count then
		return
	end

	
	local hScene = Fuben.getSceneHandleById(conf.sceneid, 0)
	if not hScene then return end

	if Fuben.getLiveMonsterCount(hScene, conf.monsterid) ~= 0 then return end

	local totalPercent
	for _, monconfig in ipairs(conf.position) do
		totalPercent = (totalPercent or 0) + monconfig.probality
	end

	local r = System.getRandomNumber(totalPercent) + 1
	local monsterConf
	local total = 0
	for _, monconfig in ipairs(conf.position) do
		total = total + monconfig.probality
		if r < total then
			monsterConf = monconfig
			break
		end
	end
	if monsterConf == nil then
		refreshRabbit(nil, activityid)
		return
	end

	Fuben.createMonster(hScene, conf.monsterid, monsterConf.posX, monsterConf.posY)

	if var.hasRefresh == 0 then
		var.refreshTime = now
		local nowTime = math.mod(now, DAY_LENGTH)
		postscripttimer.postOnceScriptEvent(nil, (config[activityid].config.beginTime+DAY_LENGTH-nowTime)*1000, function(...) refreshRabbit(...) end, activityid)
		postscripttimer.postOnceScriptEvent(nil, (config[activityid].config.endTime-nowTime)*1000, function(...) clearMonster(...) end, activityid)
	end

	local tips = string.format(lang.rabbit001, (var.hasRefresh or 0)+1)
	System.broadcastTipmsg(tips, ttChatWindow)
end

--活动结束，清理怪物
function clearMonster(actor, activityid)
	if config[activityid] == nil or not config[activityid].config then return end

	local activityConf = config[activityid].config
	local hScene = Fuben.getSceneHandleById(activityConf.rabbitMonster.sceneid, 0)
	if not hScene then return end

	if Fuben.getLiveMonsterCount(hScene, activityConf.rabbitMonster.monsterid) ~= 0 then
		Fuben.clearMonster(hScene, activityConf.rabbitMonster.monsterid)

		System.broadcastTipmsg(lang.rabbit002, ttChatWindow)
	end

	Fuben.clearAllGather(hScene, activityConf.boxMonster.monsterid)
end

--发送信息
function onSendInfo(actor, activityid)
	if not System.isCommSrv() or not operations.isInTime(activityid) then return end
	
	if not actor or not config[activityid] or not config[activityid].config then return end	

	local var = getRabbitVar(actor, activityid)
	if var == nil then return end

	local npack = LDataPack.allocPacket(actor, sysid, protocol.sSendRabbitInfo)
	if npack == nil then return end

	LDataPack.writeInt(npack, activityid)
	LDataPack.writeInt(npack, config[activityid].config.gatherCount - (var.hasGather or 0))

	LDataPack.flush(npack)
end

function onKillRabbit(monster, killer, monId)
	local activityid
	local activityConf
	for i, conf in pairs(config) do
		if conf.config.rabbitMonster.monsterid == monId then
			activityid = i
			activityConf = conf.config
			break
		end
	end
	if activityid == nil then return end

	if not System.isCommSrv() or not operations.isInTime(activityid) then return end

	local var = getStaticVar(activityid)
	if var == nil then return end

	var.hasRefresh = (var.hasRefresh or 0) + 1

	if var.hasRefresh == activityConf.rabbitMonster.count then
		System.broadcastTipmsg(lang.rabbit002, ttChatWindow)
	else
		refreshRabbit(nil, activityid)
	end

	local hScene = Fuben.getSceneHandleById(activityConf.rabbitMonster.sceneid, 0)
	if not hScene then return end

	local posX = LActor.getIntProperty(monster, P_POS_X)
	local posY = LActor.getIntProperty(monster, P_POS_Y)
	local boxConf = activityConf.boxMonster
	Fuben.createMonsters(hScene, boxConf.monsterid, posX - boxConf.range, posX + boxConf.range,
			posY - boxConf.range, posY + boxConf.range, boxConf.count, 0)
end

--采集判断
function onGatherCheck(monster, killer, monId)
	local activityid
	for i, activityConf in pairs(config) do
		if activityConf.config.boxMonster.monsterid == monId then
			activityid = i
			break
		end
	end
	if activityid == nil then return false end

	if not System.isCommSrv() or not operations.isInTime(activityid) then return false end
	if killer == nil then return false end

	local var = getRabbitVar(killer, activityid)
	if var == nil then return false end

	if var.hasGather and var.hasGather >= config[activityid].config.gatherCount then
		LActor.sendTipmsg(killer, lang.rabbit004, ttWarmTip)
		return false
	end
	return true
end
--采集箱子
function onGatherBox(monster, killer, monId)
	local activityid
	for i, activityConf in pairs(config) do
		if activityConf.config.boxMonster.monsterid == monId then
			activityid = i
			break
		end
	end
	if activityid == nil then return end

	if not System.isCommSrv() or not operations.isInTime(activityid) then return end

	if killer == nil then return end

	local var = getRabbitVar(killer, activityid)
	if var == nil then return end

	var.hasGather = (var.hasGather or 0) + 1

	onSendInfo(killer, activityid)
end

function newDayLogin(actor)
	if actor == nil then return end

	for activityid, _ in pairs(config) do
		local var = getRabbitVar(actor, activityid)
		if var then
			var.hasGather = 0
			onSendInfo(actor, activityid)
		end
	end
end
function onLogin(actor)
	if actor == nil then return end

	for activityid, _ in pairs(config) do
		if operations.isInTime(activityid) and System.isCommSrv() then
			local activityTime = operations.getActivityTime(activityid)
			local actorActivityTime = getActorActivityTime(actor, activityid)

			if activityTime ~= 0 and activityTime ~= actorActivityTime then
				resetRabbitVar(actor, activityid)
				setActorActivityTime(actor, activityid)
			end

			onSendInfo(actor, activityid)
		end
	end
end

function checkRabbit()
	for activityid, _ in pairs(config) do
		if operations.isInTime(activityid) then
			openActivity(activityid)
		end
	end
end

function initOperations()
	for activityid, activityConf in pairs(config) do
		operations.regStartEvent(activityid, openActivity)
		operations.regCloseEvent(activityid, closeActivity)

		monevent.regDieEvent(activityConf.config.rabbitMonster.monsterid, onKillRabbit)
		monevent.regGatherFinish(activityConf.config.boxMonster.monsterid, onGatherBox)
		monevent.regGatherCheck(activityConf.config.boxMonster.monsterid, onGatherCheck)
	end
end

table.insert(InitFnTable, initOperations)

actorevent.reg(aeNewDayArrive, newDayLogin)
actorevent.reg(aeUserLogin, onLogin, true)

engineevent.regGameStartEvent(checkRabbit)


