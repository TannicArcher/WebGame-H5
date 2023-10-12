module("activity.qqplatform.leijixiaofei", package.seeall)
setfenv(1, activity.qqplatform.leijixiaofei)

local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local operations = require("systems.activity.operations")
local actorevent  = require("actorevent.actorevent")
local abase = require("systems.awards.abase")

local activityList = operations.getSubActivitys(SubActConf.LJ_XIAOFEI)
local systemId = SystemId.yunyingActivitySystem
local protocol = YunyingActivityProtocal
local ScriptTips = Lang.ScriptTips

function setActivityTime(actId, beginTime)
	if not actId then return end

	local sys_var = System.getStaticVar()
	if not sys_var then return end

	if sys_var.leijixiaofei == nil then sys_var.leijixiaofei = {} end
	sys_var.leijixiaofei[actId] = beginTime
end

function getActivityTime(actId)
	if not actId then return 0 end

	local sys_var = System.getStaticVar()
	if not sys_var or not sys_var.leijixiaofei then return 0 end

	return sys_var.leijixiaofei[actId] or 0
end

function getActorVar(actor, actId)
	if not actor or not actId then return end

	local var = LActor.getPlatVar(actor)
	if not var then return end

	if var.leijixiaofei == nil then var.leijixiaofei = {} end
	if var.leijixiaofei[actId] == nil then var.leijixiaofei[actId] = {} end

	return var.leijixiaofei[actId]
end

function resetActorVar(actor, actId)
	if not actor or not actId then return end
	local var = LActor.getPlatVar(actor)
	if not var then return end

	if var.leijixiaofei and var.leijixiaofei[actId] then
		var.leijixiaofei = nil
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

function addXiaofei(actor, actId, value)
	local var = getActorVar(actor, actId)
	if not var then return end
	var.xiaofei = (var.xiaofei or 0) + value
end

function getXiaofei(actor, actId)
	local var = getActorVar(actor, actId)
	if not var then return end
	return var.xiaofei or 0
end

function sendXiaofei(actor, actId)
	local pack = LDataPack.allocPacket(actor, systemId, protocol.sLeijixiaofei)
	if not pack then return end

	LDataPack.writeInt(pack, actId)
	LDataPack.writeInt(pack, getXiaofei(actor, actId))
	LDataPack.flush(pack)
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

	local pack = LDataPack.allocPacket(actor, systemId, protocol.sLeijixiaofeiAward)
	if not pack then return end

	LDataPack.writeInt(pack, actId)
	LDataPack.writeInt(pack, var.awards or 0)
	LDataPack.flush(pack)
end

function dealLeijixiaofei(actor, value)
	for actId, _ in pairs(activityList) do
		if operations.isInTime(actId) then
			addXiaofei(actor, actId, value)
			sendXiaofei(actor, actId)
		end
	end
end

function clientAward(actor, packet)
	local actId = LDataPack.readInt(packet)
	local awardIdx = LDataPack.readInt(packet)

	if not operations.isInTime(actId) then
		LActor.sendTipmsg(actor, ScriptTips.ljxf001)
		return
	end

	local xiaofei = getXiaofei(actor, actId)

	local config = operations.getConf(actId, SubActConf.LJ_XIAOFEI)
	if not config or not config.config or not config.config.awards then return end

	local conf = config.config.awards[awardIdx + 1]
	if not conf then return end

	if xiaofei < conf.limit then
		LActor.sendTipmsg(actor, ScriptTips.ljxf002)
		return 
	end

	if getAwardStatus(actor, actId, awardIdx) == 1 then
		LActor.sendTipmsg(actor, ScriptTips.ljxf003)
		return
	end

	if Item.getBagEmptyGridCount(actor) < #conf.awards then
		LActor.sendTipmsg(actor, ScriptTips.ljxf004)
		return
	end

	setAwardStatus(actor, actId, awardIdx)

	abase.sendAwards(actor, conf.awards, "activity_leijixiaofei")

	sendAwardStatus(actor, actId)
end

function mailAward(actor, activityId)
	local config = operations.getConf(activityId, SubActConf.LJ_XIAOFEI)
	if not config or not config.config or not config.config.awards then return end

	local conf = config.config.awards

	local actorid = LActor.getActorId(actor)
	local xiaofei = getXiaofei(actor, activityId)

	for idx, info in ipairs(conf) do
		if getAwardStatus(actor, activityId, idx-1) == 0 and xiaofei >= info.limit then
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
			sendXiaofei(actor, actId)
			sendAwardStatus(actor, actId)
		else
			mailAward(actor,actId)
		end
	end
end

function openActivity(activityId, beginTime)
	print("LeijixiaofeiActivity Open !!!")

	--设置活动开启时间(服务器)
	setActivityTime(activityId, beginTime)

	local players = LuaHelp.getAllActorList()
	if not players then return end

	for _, player in ipairs(players) do
		--清空玩家数据
		resetActorVar(player, activityId)
		setActorActivityTime(player, activityId)
		sendXiaofei(player, activityId)
		sendAwardStatus(actor, activityId)
	end
end

function closeActivity(activityId)
	print("LeijixiaofeiActivity Close !!!")

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
actorevent.reg(aeConsumeYuanbao, dealLeijixiaofei)

netmsgdispatcher.reg(systemId, protocol.cLeijixiaofeiAward, clientAward)

--@openYYActivity 12 2015-10-23 00:00:00 1
