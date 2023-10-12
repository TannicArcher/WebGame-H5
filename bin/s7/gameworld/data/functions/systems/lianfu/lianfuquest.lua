--连服任务
module("systems.lianfu.lianfuquest", package.seeall)
setfenv(1, systems.lianfu.lianfuquest)

require("lianfu.lianfuquestconfig")
require("protocol")
local actorevent = require("actorevent.actorevent")
local fubenevent = require("actorevent.fubenevent")
local monevent = require("monevent.monevent")
local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local lianfu = require("systems.lianfu.lianfumanager")
local lianfuutils = require("systems.lianfu.lianfuutils")
local fubenteam = require("systems.fubensystem.fubenteam")

local postscripttimer = require("base.scripttimer.postscripttimer")

require("fubenconfig.transterconf")

local config = LianfuQuestConf

local SystemId = SystemId.lianfuSystemId
local protocol = LianfuSystemProtocol
local LDataPack = LDataPack
local LActor = LActor
local sendTipmsg = LActor.sendTipmsg
local tips = Lang.Lianfu
local lianfuQuestOpenTime = 0 	--连服任务开启时间

--加任务进度
function processTask(actor, monId)
	if actor == nil then return end

	local var = LActor.getSysVar(actor)
	if var == nil or var.lianfuquest == nil then return end

	local quest = var.lianfuquest
	local taskconfig = config.tasks[quest.questId]
	if taskconfig == nil or taskconfig.monsterId ~= monId then return end

	if quest.hasFinish + 1 >= taskconfig.amount then
		finishQuest(actor)
		return
	end

	quest.hasFinish = quest.hasFinish + 1
	sendQuestInfo(actor)
end

--立即完成
function quicklyFinish(actor)
	if actor == nil then return end

	local var = LActor.getSysVar(actor)
	if var == nil or var.lianfuquest == nil then return end

	local quest = var.lianfuquest
	local taskconfig = config.tasks[quest.questId]
	if taskconfig == nil then return end

	local totalYb = LActor.getMoneyCount(actor, mtBindYuanbao)
	local needMomey = config.quicklyExpend
	if totalYb < needMomey then
		sendTipmsg(actor, tips.quest001, ttWarmTip)
		return
	end
	LActor.changeMoney(actor,mtBindYuanbao,-needMomey,1,true, "lianfu", "lianfuquest")

	finishQuest(actor)
end

--完成任务，给奖励，刷新任务id
function finishQuest(actor)
	if actor == nil then return end

	local var = LActor.getSysVar(actor)
	if var == nil or var.lianfuquest == nil then return end

	local quest = var.lianfuquest
	local taskconfig = config.tasks[quest.questId]
	if taskconfig == nil or taskconfig.awards == nil then return end

	local awards = taskconfig.awards
	for _, award in ipairs(awards) do
		local isSuc = LActor.giveAward(actor, award.type, award.count, 781, award.id, "lianfuquest", award.bind)
		if isSuc then
			System.logCounter(LActor.getActorId(actor), tostring(LActor.getAccountName(actor)), tostring(LActor.getLevel(actor)),
					"lianfuquest", "finishquest", "taskid "..quest.questId, "itemid"..award.id, "count "..award.count)
		elseif award.type == 0 then
			sendGmMailByActor(actor, tips.quest002, 1, award.id, award.count, 0, 0)

			System.logCounter(LActor.getActorId(actor), tostring(LActor.getAccountName(actor)), tostring(LActor.getLevel(actor)),
					"lianfuquest", "finishquest", "taskid "..quest.questId, "itemid"..award.id, "count "..award.count)
		end
	end
	if (quest.questId + 1) <= #config.tasks then
		quest.questId = quest.questId + 1
	else
		quest.questId = 0
		LActor.addQuestValue(actor, config.finishAllQuestId, 0, 1)
	end
	quest.hasFinish = 0
	sendQuestInfo(actor)
end


-- 怪物死亡
function onMonstersDie(monster, killer, monId)
	-- 如果是宠物打死的，找出主人
	if LActor.isPet(killer) then
		killer = LActor.getMonsterOwner(killer)
		if not killer then
			print("lianfuquest Monster Killed By Pet No owner")
			return
		end
	end

	if not LActor.isActor(killer) then
		print("lianfuquest Monster Killed, Owner None")
		return
	end

	local players = LuaHelp.getTeamMemberList(killer)
	if players ~= nil then
		for _, player in ipairs(players) do
			if LActor.isInSameScreen(killer, player) then
				--处理任务,修改完成状态,数量等
				processTask(player, monId)
			end
		end
	else
		--处理任务,修改完成状态,数量等
		processTask(killer, monId)
	end
end
--采集
function onGatherFinish(monster, killer, monId)
  	processTask(killer, monId)
end

--发送数据
function sendQuestInfo(actor)
	if actor == nil then return end

	if lianfuQuestOpenTime == 0 then
		judgeLianfuQuestOpenTime()
	end
	if System.getNowTime() < lianfuQuestOpenTime or lianfuQuestOpenTime == 0 then return end

	local var = LActor.getSysVar(actor)
	if var == nil then return end

	local quest = var.lianfuquest
	local questId = -1
	local hasFinish = 0
	if quest then
		questId = quest.questId or 0
		hasFinish = quest.hasFinish or 0
	end

	local npack = LDataPack.allocPacket(actor, SystemId, protocol.sSendLianfuQuestInfo)
	if npack == nil then return end
	LDataPack.writeData(npack, 2,  
						dtInt, questId,
						dtInt, hasFinish)

	LDataPack.flush(npack)
end

