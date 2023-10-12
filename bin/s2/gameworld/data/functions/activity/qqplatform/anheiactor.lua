module("activity.qqplatform.anheiactor", package.seeall)
setfenv(1, activity.qqplatform.anheiactor)

local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local operations = require("systems.activity.operations")
local actorevent  = require("actorevent.actorevent")
local abase = require("systems.awards.abase")

local activityList = operations.getSubActivitys(SubActConf.ANHEIBOSS)
local systemId = SystemId.yunyingActivitySystem
local protocol = YunyingActivityProtocal
local ScriptTips = Lang.ScriptTips

function setActivityTime(actId, beginTime)
	if not actId then return end

	local sys_var = System.getStaticVar()
	if not sys_var then return end

	if sys_var.anheiactor == nil then sys_var.anheiactor = {} end
	sys_var.anheiactor[actId] = beginTime
end

function getActivityTime(actId)
	if not actId then return 0 end

	local sys_var = System.getStaticVar()
	if not sys_var or not sys_var.anheiactor then return 0 end

	return sys_var.anheiactor[actId] or 0
end

function getActorVar(actor, actId)
	if not actor or not actId then return end
	local var = LActor.getPlatVar(actor)
	if not var then return end

	if var.anheiactor == nil then var.anheiactor = {} end
	if var.anheiactor[actId] == nil then var.anheiactor[actId] = {} end

	return var.anheiactor[actId]
end

function resetActorVar(actor, actId)
	if not actor or not actId then return end
	local var = LActor.getPlatVar(actor)
	if not var then return end

	if var.anheiactor and var.anheiactor[actId] then
		var.anheiactor = nil
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

function addKillCount(actor, actId, idx)
	local var = getActorVar(actor, actId)
	if not var then return end

	if var.killInfo == nil then var.killInfo = {} end
	var.killInfo[idx] = (var.killInfo[idx] or 0) + 1
end

function setAwardStatus(actor, actId, idx)
	local var = getActorVar(actor, actId)
	if not var then return end
	var.awards = System.setIntBit(var.awards or 0, idx, true)
end

function getAwardStatus(actor, actId, idx)
	local var = getActorVar(actor, actId)
	if not var then return end
	return System.getIntBit(var.awards or 0, idx)
end

function sendAwardStatus(actor, actId)
	local var = getActorVar(actor, actId)
	if not var then return end

	local pack = LDataPack.allocPacket(actor, systemId, protocol.sAnheiActorAwardStatus)
	if not pack then return end

	LDataPack.writeInt(pack, actId)
	LDataPack.writeInt(pack, var.awards or 0)
	LDataPack.flush(pack)
end

function sendInfo(actor, actId)
	local var = getActorVar(actor, actId)
	if not var then return end

	local conf = operations.getConf(actId, SubActConf.ANHEIBOSS)
	if not conf or not conf.config or not conf.config.awards then return end

	local pack = LDataPack.allocPacket(actor, systemId, protocol.sAnheiActorInfo)
	if not pack then return end

	LDataPack.writeInt(pack, actId)
	for i=1, #conf.config.awards do
		if var.killInfo then
			LDataPack.writeInt(pack, var.killInfo[i] or 0)
		else
			LDataPack.writeInt(pack, 0)
		end
	end
	LDataPack.flush(pack)
end

function dealActorKillBoss(monster, killer, monId)
	if not System.isLianFuSrv() then return end
	if not LActor.isActor(killer) then return end

	for actId, conf in pairs(activityList) do
		if operations.isInTime(actId) then
			local config = conf.config
			for idx, info in ipairs(config.awards) do
				if info.monsterId == monId then
					local players = LuaHelp.getTeamMemberList(killer)
					if players ~= nil then
						for _, player in ipairs(players) do
							if LActor.isInSameScreen(killer, player) then
								addKillCount(player, actId, idx)
								sendInfo(player, actId)
							end
						end
					else
						addKillCount(killer, actId, idx)
						sendInfo(killer, actId)
					end
					
				end
			end
		end
	end
end

function clientAward(actor, packet)
	local actId = LDataPack.readInt(packet)
	local awardIdx = LDataPack.readByte(packet)

	if not operations.isInTime(actId) then
		LActor.sendTipmsg(actor, ScriptTips.anheiactor001)
		return
	end

	local var = getActorVar(actor, actId)
	if not var then return end

	local config = operations.getConf(actId, SubActConf.ANHEIBOSS)
	if not config or not config.config or not config.config.awards then return end

	local conf = config.config.awards[awardIdx + 1]
	if not conf then return end

	if not var.killInfo or ((var.killInfo[awardIdx + 1] or 0) < conf.count) then
		LActor.sendTipmsg(actor, ScriptTips.anheiactor002)
		return
	end

	if getAwardStatus(actor, actId, awardIdx) == 1 then
		LActor.sendTipmsg(actor, ScriptTips.anheiactor004)
		return
	end

	if Item.getBagEmptyGridCount(actor) < #conf.awards then
		LActor.sendTipmsg(actor, ScriptTips.anheiactor003)
		return
	end

	setAwardStatus(actor, actId, awardIdx)

	abase.sendAwards(actor, conf.awards, "activity_anheiactor")
	sendAwardStatus(actor, actId)
end

function mailAward(actor, activityId)
	local config = operations.getConf(activityId, SubActConf.ANHEIBOSS)
	if not config or not config.config or not config.config.awards then return end

	local conf = config.config.awards

	local var = getActorVar(actor, activityId)
	if not var or not var.killInfo then return end

	local actorid = LActor.getActorId(actor)
	for idx, info in ipairs(conf) do
		if getAwardStatus(actor, activityId, idx-1) == 0 and (var.killInfo[idx] or 0) >= info.count then
			setAwardStatus(actor, activityId, idx-1)
			abase.sendAwardsByMail(actorid, info.awards, config.config.context, config.config.log, LActor.getServerId(actor))
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

function onNewDay(actor)
	for actId, _ in pairs(activityList) do
		mailAward(actor, actId)
		resetActorVar(actor, actId)
		if operations.isInTime(actId) then
			setActorActivityTime(actor, activityId)
			sendInfo(actor, actId)
			sendAwardStatus(actor, actId)
		end
	end
end

function openActivity(activityId, beginTime)
	print("AnHeiActorActivity Open !!!")

	--设置活动开启时间(服务器)
	setActivityTime(activityId, beginTime)

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
	print("AnHeiActorActivity Close !!!")

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

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)

netmsgdispatcher.reg(systemId, protocol.cAnheiActorAwardStatus, clientAward)

--测试代码
-- function ssss(actor)
-- 	dealActorKillBoss(nil, actor, 3)
-- end

-- _G.anhei = ssss

--@openYYActivity 10 2015-9-29 7:20:1 100
--@closeYYActivity 10
