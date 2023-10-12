--皇城争夺活动
module("activity.qqplatform.huangcheng", package.seeall)
setfenv(1, activity.qqplatform.huangcheng)

require("activity.operationsconf")
require("protocol")

local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local operations = require("systems.activity.operations")
local lianfuutils = require("systems.lianfu.lianfuutils")
local actorevent  = require("actorevent.actorevent")
local abase = require("systems.awards.abase")
local centerservermsg = require("utils.net.centerservermsg")

local activityList = operations.getSubActivitys(SubActConf.HUANGCHENG)
local systemId = SystemId.yunyingActivitySystem
local protocol = YunyingActivityProtocal
local centerProtocol = YunyingActivityProtocal.CenterSrvCmd
local ScriptTips = Lang.ScriptTips

local NO_AWARD = 0 			--不能领取
local CAN_GET_AWARD = 1 	--可以领取
local HAS_GET_AWARD = 2		--已领取

function getSysVar(activityId)
	if not activityId then return end

	local var = System.getStaticVar()
	if not var then return end

	if var.huangcheng == nil then var.huangcheng = {} end
	if var.huangcheng[activityId] == nil then var.huangcheng[activityId] = {} end
	return var.huangcheng[activityId]
end

function clearSysVar(activityId)
	if not activityId then return end

	local var = System.getStaticVar()
	if not var then return end

	if var.huangcheng and var.huangcheng[activityId] then
		var.huangcheng[activityId] = nil
	end
end

function setHuangChengWinner(activityId, serverId, guildId, leaderId, guildName, leaderName)
	local var = getSysVar(activityId)
	if not var then return end

	var.sid = serverId
	var.guildId = guildId
	var.guildName = guildName
end

function dealHuangChengActivity(serverId, guildId, leaderId, guildName, leaderName)
	if not System.isLianFuSrv() then return end

	local realGuildName = string.format("%s.%s", WarFun.getServerName(serverId), guildName)
	local realLeaderName = string.format("%s.%s", WarFun.getServerName(serverId), leaderName)
	for actId, _ in pairs(activityList) do
		if operations.isInTime(actId) then
			setHuangChengWinner(actId, serverId, guildId, leaderId, realGuildName, realLeaderName)
			broadcastToServer(actId, serverId, guildId, leaderId, realGuildName, realLeaderName)
			broadcastToActor(actId)
		end
	end
end

function broadcastToServer(actId, serverId, guildId, leaderId, guildName, leaderName)
	local config = lianfuutils.getLianfuConf(System.getServerId())
	if config then
		for _, sid in ipairs(config.commonServerId) do
			local pack = LDataPack.allocCenterPacket(sid, systemId, centerProtocol.sHuangChengInfo) 
			if pack then
				LDataPack.writeData(pack, 6, dtInt, actId, dtInt, serverId, dtInt, guildId, dtInt, leaderId, dtString, guildName, dtString, leaderName)
				System.sendDataToCenter(pack)
			end
		end
	end
end

function recieveHuangCheng(packet)
	local actId, sid, guildId, leaderId, guildName, leaderName = LDataPack.readData(packet, 6, dtInt, dtInt, dtInt, dtInt, dtString, dtString)

	if operations.isInTime(actId) then
		setHuangChengWinner(actId, sid, guildId, leaderId, guildName, leaderName)
		broadcastToActor(actId)
	end
end

function broadcastToActor(actId)
	local var = getSysVar(actId)
	if not var then return end

	local pack = LDataPack.allocBroadcastPacket(systemId, protocol.sHuangChengInfo)
	if not pack then return end

	LDataPack.writeData(pack, 5, dtInt, actId, 
								dtInt, var.guildId or 0, 
								dtInt, var.leaderId or 0, 
								dtString, var.guildName or "", 
								dtString, var.leaderName or "")

	System.broadcastData(pack)

	local players = LuaHelp.getAllActorList()
	if not players then return end

	for _, player in ipairs(players) do
		--发送领奖状态
		sendAwardStatus(player, actId)
	end
end

function sendInfo(actor, actId)
	local var = getSysVar(actId)
	if not var then return end

	local pack = LDataPack.allocPacket(actor, systemId, protocol.sHuangChengInfo)
	if not pack then return end

	LDataPack.writeData(pack, 5, dtInt, actId, 
								dtInt, var.guildId or 0, 
								dtInt, var.leaderId or 0, 
								dtString, var.guildName or "", 
								dtString, var.leaderName or "")

	LDataPack.flush(pack)
end

