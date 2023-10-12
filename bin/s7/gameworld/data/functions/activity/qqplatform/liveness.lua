--活跃有礼
module("activity.qqplatform.liveness", package.seeall)
setfenv(1, activity.qqplatform.liveness)

require("activity.operationsconf")
require("protocol")

local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local actorevent = require("actorevent.actorevent")
local monevent = require("monevent.monevent")
local operations = require("systems.activity.operations")
local actorfunc = require("utils.actorfunc")
local mailsystem = require("systems.mail.mailsystem")

local config = operations.getSubActivitys(SubActConf.LIVENESS_AWARD)

local sysid = SystemId.yunyingActivitySystem
local protocol = YunyingActivityProtocal
local lang = Lang.ScriptTips

local function getLivenessVar(actor, activityid)
	if actor == nil or activityid == nil then return end
	local var = actorfunc.getPlatVar(actor)
	if var == nil then return end

	if var.liveness == nil then
		var.liveness = {}
	end
	if var.liveness[activityid] == nil then
		var.liveness[activityid] = {}
	end

	return var.liveness[activityid]
end
function resetActorVar(actor, activityid)
	if not actor or not activityid then return end
	local var = actorfunc.getPlatVar(actor)
	if not var then return end

	if var.liveness and var.liveness[activityid] then
		var.liveness[activityid] = nil
	end
end

--玩家参加该活动的时间
function setActorActivityTime(actor, activityid)
	local var = getLivenessVar(actor, activityid)
	if not var then return end

	var.opentime = operations.getActivityTime(activityid)
end
function getActorActivityTime(actor, activityid)
	local var = getLivenessVar(actor, activityid)
	if not var then return 0 end

	return var.opentime or 0
end

--活跃度改变
function onChangeLiveness(actor, count, todaycount)
	if actor == nil then return end

	for activityid, conf in pairs(config) do
		if operations.isInTime(activityid) then
			local var = getLivenessVar(actor, activityid)
			if var == nil then return end

			var.liveness = (var.liveness or 0) + count
			if var.liveness < todaycount and System.isCommSrv() then
				var.liveness = todaycount
			end

			--上限判断
			local itemcount = #conf.config.awards
			if var.liveness > conf.config.awards[itemcount].count then
				var.liveness = conf.config.awards[itemcount].count
			end

			onSendInfo(actor, activityid)
		end
	end
end

function getAwards(actor, packet)
	if actor == nil or packet == nil then return end

	local activityid = LDataPack.readInt(packet)
	local idx = LDataPack.readInt(packet)

	local var = getLivenessVar(actor, activityid)
	if var == nil then return end
	var.situation = var.situation or 0
	var.liveness = var.liveness or 0

	if config == nil or config[activityid] == nil or config[activityid].config == nil then return end

	if not System.isCommSrv() or not operations.isInTime(activityid) then return end

	if System.getIntBit(var.situation, idx) ~= 0 then return end

	local awardConf = config[activityid].config.awards[idx]
	if awardConf == nil or var.liveness < awardConf.count then return end

	if Item.getBagEmptyGridCount(actor) <= 0 then
		LActor.sendTipmsg(actor, lang.liveness001, ttWarmTip)
		return
	end

	var.situation = System.setIntBit(var.situation, idx, true)
	for _, iteminfo in pairs(awardConf.items) do
		local logid = 776
		LActor.giveAward(actor, iteminfo.type, iteminfo.num, logid, iteminfo.param, "zhongqiu_huoyedu", iteminfo.bind);
	end

	onSendInfo(actor, activityid)
end

--发送信息
function onSendInfo(actor, activityid)
	if not System.isCommSrv() or not operations.isInTime(activityid) then return end

	if actor == nil then return end

	local var = getLivenessVar(actor, activityid)
	if var == nil then return end

	var.situation = var.situation or 0
	var.liveness = var.liveness or 0

	local npack = LDataPack.allocPacket(actor, sysid, protocol.sSendLivenessInfo)
	if npack == nil then return end

	LDataPack.writeInt(npack, activityid)
	LDataPack.writeInt(npack, var.liveness)
	LDataPack.writeInt(npack, var.situation)

	LDataPack.flush(npack)