--初始化数据，传送进王城地图
function enterLianfuWangcheng(actor)
	print("enterLianfuWangcheng")
	if actor == nil then return end

	if lianfuQuestOpenTime == 0 then
		judgeLianfuQuestOpenTime()
	end
	if System.getNowTime() < lianfuQuestOpenTime or lianfuQuestOpenTime == 0 then
		print(lianfuQuestOpenTime)
		sendTipmsg(actor, tips.quest004, ttWarmTip)
		return
	end
	local level = LActor.getRealLevel(actor)
	if level < config.level then
		local msg = string.format(tips.quest003, config.level)
		sendTipmsg(actor, msg, ttWarmTip)
		return
	end

	-- 正在执行护送任务
	if LActor.hasState(actor, esProtection) then
		sendTipmsg(actor, tips.quest005, ttWarmTip)
		return
	end

	if fubenteam.getFubenTeamId(actor) ~= 0 then
		local npack = LDataPack.allocPacket(actor, SystemId, protocol.sEnterXiaoyaohuangcheng)
		if npack == nil then return end

		LDataPack.flush(npack)
		return
	end
	onEnterLianfuWangcheng(actor)
end

function chooseEnterOrNot(actor, packet)
	if actor == nil or packet == nil then return end
	local flag = LDataPack.readByte(packet)
	if flag == 0 then return end
	
	fubenteam.leaveFubenTeamCommon(actor)
	onEnterLianfuWangcheng(actor)
end

function onEnterLianfuWangcheng(actor)
	local var = LActor.getSysVar(actor)
	if var == nil then return end

	if var.lianfuquest == nil then
		var.lianfuquest = {}
		local quest = var.lianfuquest
		quest.questId = 1
		quest.hasFinish = 0
	end

	lianfu.loginLianfuServer(actor, 0, config.sceneId, config.toPosx, config.toPosy)

	sendQuestInfo(actor)
end

function enterXiaoyaocheng(actor)
	if System.isLianFuSrv() then
		LActor.loginOtherSrv(actor, LActor.getServerId(actor), 0, config.xiaoyaochengId, config.posX, config.posY)
	end
end

--每天刷新数据
function refreshQuestInfo(actor)
	if actor == nil then return end

	local var = LActor.getSysVar(actor)
	if var == nil or var.lianfuquest == nil then return end

	local quest = var.lianfuquest
	quest.questId = 1	--当前进行的任务id
	quest.hasFinish = 0 --当前任务进度

	sendQuestInfo(actor)
	checkAndAddQuest(actor)
end

function onLogin(actor)
	if System.isLianFuSrv() then
		fubenteam.onDelFubenTeamMember(actor)
	elseif System.isCommSrv() then	
		local var = LActor.getSysVar(actor)
		if var and var.lianfuquest == nil then
			checkAndAddQuest(actor)
		end
	end
end

--玩家增加 完成所有连服任务 的任务
function checkAndAddQuest(actor)
	if actor == nil then return end

	if lianfuQuestOpenTime ~= 0 and System.getNowTime() >= lianfuQuestOpenTime then
		if LActor.getRealLevel(actor) >= config.level then
			LActor.addQuest(actor, config.finishAllQuestId)
		end
	end
end

function onLevelUp(actor)
	if actor == nil then return end

	if LActor.getRealLevel(actor) == config.level then
		checkAndAddQuest(actor)
	end
end

function finishQuestCheck(...)
	local actors = LuaHelp.getAllActorList()
	if actors == nil then return end
	for _, actor in ipairs(actors) do
		checkAndAddQuest(actor)
	end
end

--定时器 开启连服皇城时给玩家都加上 完成所有连服任务的 任务
function finishQuestInit()
	if not System.isCommSrv() then return end

	if lianfuQuestOpenTime == 0 then
		judgeLianfuQuestOpenTime()
	end

	local now = System.getNowTime()
	if lianfuQuestOpenTime == 0 or lianfuQuestOpenTime <= now then return end

	postscripttimer.postOnceScriptEvent(nil, (lianfuQuestOpenTime - now)*1000, function(...) finishQuestCheck(...) end)
end

function initMonster()
	--注册怪物死亡事件和采集事件
	for _, task in ipairs(config.tasks) do
		if task.type == 1 then
			monevent.regDieEvent(task.monsterId, onMonstersDie)
		elseif task.type == 0 then
			monevent.regGatherFinish(task.monsterId, onGatherFinish)
		end
	end
end

--连服任务开启的时间
function judgeLianfuQuestOpenTime()
	local serverId = System.getServerId()
	local lianfuconfig = lianfuutils.getLianfuConf(serverId)
	if not lianfuconfig or not lianfuconfig.opentime then return end

	local opentime = lianfuconfig.opentime
	lianfuQuestOpenTime = opentime + (config.openday - 1) * 3600 * 24
end

table.insert(InitFnTable, initMonster)
lianfuutils.regOnLianFuNetInited(judgeLianfuQuestOpenTime)
engineevent.regGameStartEvent(finishQuestInit)

actorevent.reg(aeNewDayArrive, refreshQuestInfo)
actorevent.reg(aeUserLogin, sendQuestInfo)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeLevel, onLevelUp)

fubenevent.registerTeleport(TransterConf.LIANFU_WANGCHENG, enterLianfuWangcheng)
fubenevent.registerTeleport(TransterConf.BENFU_XIAOYAOCHENG, enterXiaoyaocheng)

netmsgdispatcher.reg(SystemId, protocol.cQuickFinish, quicklyFinish)
netmsgdispatcher.reg(SystemId, protocol.cChooseEnterOrNot, chooseEnterOrNot)

