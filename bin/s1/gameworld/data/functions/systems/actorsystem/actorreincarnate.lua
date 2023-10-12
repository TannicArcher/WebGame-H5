module("actorreincarnate", package.seeall)
--轮回系统


--[[
reincarnateData = {
	levelCount 等级已兑换次数
	normalCount 普通道具兑换次数
	advanceCount 高级道具兑换次数
}
 ]]

local ReincarnationConf = ReincarnationBase
local ExchangeConf = ReincarnationExchange
local levelConf = ReincarnationLevel

local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)

	if nil == var.reincarnateData then var.reincarnateData = {} end
	return var.reincarnateData
end

local function updateInfo(actor)
	local actorId = LActor.getActorId(actor)
	local actordata = LActor.getActorData(actor)
	if nil == actordata then print("actorreincarnate.updateInfo:actordata nil, actorId:"..tostring(actorId)) return end
	local data = getStaticData(actor)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Reincarnate, Protocol.sReincarnateCMD_UpdateInfo)
	LDataPack.writeInt(npack, actordata.reincarnate_lv)
	LDataPack.writeInt(npack, actordata.reincarnate_exp)
	LDataPack.writeShort(npack, data.levelCount or 0)
	LDataPack.writeShort(npack, data.normalCount or 0)
	LDataPack.writeShort(npack, data.advanceCount or 0)
	LDataPack.flush(npack)
end

--检测开启等级
function checkOpenLevel(actor)
	local level = LActor.getZhuanShengLevel(actor) * 1000
	level = level + LActor.getLevel(actor)
	if level < ReincarnationConf.openLevel then return false end

	return true
end

local function updateAttr(actor)
	local actorId = LActor.getActorId(actor)
	local actordata = LActor.getActorData(actor)
	if nil == actordata then print("actorreincarnate.updateAttr:actordata nil, actorId:"..tostring(actorId)) return end

	local attr = LActor.GetReincarnateAttr(actor)
	if not attr then return end
	attr:Reset()

	local ex_attr = LActor.GetReincarnateExAttr(actor)
	if not ex_attr then return end
	ex_attr:Reset()

	local conf = levelConf[actordata.reincarnate_lv]
	if conf then
		for _, v in pairs(conf.attrs or {}) do attr:Add(v.type, v.value) end
		for _, v in pairs(conf.ex_attrs or {}) do ex_attr:Add(v.type, v.value) end
		attr:SetExtraPower(conf.ex_power or 0)

		LActor.reCalcAttr(actor)
		LActor.reCalcExAttr(actor)
	end
end

local function onReqPromote(actor, packet)
	local method = LDataPack.readByte(packet)
	local actorId = LActor.getActorId(actor)
	local data = getStaticData(actor)

	if false == checkOpenLevel(actor) then print("actorreincarnate.onReqPromote:level limit, actorId:"..tostring(actorId)) return end

	local exp = 0
	if 1 == method then --等级转换
		--转换次数是否用完
		if ReincarnationConf.levelExchangeTimes <= (data.levelCount or 0) then
			print("actorreincarnate.onReqPromote:levelCount limit , actorId:"..tostring(actorId))
			return
		end

		local level = LActor.getLevel(actor)
		if not ExchangeConf[level] then
			print("actorreincarnate.onReqPromote:conf nil, level:"..tostring(level)..", actorId:"..tostring(actorId))
			return
		end

		exp = ExchangeConf[level].value or 0

		--扣等级
		LActor.setLevel(actor, level - 1)
		LActor.onLevelUp(actor)
		LActor.addExp(actor, 0, "reincarnate reset exp")

		data.levelCount = (data.levelCount or 0) + 1

	elseif 2 == method then --普通物品提升
		if (data.normalCount or 0) >= ReincarnationConf.normalItem.time then
			print("actorreincarnate.onReqPromote:normalCount limit, actorId:"..tostring(actorId))
			return
		end

		--物品够不够
		if 0 >= LActor.getItemCount(actor, ReincarnationConf.normalItem.id) then
			print("actorreincarnate.onReqPromote:normal item not enough, actorId:"..tostring(actorId))
			return
		end

		LActor.costItem(actor, ReincarnationConf.normalItem.id, 1, "reincarnatenormal")
		data.normalCount = (data.normalCount or 0) + 1

		exp = ReincarnationConf.normalItem.value

	elseif method == 3 then --高级物品提升
		if (data.advanceCount or 0) >= ReincarnationConf.advanceItem.time then
			print("actorreincarnate.onReqPromote:advanceCount limit, actorId:"..tostring(actorId))
			return
		end

		--物品够不够
		if 0 >= LActor.getItemCount(actor, ReincarnationConf.advanceItem.id) then
			print("actorreincarnate.onReqPromote:advance item not enough, actorId:"..tostring(actorId))
			return
		end

		LActor.costItem(actor, ReincarnationConf.advanceItem.id, 1, "reincarnatenormal")
		data.advanceCount = (data.advanceCount or 0) + 1

		exp = ReincarnationConf.advanceItem.value
	else
		print("actorreincarnate.onReqPromote:method error, actorId:"..tostring(actorId))
		return
	end

	local actordata = LActor.getActorData(actor)
	if nil == actordata then print("actorreincarnate.onReqPromote:actordata nil, actorId:"..tostring(actorId)) return end

	actordata.reincarnate_exp = actordata.reincarnate_exp + exp
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
		"get reincarnate exp", tostring(exp), tostring(actordata.reincarnate_exp), "", "method"..tostring(method), "", "")

	updateInfo(actor)
