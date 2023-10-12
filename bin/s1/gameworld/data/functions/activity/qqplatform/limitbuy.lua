--限时抢购
module("activity.qqplatform.limitbuy", package.seeall)
setfenv(1, activity.qqplatform.limitbuy)

require("activity.operationsconf")
require("protocol")

local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local actorevent = require("actorevent.actorevent")
local monevent = require("monevent.monevent")
local operations = require("systems.activity.operations")
local actorfunc = require("utils.actorfunc")

local config = operations.getSubActivitys(SubActConf.LIMIT_TIME_BUY)

local sysid = SystemId.yunyingActivitySystem
local protocol = YunyingActivityProtocal
local lang = Lang.ScriptTips

function getLimitbuyVar(actor, activityid)
	if actor == nil or activityid == nil then return end
	local var = LActor.getPlatVar(actor)
	if var == nil then return end

	if var.limitbuy == nil then
		var.limitbuy = {}
	end
	if var.limitbuy[activityid] == nil then
		var.limitbuy[activityid] = {}
	end

	return var.limitbuy[activityid]
end
function resetLimitbuyVar(actor, activityid)
	if not actor or not activityid then return end

	local var = LActor.getPlatVar(actor)
	if var and var.limitbuy and var.limitbuy[activityid] then
		var.limitbuy[activityid] = nil
	end
end

--玩家参加该活动的时间
function setActorActivityTime(actor, activityid)
	local var = getLimitbuyVar(actor, activityid)
	if not var then return end

	var.opentime = operations.getActivityTime(activityid)
end
function getActorActivityTime(actor, activityid)
	local var = getLimitbuyVar(actor, activityid)
	if not var then return 0 end

	return var.opentime or 0
end

local function getStaticVar(activityid)
	if not System.isCommSrv() or activityid == nil then return end

	local var = System.getStaticVar()
	if var == nil then return end

	if var.limitbuy == nil then
		var.limitbuy = {}
	end
	if var.limitbuy[activityid] == nil then
		var.limitbuy[activityid] = {}
	end

	return var.limitbuy[activityid]
end
function resetStaticVar(activityid)
	if not System.isCommSrv() or activityid == nil then return end

	local var = System.getStaticVar()
	if var and var.limitbuy and var.limitbuy[activityid] then
		var.limitbuy[activityid] = nil
	end
end

--开启活动
function openActivity(activityid)
	if not System.isCommSrv() then return end
	if not operations.isInTime(activityid) then return end

	resetStaticVar(activityid)

	local players = LuaHelp.getAllActorList()
	if players == nil then return end

	for _, player in ipairs(players) do
		resetLimitbuyVar(player, activityid)
		onSendInfo(player, activityid)
		setActorActivityTime(actor, activityid)
	end
end

--发送信息
function onSendInfo(actor, activityid)
	if not System.isCommSrv() or not operations.isInTime(activityid) then return end

	if not actor or not activityid or not config[activityid] or not config[activityid].config then return end

	local activityConf = config[activityid].config

	local var = getLimitbuyVar(actor, activityid)
	if var == nil then return end
	local sys_var = getStaticVar(activityid)
	if sys_var == nil then return end

	local activity_var = operations.getSysVar(activityid)
	if not activity_var or not activity_var.begTime then return end

	local daycount = System.getDayDiff(System.getNowTime(), activity_var.begTime) + 1
	local awardsConf = activityConf.item[daycount]
	if awardsConf == nil then return end

	local npack = LDataPack.allocPacket(actor, sysid, protocol.sSendLimitBuy)
	if npack == nil then return end
	
	LDataPack.writeInt(npack, activityid)
	LDataPack.writeInt(npack, daycount)

	local total = #awardsConf
	LDataPack.writeInt(npack, total)

	for i, iteminfo in ipairs(awardsConf) do
		local tmp1 = 0
		local tmp2 = iteminfo.firstcount
		if var.item and var.item[i] then
			tmp1 = var.item[i]
		end
		if sys_var.item and sys_var.item[i] then
			tmp2 = sys_var.item[i]
		end

		LDataPack.writeInt(npack, iteminfo.itemid)
		LDataPack.writeInt(npack, iteminfo.limitcount - tmp1)
		LDataPack.writeInt(npack, tmp2)
	end

	LDataPack.flush(npack)
