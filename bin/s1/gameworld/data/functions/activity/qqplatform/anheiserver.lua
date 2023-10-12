module("activity.qqplatform.anheiserver", package.seeall)
setfenv(1, activity.qqplatform.anheiserver)

local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local operations = require("systems.activity.operations")
local actorevent  = require("actorevent.actorevent")
local abase = require("systems.awards.abase")
local rankfunc = require("utils.rankfunc")
local lianfuutils = require("systems.lianfu.lianfuutils")
local centerservermsg = require("utils.net.centerservermsg")
local postscripttimer = require("base.scripttimer.postscripttimer")


local activityList = operations.getSubActivitys(SubActConf.ANHEIBOSSTOTAL)
local systemId = SystemId.yunyingActivitySystem
local protocol = YunyingActivityProtocal
local ScriptTips = Lang.ScriptTips
local centerProtocol = YunyingActivityProtocal.CenterSrvCmd

local rankName = "anheirank_%d"
local rankFile = "anheirank_%d.txt"
local rankMax  = 3
local anheiRank

function initRank()
	anheiRank = {}
	for actId, _ in pairs(activityList) do
		if operations.isInTime(actId) then
			local name = string.format(rankName, actId)
			local fileName = string.format(rankFile, actId)
			anheiRank[actId] = rankfunc.InitRank(name, fileName, rankMax, nil, true)
		end
	end
end

function resetRank(actId)

	local fileName = string.format(rankFile, actId)

	if anheiRank[actId] then
		Ranking.clearRanking(anheiRank[actId])
		Ranking.save(anheiRank[actId], fileName)
	else
		local name = string.format(rankName, actId)
		anheiRank[actId] = rankfunc.InitRank(name, fileName, rankMax, columnName, true)
	end
end

function getActivityVar(actId)
	if not actId then return end

	local sys_var = System.getDyanmicVar()
	if not sys_var then return end

	if sys_var.anheiserver == nil then sys_var.anheiserver = {} end
	if sys_var.anheiserver[actId] == nil then sys_var.anheiserver[actId] = {} end

	return sys_var.anheiserver[actId]
end

function setActivityTime(actId, beginTime)
	if not actId then return end

	local sys_var = System.getStaticVar()
	if not sys_var then return end

	if sys_var.anheiserver == nil then sys_var.anheiserver = {} end
	sys_var.anheiserver[actId] = beginTime
end

function getActivityTime(actId)
	if not actId then return 0 end

	local sys_var = System.getStaticVar()
	if not sys_var or not sys_var.anheiserver then return 0 end

	return sys_var.anheiserver[actId] or 0
end

function isEnd(actId)
	local config = operations.getConf(actId, SubActConf.ANHEIBOSSTOTAL)
	if not config or not config.config then return end

	local now = System.getNowTime()

	return now >= operations.getEndTime(actId) - config.config.endTime
end

--结算时广播
function jiesuanBroad(actor, activityid)
	if not operations.isInTime(activityid) and not System.isLianFuSrv() then return end

	local rank = anheiRank[activityid]
	if not rank then return end

	local serverids = {}
	local score
	for i = 1, 3 do
		local rankItem = Ranking.getItemFromIndex(rank, i-1)
		if rankItem then
			serverids[i] = WarFun.getServerName(Ranking.getId(rankItem))
			if i == 1 then
				score = Ranking.getPoint(rankItem)
			end
		end
	end

	local str1 = string.format(ScriptTips.anheiserver006, serverids[1] or "", score or 0)
	local str2 = string.format(ScriptTips.anheiserver007, serverids[1] or "", serverids[2] or "", serverids[3] or "")
	LianfuFun.broadcastTipmsg(str1, ttScreenMarquee)
	LianfuFun.broadcastTipmsg (str2, ttHearsay)
end
function checkJiesuanBroad()
	local now = System.getNowTime()

	for activityid, config in pairs(activityList) do
		if operations.isInTime(activityid) then
			if config.config and config.config.endTime then
				local jiesuanTime = operations.getEndTime(activityid) - config.config.endTime
				local sys_var = getActivityVar(activityid)
				if sys_var then
					sys_var.eid = postscripttimer.postOnceScriptEvent(nil, (jiesuanTime-now)*1000, function(...) jiesuanBroad(...) end, activityid)
				end
			end
		end
	end
end

function getActorVar(actor, actId)
	if not actor or not actId then return end
	local var = LActor.getPlatVar(actor)
	if not var then return end

	if var.anheiserver == nil then var.anheiserver = {} end
	if var.anheiserver[actId] == nil then var.anheiserver[actId] = {} end

	return var.anheiserver[actId]
end