end

local function onReqUpgrade(actor, packet)
	local actorId = LActor.getActorId(actor)
	local actordata = LActor.getActorData(actor)
	if nil == actordata then print("actorreincarnate.onReqUpgrade:actordata nil, actorId:"..tostring(actorId)) return end

	if false == checkOpenLevel(actor) then print("actorreincarnate.onReqUpgrade:level limit, actorId:"..tostring(actorId)) return end

	local config = levelConf[actordata.reincarnate_lv + 1]
	if not config then
		print("actorreincarnate.onReqUpgrade:conf nil ,level:"..tostring(actordata.reincarnate_lv + 1)..", actorId:"..tostring(actorId))
		return
	end

	--经验够不够
	if actordata.reincarnate_exp < config.consume then print("actorreincarnate.onReqUpgrade:exp not enough, actorId:"..tostring(actorId)) return end

	actordata.reincarnate_exp = actordata.reincarnate_exp - config.consume
	actordata.reincarnate_lv = actordata.reincarnate_lv + 1

	--公告
	if config.noticeId then noticemanager.broadCastNotice(config.noticeId, LActor.getName(actor)) end

	updateInfo(actor)

	updateAttr(actor)

    System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
        "cost reincarnate exp", tostring(config.consume), tostring(actordata.reincarnate_exp), "", "upgrade reincarnate level", "", "")
end

local function onLogin(actor)
	if false == checkOpenLevel(actor) then return end
	updateInfo(actor)
end

local function onInit(actor)
	if false == checkOpenLevel(actor) then return end
	updateAttr(actor)
end

local function onNewDay(actor, isLogin)
	if false == checkOpenLevel(actor) then return end
	local data = getStaticData(actor)
	data.levelCount = nil
	data.normalCount = nil
	data.advanceCount = nil

	if not isLogin then updateInfo(actor) end
end

local function onLevelUp(actor, zsLevel)
	updateInfo(actor)
end

function addExp(actor, val)
    if not val then return end
    local actorId = LActor.getActorId(actor)
    local actordata = LActor.getActorData(actor)
    if nil == actordata then print("actorreincarnate.addExp:actordata nil, actorId:"..tostring(actorId)) return end

    actordata.reincarnate_exp = actordata.reincarnate_exp + val
    updateInfo(actor)
end

local function initFunc()
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeNewDayArrive, onNewDay)
	actorevent.reg(aeInit, onInit)
	actorevent.reg(aeZhuansheng, onLevelUp)

	netmsgdispatcher.reg(Protocol.CMD_Reincarnate, Protocol.cReincarnateCMD_ReqPromote, onReqPromote)
	netmsgdispatcher.reg(Protocol.CMD_Reincarnate, Protocol.cReincarnateCMD_ReqUpgrade, onReqUpgrade)
end
table.insert(InitFnTable, initFunc)

local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.reincarnate = function(actor, args)
	local actordata = LActor.getActorData(actor)
    if actordata == nil then print("get actorData error") return end
    actordata.reincarnate_exp = actordata.reincarnate_exp + tonumber(args[1])
    updateInfo(actor)
end
