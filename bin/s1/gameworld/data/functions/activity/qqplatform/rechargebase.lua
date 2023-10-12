module("activity.qqplatform.rechargebase", package.seeall)
setfenv(1, activity.qqplatform.rechargebase)

local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local mailsystem = require("systems.mail.mailsystem")
local postscripttimer = require("base.scripttimer.postscripttimer")
local actorevent = require("actorevent.actorevent")
local abase = require("systems.awards.abase")
local operations = require("systems.activity.operations")

require("protocol")

local protocol = YunyingActivityProtocal
local systemId = SystemId.yunyingActivitySystem 
local Lang = Lang.ScriptTips
local rcmd = protocol.sSendRechargeInfo

local subActId = SubActConf.DAILY_RECHARGE

local ActivityConfig = operations.getSubActivitys(subActId)

function getSysVar(actId)
	if not actId then return end

	local var = System.getStaticVar()
	if not var then return end

	if not var.rechargebase then
		var.rechargebase = {}
	end

	if not var.rechargebase[actId] then
		var.rechargebase[actId] = {}
	end
	return var.rechargebase[actId]
end

function getActorVar(actor, actId)
	if not actor or not actId then return end

	local var = LActor.getPlatVar(actor)
	if not var then return end

	if not var.rechargebase then
		var.rechargebase = {}
	end

	if not var.rechargebase[actId] then
		var.rechargebase[actId] = {}
	end
	return var.rechargebase[actId]
end

function rechargeInit(id, beginTime, endTime)
	print("open recharge activity .....")

	--初始化玩家信息
	local players = LuaHelp.getAllActorList()
	if players then
		for _, player in ipairs(players) do
			resetActorVar(player, id, endTime)
		end
	end
end

function rechargeClose(id, beginTime, endTime, subAct)
	print("close recharge activity .....")

	if not subAct then subAct = subActId end
	local act = operations.getConf(id, subAct)
	if not act then return end

	--发送未领取邮件奖励
	local players = LuaHelp.getAllActorList()
	if players then
		for _, player in ipairs(players) do
			mailAward(player, id, act.config)
		end
	end
end

function awardCheck(actor, actId, idx, config)
	if not actId or not config then return end

	local level = getLimit(actor, actId, config) or 0

	if level <= 0 or idx > level then return true end

	local var = getActorVar(actor, actId)
	if not var then return true end

	local situation = var.situation or 0

	for k = 1, level do
		if System.getIntBit(situation, k) ~= 1 then
			return false
		end
	end

	return true
end

function getLimit(actor, actId, config)
	if not actId or not config then return end

	local var = getActorVar(actor, actId)
	if not var or not var.recharge then return end

	local recharge, index = var.recharge, 0

	for k, info in ipairs(config.awards) do
		if recharge >= info.limit then
			index = k
		end
	end

	return index
end

function checkSendAward(actor, actId, idx, config)
	if not operations.isInTime(actId) then return end

	local var = getActorVar(actor, actId)
	if not var then return end

	if idx <= 0 or idx > #config.awards then return end

	if awardCheck(actor, actId, idx, config) then
		LActor.sendTipmsg(actor, Lang.ljcz003)
		return
	end

	var.situation = var.situation or 0

	if System.getIntBit(var.situation, idx) ~= 0 then
		LActor.sendTipmsg(actor, Lang.ljcz001)
		return
	end

	local conf = config.awards[idx]
	if not conf or not conf.awards or not conf.limit then return end

	local count, needspace = 0, 0
	for _, info in ipairs(conf.awards) do
		if info.rewardtype == qatItem then
			needspace = Item.getAddItemNeedGridCount(actor, info.itemid, info.amount)
			count = count + needspace
		end
	end

	if Item.getBagEmptyGridCount(actor) < count then
		LActor.sendTipmsg(actor, Lang.ljcz002)
		return
	end

	abase.sendAwards(actor, conf.awards, config.log or "recharge")

	var.situation = System.setIntBit(var.situation, idx, true)

	return true
end

function getAward(actor, packet)
	if not System.isCommSrv() then return end

	local actId = LDataPack.readInt(packet)
	local idx = LDataPack.readInt(packet)

	local config = ActivityConfig[actId].config
	if not config then return end

	if checkSendAward(actor, actId, idx, config) then
		sendBaseInfo(actor, actId, systemId, rcmd)
	end
end

function rechargeInsert(tb, info)
	for _, t in ipairs(tb) do
		if t.rewardtype == info.rewardtype and t.type == info.type and t.itemid == info.itemid then
			t.amount = t.amount + info.amount
			return
		end
	end

	table.insert(tb, info)
end

function resetActorVar(actor, actId, time)
	if not actor or not actId then return end

	local actor_var = getActorVar(actor, actId)
	if not actor_var then return end
	actor_var.recharge = nil
	actor_var.situation = nil
	if time then 
		actor_var.tenancy = time
	end
end