function getActorVar(actor, actId)
	if not actor or not actId then return end
	local var = LActor.getPlatVar(actor)
	if not var then return end

	if var.huangcheng == nil then var.huangcheng = {} end
	if var.huangcheng[actId] == nil then var.huangcheng[actId] = {} end

	return var.huangcheng[actId]
end

function resetActorVar(actor, actId)
	if not actor or not actId then return end
	local var = LActor.getPlatVar(actor)
	if not var then return end

	if var.huangcheng and var.huangcheng[actId] then
		var.huangcheng[actId] = nil
	end
end

function setActorJoin(actor)
	for actId, _ in pairs(activityList) do
		if operations.isInTime(actId) then 
			local var = getActorVar(actor, actId)
			if var then
				--设置为可领取
				var.joinAward = CAN_GET_AWARD
				sendAwardStatus(actor,actId)
			end
		end
	end
end

function sendAwardStatus(actor, actId)
	local sys_var = getSysVar(actId)
	if not sys_var then return end

	local var = getActorVar(actor, actId)
	if not var then return end

	local pack = LDataPack.allocPacket(actor, systemId, protocol.sHuangChengAward)
	if not pack then return end

	local aid = LActor.getActorId(actor)
	local leadAward = NO_AWARD
	local guildAward = NO_AWARD
	local joinAward = NO_AWARD
	if sys_var.guildId then
		--逍遥争霸活动结束了才能领奖励
		if var.hasGetAwardId then
			if var.hasGetAwardId == 0 then
				leadAward = HAS_GET_AWARD
			elseif var.hasGetAwardId == 1 then
				guildAward = HAS_GET_AWARD
			elseif var.hasGetAwardId == 2 then
				joinAward = HAS_GET_AWARD
			end
		elseif LActor.getGuildId(actor) == sys_var.guildId then
			if LActor.getGuildPos(actor) == smGuildLeader then
				if not sys_var.leaderId and not sys_var.leaderName then
					leadAward = CAN_GET_AWARD
				end
			else
				guildAward = CAN_GET_AWARD
			end
		else
			joinAward = var.joinAward or NO_AWARD
		end
	end

	LDataPack.writeData(pack, 4, dtInt, actId, 
								dtByte, leadAward,
								dtByte, guildAward, 
								dtByte, joinAward)
	LDataPack.flush(pack)
end

function onLogin(actor)
	if System.isCrossWarSrv() then return end
	--当前活动
	for actId, _ in pairs(activityList) do
		--过期活动处理
		if getActivityTime(actId) ~= 0 and getActorActivityTime(actor, actId) ~= 0 and getActorActivityTime(actor, actId) ~= getActivityTime(actId) then
			--如果当前活动正在进行, 则清理数据
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

function setActorActivityTime(actor, actId)
	local var = getActorVar(actor, actId)
	if not var then return end

	local sys_var = getSysVar(actId)
	if sys_var then
		var.opentime = sys_var.beginTime or 0
	end
end

function getActorActivityTime(actor, actId)
	local var = getActorVar(actor, actId)
	if not var then return end

	return var.opentime or 0
end

function getActivityTime(actId)
	local sys_var = getSysVar(actId)
	if not sys_var then return end
	return sys_var.beginTime or 0
end

function setActivityTime(actId, beginTime)
	local sys_var = getSysVar(actId)
	if not sys_var then return end

	sys_var.beginTime = beginTime
end

--客户端领取奖励
function clientAward(actor, packet)
	local actId = LDataPack.readInt(packet)
	local awardType = LDataPack.readByte(packet)

	if not operations.isInTime(actId) then
		LActor.sendTipmsg(actor, ScriptTips.huangcheng004) 
		return
	end

	local var_sys = getSysVar(actId)
	if not var_sys then
		LActor.sendTipmsg(actor, ScriptTips.huangcheng001)
		return
	end

	local var = getActorVar(actor, actId)
	if not var then 
		LActor.sendTipmsg(actor, ScriptTips.huangcheng001)
		return
	end

	local flag
	if var.hasGetAwardId then
		flag = 2 	--已领取
	elseif awardType == 0 or awardType == 1 then
		if LActor.getGuildId(actor) ~= var_sys.guildId or
			(awardType == 0 and LActor.getGuildPos(actor) ~= smGuildLeader) then
			flag = 1 	--不能领取
		end	
	elseif awardType == 2 then
		if not var.joinAward then
			flag = 1
		end
	else
		return
	end

	if flag == 1 then
		LActor.sendTipmsg(actor, ScriptTips.huangcheng002)
		return
	elseif flag == 2 then
		LActor.sendTipmsg(actor, ScriptTips.huangcheng003)
		return
	end

	local conf = operations.getConf(actId, SubActConf.HUANGCHENG)
	if not conf or not conf.config or not conf.config.awards then return end

	local awards = conf.config.awards[awardType+1]
	if not awards or not awards.awards then return end

	if Item.getBagEmptyGridCount(actor) < #awards then
		LActor.sendTipmsg(actor, ScriptTips.huangcheng005)
		return
	end

	if awardType == 0 then
		var_sys.leaderId = LActor.getActorId(actor)	--记录谁领取了帮主奖励
		var_sys.leaderName = LActor.getName(actor)
		broadcastToActor(actId)
	end
	var.hasGetAwardId = awardType 		--记录玩家领取了哪个奖励

	abase.sendAwards(actor, awards.awards, "activity_huangcheng")

	sendAwardStatus(actor, actId)