end

function openActivity(activityid)
	if not System.isCommSrv() then return end
	if not operations.isInTime(activityid) then return end

	local players = LuaHelp.getAllActorList()
	if players == nil then return end

	for _, player in ipairs(players) do
		resetActorVar(player, activityid)

		onSendInfo(player, activityid)
		checkLiveness(player)

		setActorActivityTime(player, activityid)
	end
end
function closeActivity(activityid)
	local players = LuaHelp.getAllActorList()
	if players == nil then return end

	for _, player in ipairs(players) do
		endSendAwards(player, activityid)
	end
end

function onLogin(actor, firstLogin)
	if actor == nil then return end

	for activityid, _ in pairs(config) do
		if operations.isInTime(activityid) then
			local activityTime = operations.getActivityTime(activityid)
			local actorActivityTime = getActorActivityTime(actor, activityid)
			if activityTime ~= 0 and activityTime ~= actorActivityTime then
				endSendAwards(actor, activityid)
				resetActorVar(actor, activityid)
				setActorActivityTime(actor, activityid)
			end

			onSendInfo(actor, activityid)
			checkLiveness(actor)
			if activityid == OperationsConf.MID_AUTUMN then
				buchang(actor, activityid, firstLogin)
			end
		else
			endSendAwards(actor, activityid)
		end
	end
end

function buchang(actor, activityid, firstLogin)
	local var = getLivenessVar(actor, activityid)
	if var == nil then return end

	if firstLogin == 1 then
		var.buchang = true
	elseif var.buchang == nil then
		var.liveness = (var.liveness or 0) + 280
		var.buchang = true
	end
end

--活动结束发送未领取的奖励
function endSendAwards(actor, activityid)
	if actor == nil or activityid == nil then return end

	local var = getLivenessVar(actor, activityid)
	if var == nil or var.liveness == nil or var.situation == nil then return end

	local serverid = LActor.getServerId(actor)
	local actorid = LActor.getActorId(actor)
	local mailtips = lang.liveness002
	local qtype
	local itemlist = {}

	if config[activityid] == nil or config[activityid].config == nil or config[activityid].config.awards == nil then return end
	for idx, conf in ipairs(config[activityid].config.awards) do
		if var.liveness >= conf.count and System.getIntBit(var.situation, idx) == 0 then
			var.situation = System.setIntBit(var.situation, idx, true)
			for _, v in ipairs(conf.items) do
				if v.type == qatItem then
					qtype = mailsystem.TYPE_ITEM
				elseif v.type == qatBindMoney or v.type == qatMoney
				or v.type == qatBindYuanBao or v.type == qatYuanbao then
					qtype = mailsystem.TYPE_MONEY
				else
					qtype = mailsystem.TYPE_VAL
				end

				local attachment =
		 		{
					type    = qtype,
					param   = v.param,
					count   = v.num,
					bind    = v.bind,
					quality = v.quality
				}

				table.insert(itemlist, attachment)

				if #itemlist == 3 then
					sendGmMailByActorIdEx(actorid, mailtips, itemlist, "activity_liveness", serverid)
					itemlist = {}
				end
			end
		end
	end
	if #itemlist > 0 then
		sendGmMailByActorIdEx(actorid, mailtips, itemlist, "activity_liveness", serverid)
		itemlist = {}
	end
end

function initOperations()
	for activityid, _ in pairs(config) do
		operations.regStartEvent(activityid, openActivity)
		operations.regCloseEvent(activityid, closeActivity)
	end
end

function checkLiveness(actor)
	if actor == nil then return end
	local var = LActor.getSysVar(actor)
	if var == nil or var.liveness == nil or var.liveness.total == nil then return end

	onChangeLiveness(actor, 0, var.liveness.total)
end

table.insert(InitFnTable, initOperations)

actorevent.reg(aeUserLogin, onLogin, true)

netmsgdispatcher.reg(sysid, protocol.cGetLivenessAward, getAwards)