end

--购买物品
function buyItem(actor, packet)
	if actor == nil or packet == nil then return end

	local activityid = LDataPack.readInt(packet)
	local itemid = LDataPack.readInt(packet)

	if not System.isCommSrv() or not operations.isInTime(activityid) then return end

	local var = getLimitbuyVar(actor, activityid)
	if var == nil then return end
	local sys_var = getStaticVar(activityid)
	if sys_var == nil then return end
	
	local activity_var = operations.getSysVar(activityid)
	if not activity_var or not activity_var.begTime then return end

	local daycount = System.getDayDiff(System.getNowTime(), activity_var.begTime) + 1
	if config[activityid] == nil or config[activityid].config == nil then return end

	local awardsConf = config[activityid].config.item[daycount]
	if awardsConf == nil then return end

	local idx
	local iteminfo
	for i, conf in ipairs(awardsConf) do
		if conf.itemid == itemid then
			idx = i
			iteminfo = conf
			break
		end
	end
	if idx == nil or iteminfo == nil then return end

	if LActor.getMoneyCount(actor, mtYuanbao) < iteminfo.price then
		LActor.sendTipmsg(actor, lang.limitbuy001, ttWarmTip)
		return
	end

	if Item.getBagEmptyGridCount(actor) <= 0 then
		LActor.sendTipmsg(actor, lang.limitbuy002, ttWarmTip)
		return
	end

	if var.item == nil then
		var.item = {}
	end
	if sys_var.item == nil then
		sys_var.item = {}
	end
	if var.item[idx] and var.item[idx] >= iteminfo.limitcount then return end

	var.item[idx] = (var.item[idx] or 0) + 1
	sys_var.item[idx] = (sys_var.item[idx] or iteminfo.firstcount) + 1

	local tips = string.format("qqplatform_%d_%d", activityid, SubActConf.LIMIT_TIME_BUY)
	LActor.changeMoney(actor, mtYuanbao, -iteminfo.price, 1, true, tips, "limitbuy", string.format("itemid:%d", iteminfo.itemid))
	LActor.addItem(actor, iteminfo.itemid, 0, iteminfo.strong, iteminfo.count, iteminfo.bind, tips, 785)

	onSendInfo(actor, activityid)
	broadBuyItem(activityid, iteminfo.itemid, sys_var.item[idx])
end

--广播玩家购买了物品
function broadBuyItem(activityid, itemid, count)
	local pack = LDataPack.allocBroadcastPacket(sysid, protocol.sBroadLimitBuy)
	if not pack then return end

	LDataPack.writeInt(pack, activityid)
	LDataPack.writeInt(pack, itemid)
	LDataPack.writeInt(pack, count)
	System.broadcastData(pack)
end

function newDayLogin(actor)
	if actor == nil then return end

	for activityid, _ in pairs(config) do
		local var = getLimitbuyVar(actor, activityid)
		if var == nil then return end

		var.item = {}
		onSendInfo(actor, activityid)
	end
end
function onLogin(actor)
	if actor == nil then return end

	for activityid, _ in pairs(config) do
		if operations.isInTime(activityid) then
			local activityTime = operations.getActivityTime(activityid)
			local actorActivityTime = getActorActivityTime(actor, activityid)

			if activityTime ~= 0 and activityTime ~= actorActivityTime then
				resetLimitbuyVar(actor, activityid)
				setActorActivityTime(actor, activityid)
			end

			local today = System.getToday()
			local sys_var = getStaticVar(activityid)
			if sys_var and (sys_var.refreshTime == nil or sys_var.refreshTime ~= today) then	
				sys_var.refreshTime = today
				sys_var.item = {}
			end

			onSendInfo(actor, activityid)
		end
	end
end

function initOperations()
	for activityid, _ in pairs(config) do
		operations.regStartEvent(activityid, openActivity)
	end
end

table.insert(InitFnTable, initOperations)

actorevent.reg(aeUserLogin, onLogin, true)
actorevent.reg(aeNewDayArrive, newDayLogin)

netmsgdispatcher.reg(sysid, protocol.cBuyLimitItem, buyItem)

