--藏宝阁
module("systems.cangbaoge.cangbaoge", package.seeall)
setfenv(1, systems.cangbaoge.cangbaoge)

local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local actorevent = require("actorevent.actorevent")
local postscripttimer = require("base.scripttimer.postscripttimer")
local operations = require("systems.activity.operations")

require("protocol")
local SystemId = SystemId.yunyingActivitySystem
local protocol = YunyingActivityProtocal

require("activity.operationsconf")
local config = operations.getSubActivitys(SubActConf.CANG_BAO_GE)

local tips = Lang.Cangbaoge

--开启藏宝阁
function openCangbaoge(activityId)
	if not System.isCommSrv() then return end
	if not operations.isInTime(activityId) then return end

	local players = LuaHelp.getAllActorList()
	if players == nil then return end

	for _, player in ipairs(players) do
		resetActorVar(player, activityId)
		setActorActivityTime(player, activityId)
		onRefresh(player, activityId, false, true)
	end
end

--关闭藏宝阁
function closeCangbaoge(activityId)
	if not System.isCommSrv() then return end

	local players = LuaHelp.getAllActorList()
	if players == nil then return end

	for _, player in ipairs(players) do
		local actor_var = getActorVar(actor, activityId)
		if actor_var and actor_var.timerid then
			postscripttimer.cancelScriptTimer(actor, actor_var.timerid)
			actor_var.timerid = nil
		end
	end
end

function getActorVar(actor, activityId)
	if not actor or not activityId then return end

	local var = LActor.getPlatVar(actor)
	if not var then return end

	if not var.treasure then var.treasure = {} end
	if not var.treasure[activityId] then var.treasure[activityId] = {} end

	return var.treasure[activityId]
end
function resetActorVar(actor, activityId)
	if not actor or not activityId then return end

	local var = LActor.getPlatVar(actor)
	if not var or not var.treasure or not var.treasure[activityId] then return end

	var.treasure[activityId] = nil
end

--玩家参加该活动的时间
function setActorActivityTime(actor, activityId)
	local var = getActorVar(actor, activityId)
	if not var then return end

	var.opentime = operations.getActivityTime(activityId)
end
function getActorActivityTime(actor, activityId)
	local var = getActorVar(actor, activityId)
	if not var then return 0 end

	return var.opentime or 0
end

--刷新藏宝阁
function onRefresh(actor, activityId, quick, first)
	if not operations.isInTime(activityId) or not actor then return end

	if not config[activityId] or not config[activityId].config then return end
	local conf = config[activityId].config

	local actor_var = getActorVar(actor, activityId)
	if not actor_var then return end

	actor_var.item = {}
	local itemcount = 1
	--随机元宝物品
	local itemlist = table.deepcopy(conf.yuanbaoItem)
	for i = 1, conf.yuanbaoCount do
		actor_var.item[itemcount] = {}
		actor_var.item[itemcount].moneytype = 3
		actor_var.item[itemcount].situation = 0
		actor_var.item[itemcount].itemid = randomItem(itemlist, first)
		itemcount = itemcount + 1
	end
	
	--随机金币物品
	local itemlist = table.deepcopy(conf.coinItem)
	for i = 1, conf.coinCount do
		actor_var.item[itemcount] = {}
		actor_var.item[itemcount].moneytype = 1
		actor_var.item[itemcount].situation = 0
		actor_var.item[itemcount].itemid = randomItem(itemlist, first)
		itemcount = itemcount + 1
	end

	if not quick then
		actor_var.timerid = postscripttimer.postOnceScriptEvent(actor, conf.refreshTime*1000, function(...) onRefresh(...) end, activityId)
		actor_var.refreshTime = System.getNowTime() + conf.refreshTime
	end

	onSendInfo(actor, activityId)
end
function randomItem(itemlist, first)
	if first then
		for j, itemConf in ipairs(itemlist) do
			if itemConf.first then
				table.remove(itemlist, j)
				return itemConf.itemid
			end
		end
	else
		local TotalPresent = 0
		for _, itemConf in ipairs(itemlist) do
			TotalPresent = TotalPresent + itemConf.present
		end

		local r = System.getRandomNumber(TotalPresent)
		local total = 0
		for j, itemConf in ipairs(itemlist) do
			total = total + itemConf.present
			if r < total then
				table.remove(itemlist, j)
				return itemConf.itemid
			end
		end
	end
	return 0
end

--立即刷新藏宝阁
function quickRefresh(actor, packet)
	if not actor or not packet then return end
	local activityId = LDataPack.readInt(packet)

	if not System.isCommSrv() or not operations.isInTime(activityId) then return end
	if not config[activityId] or not config[activityId].config then return end

	local conf = config[activityId].config
	if LActor.getMoneyCount(actor, mtYuanbao) < conf.refreshPrice then
		LActor.sendTipmsg(actor, tips.t001)
		return
	end

	local actor_var = getActorVar(actor, activityId)
	if not actor_var then return end

	if actor_var.hasRefresh and actor_var.hasRefresh >= conf.refreshCount then
		return
	end

	LActor.changeMoney(actor, mtYuanbao, -conf.refreshPrice, 1, true, "cangbaoge", "quickRefresh")

	actor_var.hasRefresh = (actor_var.hasRefresh or 0) + 1
	onRefresh(actor, activityId, true)
end