end

--开启活动(通知玩家)
function openActivity(activityId, beginTime)
	print("HuangChengActivity Open !!!")
	--清理服务器数据
	clearSysVar(activityId)

	--设置活动开启时间(服务器)
	setActivityTime(activityId, beginTime)

	broadcastToActor(activityId)

	local players = LuaHelp.getAllActorList()
	if not players then return end

	for _, player in ipairs(players) do
		--清空玩家领奖
		resetActorVar(player, activityId)
		--设置活动开启时间(记录在玩家)
		setActorActivityTime(player, beginTime)
		--发送领奖状态
		sendAwardStatus(player, activityId)
	end
end

--关闭活动(发奖励)
function closeActivity(activityId)
	print("HuangChengActivity Close !!!")

	local players = LuaHelp.getAllActorList()
	if not players then return end

	for _, player in ipairs(players) do
		mailAward(player, activityId)
	end
end

function mailAward(actor, activityId)
	local conf = operations.getConf(activityId, SubActConf.HUANGCHENG)
	if not conf or not conf.config or not conf.config.awards then return end

	local sys_var = getSysVar(activityId)
	if not sys_var or not sys_var.guildId then return end

	local var = getActorVar(actor, activityId)
	if var and not var.hasGetAwardId then
		if not sys_var.leaderName and LActor.getGuildPos(actor) == smGuildLeader and LActor.getGuildId(actor) == sys_var.guildId then
			abase.sendAwardsByMail(LActor.getActorId(actor), conf.config.awards[1].awards, ScriptTips.huangcheng006, "activity_huangcheng", LActor.getServerId(actor))
			sys_var.leaderId = LActor.getActorId(actor)
			sys_var.leaderName = LActor.getName(actor)
			var.hasGetAwardId = 0
		elseif LActor.getGuildId(actor) == sys_var.guildId then
			abase.sendAwardsByMail(LActor.getActorId(actor), conf.config.awards[2].awards, ScriptTips.huangcheng007, "activity_huangcheng", LActor.getServerId(actor))
			var.hasGetAwardId = 1
		elseif var.joinAward and var.joinAward == CAN_GET_AWARD then
			abase.sendAwardsByMail(LActor.getActorId(actor), conf.config.awards[3].awards, ScriptTips.huangcheng008, "activity_huangcheng", LActor.getServerId(actor))
			var.hasGetAwardId = 2
		else
			var.hasGetAwardId = -1
		end
	end
end

--离开加入帮派或改变帮派职位时需要通知改变领取情况
function onCheckAward(actor)
	if not System.isCommSrv() then return end

	for actId, _ in pairs(activityList) do
		if operations.isInTime(actId) then
			sendAwardStatus(actor, actId)
		end
	end
end

function initOperations()
	for actId, _ in pairs(activityList) do
		operations.regStartEvent(actId, openActivity)
		operations.regCloseEvent(actId, closeActivity)
	end
end

table.insert(InitFnTable, initOperations)

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeJoinGuild, onCheckAward)
actorevent.reg(aeLeftGuild, onCheckAward)

netmsgdispatcher.reg(systemId, protocol.cHuangChengAward, clientAward)
centerservermsg.reg(systemId, centerProtocol.sHuangChengInfo, recieveHuangCheng)


--测试代码
-- function ssss(actor)
-- 	dealHuangChengActivity(LActor.getServerId(actor), LActor.getGuildId(actor), LActor.getActorId(actor), LActor.getGuildName(actor), LActor.getName(actor))
-- end

-- function tttt(actor)
-- 	setActorJoin(actor)
-- end
-- _G.huangcheng1 = ssss
-- _G.huangcheng2 = tttt

--@openYYActivity 10 2015-10-19 7:20:0 1
--@closeYYActivity 10