function resetActorVar(actor, actId)
	if not actor or not actId then return end
	local var = LActor.getPlatVar(actor)
	if not var then return end

	if var.anheiserver and var.anheiserver[actId] then
		var.anheiserver = nil
	end
end

function setActorActivityTime(actor, actId)
	local var = getActorVar(actor, actId)
	if not var then return end

	var.opentime = getActivityTime(actId)
end

function getActorActivityTime(actor, actId)
	local var = getActorVar(actor, actId)
	if not var then return end

	return var.opentime or 0
end

function addKillValue(actId, serverid, value)
	local rank = anheiRank[actId]
	if not rank then return end

	local rankItem = Ranking.getItemPtrFromId(rank, serverid)
	if not rankItem then
		Ranking.addItem(rank, serverid, value)
	else
		Ranking.updateItem(rank, serverid, value)
	end
	local fileName = string.format(rankFile, actId)
	Ranking.save(rank, fileName)
end

function dealServerKillBoss(monster, killer, monId)
	if not System.isLianFuSrv() then return end
	if not LActor.isActor(killer) then return end

	for actId, conf in pairs(activityList) do
		if operations.isInTime(actId) and not isEnd(actId) then
			if conf.config and conf.config.info and conf.config.info[monId] then
				--增加值
				addKillValue(actId, LActor.getServerId(killer), conf.config.info[monId])
				--广播
				broadcastToServer(actId, LActor.getServerId(killer), conf.config.info[monId])
				broadcastToActor(actId)
			end
		end
	end
end

function broadcastToServer(actId, serverId, value)

	local config = lianfuutils.getLianfuConf(System.getServerId())
	if not config then return end

	for _, sid in ipairs(config.commonServerId) do
		local pack = LDataPack.allocCenterPacket(sid, systemId, centerProtocol.sAnheiServer)
		if pack then
			LDataPack.writeData(pack, 3, dtInt, actId, dtInt, serverId, dtInt, value)
			System.sendDataToCenter(pack)
		end
	end
end

function recieveAnheiServer(packet)
	local actId, serverId, value = LDataPack.readData(packet, 3, dtInt, dtInt, dtInt)

	if operations.isInTime(actId) then
		addKillValue(actId, serverId, value)
		broadcastToActor(actId)
	end
end

function broadcastToActor(actId)
	local rank = anheiRank[actId]
	if not rank then return end

	local pack = LDataPack.allocBroadcastPacket(systemId, protocol.sAnheiServerInfo)
	if not pack then return end

	LDataPack.writeInt(pack, actId)

	for i=1, 3 do
		local rankItem = Ranking.getItemFromIndex(rank, i-1)
		if not rankItem then
			LDataPack.writeData(pack, 2, dtString, "", dtInt, 0)
		else
			LDataPack.writeData(pack, 2, dtString, WarFun.getServerName(Ranking.getId(rankItem)), dtInt, Ranking.getPoint(rankItem))
		end
	end

	System.broadcastData(pack)
end

function sendInfo(actor, actId)
	local rank = anheiRank[actId]
	if not rank then return end

	local conf = operations.getConf(actId, SubActConf.ANHEIBOSSTOTAL)
	if not conf then return end

	local pack = LDataPack.allocPacket(actor, systemId, protocol.sAnheiServerInfo)
	if not pack then return end

	LDataPack.writeInt(pack, actId)

	for i=1, #conf.config.awards do
		local rankItem = Ranking.getItemFromIndex(rank, i-1)
		if not rankItem then
			LDataPack.writeData(pack, 2, dtString, "", dtInt, 0)
		else
			LDataPack.writeData(pack, 2, dtString, WarFun.getServerName(Ranking.getId(rankItem)), dtInt, Ranking.getPoint(rankItem))
		end
	end
	LDataPack.flush(pack)
end

function sendAwardStatus(actor, actId)
	local var = getActorVar(actor, actId)
	if not var then return end

	local pack = LDataPack.allocPacket(actor, systemId, protocol.sAnheiServerAwardStatus)
	if not pack then return end

	LDataPack.writeInt(pack, actId)
	LDataPack.writeByte(pack, var.awards or 0)
	LDataPack.flush(pack)
end