--购买物品
function buyItem(actor, packet)
	if actor == nil or packet == nil then return end

	local activityId, moneyType, itemid = LDataPack.readData(packet, 3, dtInt, dtInt, dtInt)

	if not System.isCommSrv() then return end
	if not operations.isInTime(activityId) then return end

	if moneyType ~= mtYuanbao and moneyType ~= mtBindCoin then return end
	if not config[activityId] or not config[activityId].config then return end
	local conf = config[activityId].config

	local actor_var = getActorVar(actor, activityId)
	if not actor_var or not actor_var.item then return end

	local idx
	if moneyType == mtYuanbao then
		for i = 1, conf.yuanbaoCount do
			if actor_var.item[i] and actor_var.item[i].itemid == itemid
				and actor_var.item[i].situation == 0 then

				idx = i
				break
			end
		end
	elseif moneyType == mtBindCoin then
		for i = conf.yuanbaoCount + 1, conf.coinCount + conf.yuanbaoCount do
			if actor_var.item[i] and actor_var.item[i].itemid == itemid
				and actor_var.item[i].situation == 0 then

				idx = i
				break
			end
		end
	end
	if idx == nil then return end

	if Item.getBagEmptyGridCount(actor) <= 0  then
		LActor.sendTipmsg(actor, tips.t002)
		return
	end

	local itemlist = conf.yuanbaoItem
	if moneyType == mtBindCoin then
		itemlist = conf.coinItem
	end
	local iteminfo
	for _, itemConf in ipairs(itemlist) do
		if itemConf.itemid == itemid then
			iteminfo = itemConf
			break
		end
	end
	if iteminfo == nil then return end

	if iteminfo.broadcast then
		local tmp
		if moneyType == mtYuanbao then
			tmp = tips.t003
		else
			tmp = tips.t004
		end
		local msg = string.format(tmp, LActor.getActorLink(actor), iteminfo.price, Item.getItemLinkMsg(iteminfo.itemid))
		System.broadcastTipmsg(msg, ttHearsay)
	end
	actor_var.item[idx].situation = 1
	LActor.changeMoney(actor, moneyType, -iteminfo.price, 1, true, "cangbaoge", "buyItem", string.format("itemid:%d", iteminfo.itemid))
	LActor.addItem(actor, iteminfo.itemid, 0, iteminfo.strong, iteminfo.count, iteminfo.bind, "cangbaoge", 791)
	onSendInfo(actor, activityId)
end

--发送信息
function onSendInfo(actor, activityId)
	if not actor or not activityId then return end
	if not System.isCommSrv() or not operations.isInTime(activityId) then return end

	local actor_var = getActorVar(actor, activityId)
	if not actor_var then return end

	if actor_var.hasRefresh == nil then
		actor_var.hasRefresh = 0
		actor_var.newdayTime = System.getToday()
	end

	local npack = LDataPack.allocPacket(actor, SystemId, protocol.sSendCangbaogeInfo)
	if npack == nil then return end

	if not config[activityId] or not config[activityId].config then return end
	local conf = config[activityId].config

	LDataPack.writeInt(npack, activityId)

	local itemcount = conf.yuanbaoCount + conf.coinCount
	LDataPack.writeInt(npack, itemcount)
	for i = 1, itemcount do
		LDataPack.writeInt(npack, actor_var.item[i].moneytype)
		LDataPack.writeInt(npack, actor_var.item[i].itemid)
		LDataPack.writeInt(npack, actor_var.item[i].situation)
	end
	LDataPack.writeUInt(npack, actor_var.refreshTime)
	LDataPack.writeInt(npack, conf.refreshCount - actor_var.hasRefresh)

	LDataPack.flush(npack)
end

function onLogin(actor)
	if actor == nil then return end

	for activityId, conf in pairs(config) do
		if operations.isInTime(activityId) and System.isCommSrv() then
			local activityTime = operations.getActivityTime(activityId)
			local actorActivityTime = getActorActivityTime(actor, activityId)

			if activityTime ~= 0 and activityTime ~= actorActivityTime then
				resetActorVar(actor, activityId)
				setActorActivityTime(actor, activityId)
			end
		
			local actor_var = getActorVar(actor, activityId)
			if not actor_var then return end

			if actor_var.hasRefresh == nil then actor_var.hasRefresh = 0 end
			local today = System.getToday()
			if actor_var.newdayTime == nil or actor_var.newdayTime ~= today then
				actor_var.newdayTime = today
				actor_var.hasRefresh = 0
			end

			local refreshTime = conf.config.refreshTime
			if actor_var.refreshTime then
				local now = System.getNowTime()
				refreshTime = actor_var.refreshTime - now
				if refreshTime < 0 then
					local tmp = math.ceil(-refreshTime / conf.config.refreshTime)
					refreshTime = refreshTime + conf.config.refreshTime * tmp
					onRefresh(actor, activityId, true)
					actor_var.refreshTime = now + refreshTime
				end

				actor_var.timerid = postscripttimer.postOnceScriptEvent(actor, (actor_var.refreshTime-now)*1000, function(...) onRefresh(...) end, activityId)
				onSendInfo(actor, activityId)
			else
				onRefresh(actor, activityId, false, true)
			end
		end
	end
end

function newdayArrive(actor)
	if actor == nil then return end
	for activityId, _ in ipairs(config) do
		if operations.isInTime(activityId) then
			local actor_var = getActorVar(actor, activityId)
			if not actor_var then return end

			actor_var.hasRefresh = 0
			actor_var.newdayTime = System.getToday()

			onSendInfo(actor, activityId)
		end
	end
end

actorevent.reg(aeNewDayArrive, newdayArrive)
actorevent.reg(aeUserLogin, onLogin)

function initOperations()
	for activityId, _ in pairs(config) do
		operations.regStartEvent(activityId, openCangbaoge)
		operations.regCloseEvent(activityId, closeCangbaoge)
	end
end

table.insert(InitFnTable, initOperations)

netmsgdispatcher.reg(SystemId, protocol.cCangbaogeBuyItem, buyItem)
netmsgdispatcher.reg(SystemId, protocol.cQuickRefresh, quickRefresh)