function mailAward(actor, actId, config)
	if not System.isCommSrv() then return end

	if not actId or not config then return end

	local level = getLimit(actor, actId, config) or 0
	if level == 0 then
		resetActorVar(actor, actId)
		return
	end

	local actor_var = getActorVar(actor, actId)
	if not actor_var then return end
	local situation = actor_var.situation or 0
	local allinfo = config.awards

	local awards = {}
	for k = 1, level do
		if System.getIntBit(situation, k) ~= 1 then
			for _, info in ipairs(allinfo[k].awards) do
				rechargeInsert(awards, info)
			end
		end
	end

	if #awards <= 0 then
		resetActorVar(actor, actId)
		return
	end

	local aid = LActor.getActorId(actor)
	local sid = LActor.getServerId(actor)
	local attachlist, qtype = {}
	local mailtips = config.tips or "SYSTEM"

	for _, v in ipairs(awards) do
		if v.rewardtype == qatItem then
			qtype = mailsystem.TYPE_ITEM
		elseif v.rewardtype == qatBindMoney or v.rewardtype == qatMoney
		or v.rewardtype == qatBindYuanBao or v.rewardtype == qatYuanbao then
			qtype = mailsystem.TYPE_MONEY
		else
			qtype = mailsystem.TYPE_VAL
		end

		local attachment =
 		{
			type    = qtype,
			param   = v.itemid,
			count   = v.amount,
			bind    = v.bind,
			quality = v.quality
		}

		table.insert(attachlist, attachment)

		if #attachlist == 3 then
			sendGmMailByActorIdEx(aid, mailtips, attachlist, "rechargesys", sid)
			attachlist = {}
		end
	end

	if #attachlist > 0 then
		sendGmMailByActorIdEx(aid, mailtips, attachlist, "rechargesys", sid)
	end

	resetActorVar(actor, actId)
end

function sendBaseInfo(actor, actId, sysId, cmd)
	local var = getActorVar(actor, actId)
	if not var then return end

	local pack = LDataPack.allocPacket(actor, sysId, cmd)
	if pack == nil then return end

	--print("recharge val:", var.recharge)
	--print(var.situation or 0)

	--local optime = operations.isInTime(actId)
	--print("op time:" ,optime)

	--local a, b, c, d, e, f = System.timeDecode(var.tenancy or 0)
	--local timetip = string.format("%d-%d-%d %d:%d:%d", a,b,c,d,e,f)
	--print("close time: "..timetip)
	LDataPack.writeInt(pack, actId)
	LDataPack.writeInt(pack, var.recharge or 0)
	LDataPack.writeInt(pack, var.situation or 0)
	LDataPack.flush(pack)
end

function getRechargeInfo(actor, packet)
	if not System.isCommSrv() then return end

	if not actor or not packet then return end

	local actId = LDataPack.readInt(packet)

	sendBaseInfo(actor, actId, systemId, rcmd)
end

function loginCheck(actor, actId, config, freshEveryDay)
	local closetime = operations.isInTime(actId)

	local var = getActorVar(actor, actId)
	if not var then return end

	local check = not closetime or (var.tenancy and var.tenancy ~= closetime)

	if freshEveryDay and not check then
		local now = System.getNowTime()
		if not var.freshTime or not System.isSameDay(var.freshTime, now) then
			check = true
			var.freshTime = now
		end
	end

	--如果有奖励没有领取
	--	1.活动结束时上线发奖励， 
	--	2.上次活动中离线，在本次活动中上线也需要发上次活动奖励
	if check then mailAward(actor, actId, config) end

	--检测是不是同一租期
	if closetime and (not var.tenancy or var.tenancy ~= closetime) then
		var.tenancy = closetime
	end
end

function rechargeVal(actor, val, actId, sysId, cmd)
	local var = getActorVar(actor, actId)
	if not var then return end

	if operations.isInTime(actId) then
		var.recharge = (var.recharge or 0) + val
		sendBaseInfo(actor, actId, sysId, cmd)
	end
end

function dailyRechargeVal(actor, val)
	if not System.isCommSrv() then return end

	for actId, info in pairs(ActivityConfig) do
		rechargeVal(actor, val, actId, systemId, rcmd)
	end
end

function onUserLogin(actor)
	for actId, info in pairs(ActivityConfig) do
		loginCheck(actor, actId, info.config, true)
	end
end

function onNewDay(actor)
	for actId, info in pairs(ActivityConfig) do
		mailAward(actor, actId, info.config)
		if operations.isInTime(actId) then
			sendBaseInfo(actor, actId, systemId, rcmd)
		end
	end
end

function initOperations()
	for actId, info in pairs(ActivityConfig) do
		operations.regStartEvent(actId, rechargeInit)
		operations.regCloseEvent(actId, rechargeClose)
	end
end

_G.getAward = getAward

table.insert(InitFnTable, initOperations)

actorevent.reg(aeRecharge, dailyRechargeVal)

actorevent.reg(aeNewDayArrive, onNewDay, true)

actorevent.reg(aeUserLogin, onUserLogin, true)

netmsgdispatcher.reg(systemId, protocol.cBaseRechargeAward, getAward)
netmsgdispatcher.reg(systemId, protocol.cQueryRechargeInfo, getRechargeInfo)