function clientAward(actor, packet)
	local actId = LDataPack.readInt(packet)

	if not operations.isInTime(actId) then
		LActor.sendTipmsg(actor, ScriptTips.anheiserver001)
		return
	end

	if not isEnd(actId) then
		LActor.sendTipmsg(actor, ScriptTips.anheiserver005)
		return
	end

	local rank = anheiRank[actId]
	if not rank then return end

	local var = getActorVar(actor, actId)
	if not var then return end

	if var.awards and var.awards == 1 then 
		LActor.sendTipmsg(actor, ScriptTips.anheiserver002)
		return
	end

	local idx = Ranking.getItemIndexFromId(rank, LActor.getServerId(actor))
	if idx < 0 or idx >= 3 then return end

	local config = operations.getConf(actId, SubActConf.ANHEIBOSSTOTAL)
	if not config or not config.config or not config.config.awards then return end

	if LActor.getRealLevel(actor) < config.config.levelLimit then
		LActor.sendTipmsg(actor, ScriptTips.anheiserver004)
		return
	end

	local conf = config.config.awards[idx + 1]	
	if not conf then return end

	if Item.getBagEmptyGridCount(actor) < #conf.awards then
		LActor.sendTipmsg(actor, ScriptTips.anheiserver003)
		return
	end

	var.awards = 1

	abase.sendAwards(actor, conf.awards, "activity_anheiserver")

	sendAwardStatus(actor, actId)
end

function mailAward(actor, activityId)
	local config = operations.getConf(activityId, SubActConf.ANHEIBOSSTOTAL)
	if not config or not config.config or not config.config.awards then return end

	local rank = anheiRank[activityId]
	if not rank then return end
	
	local idx = Ranking.getItemIndexFromId(rank, LActor.getServerId(actor))
	if idx < 0 or idx >= 3 then return end

	local conf = config.config.awards[idx + 1]
	if not conf then return end

	local var = getActorVar(actor, activityId)
	if not var then return end

	local actorid = LActor.getActorId(actor)

	if not var.awards then
		var.awards = 1
		if LActor.getRealLevel(actor) >= config.config.levelLimit then
			abase.sendAwardsByMail(actorid, conf.awards, conf.context, config.config.log, LActor.getServerId(actor))
		end
	end
end

function onLogin(actor)
	if System.isCrossWarSrv() then return end
	
	for actId, _ in pairs(activityList) do
		if getActivityTime(actId) ~= 0 and getActorActivityTime(actor, actId) ~= 0 and getActorActivityTime(actor, actId) ~= getActivityTime(actId) then
			if operations.isInTime(actId) then
				resetActorVar(actor, actId)
			end
			setActorActivityTime(actor, actId)
		end

		if operations.isInTime(actId) then
			setActorActivityTime(actor, actId)
			sendInfo(actor, actId)
			sendAwardStatus(actor, actId)
		else
			mailAward(actor, actId)
		end
	end
end

function openActivity(activityId, beginTime)
	print("AnHeiServerActivity Open !!!")

	--设置活动开启时间(服务器)
	setActivityTime(activityId, beginTime)

	resetRank(activityId)

	local config = operations.getConf(activityId, SubActConf.ANHEIBOSSTOTAL)
	if config and config.config and config.config.endTime then
		local jiesuanTime = operations.getEndTime(activityId) - config.config.endTime
		local now = System.getNowTime()
		if jiesuanTime > now then
			local sys_var = getActivityVar(activityId)
			if sys_var then
				sys_var.eid = postscripttimer.postOnceScriptEvent(nil, (jiesuanTime-now)*1000, function(...) jiesuanBroad(...) end, activityId)
			end
		end
	end

	local players = LuaHelp.getAllActorList()
	if not players then return end

	for _, player in ipairs(players) do
		--清空玩家数据
		resetActorVar(player, activityId)
		setActorActivityTime(player, activityId)
		sendInfo(player, activityId)
		sendAwardStatus(player, activityId)
	end
end

function closeActivity(activityId)
	print("AnHeiServerActivity Close !!!")

	--关活动的时候，把广播的定时器关掉
	local sys_var = getActivityVar(activityId)
	if sys_var and sys_var.eid then
		postscripttimer.cancelScriptTimer(nil, sys_var.eid)
		sys_var.eid = nil
	end

	local players = LuaHelp.getAllActorList()
	if not players then return end

	for _, player in ipairs(players) do
		mailAward(player, activityId)
	end
end

function initOperations()
	for actId, _ in pairs(activityList) do
		operations.regStartEvent(actId, openActivity)
		operations.regCloseEvent(actId, closeActivity)
	end
end

table.insert(InitFnTable, initOperations)
table.insert(InitFnTable, initRank)

actorevent.reg(aeUserLogin, onLogin)

netmsgdispatcher.reg(systemId, protocol.cAnheiServerAward, clientAward)
centerservermsg.reg(systemId, centerProtocol.sAnheiServer, recieveAnheiServer)

engineevent.regGameStartEvent(checkJiesuanBroad)

function sss(actor)
	dealServerKillBoss(nil, actor, 641)
	dealServerKillBoss(nil, actor, 650)
end

_G.anhei1 = sss
