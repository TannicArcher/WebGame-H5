module("systems.txvipaward.tx3366award", package.seeall)
setfenv(1, systems.txvipaward.tx3366award)

require("txvipaward.award3366conf")
require("protocol")

local actorevent       = require("actorevent.actorevent")
local netmsgdispatcher = require("utils.net.netmsgdispatcher")

local System = System
local LActor = LActor
local tips = Lang.ScriptTips

local timeRewardSystem = SystemId.timeRewardSystem
local TimeRewardSystemProtocol = TimeRewardSystemProtocol

function getStaticVar( actor )
	local var = LActor.getSysVar(actor)
	if var.tx3366info == nil then
		var.tx3366info = {}
	end

	return var.tx3366info
end

function sendStatu( actor )
	local var = getStaticVar(actor)
	local tx3366 = var.tx3366 or false
	local record = var.record or 0

	local is3366 = 1
	if not tx3366 then is3366 = 0 end

	local pack = LDataPack.allocPacket(actor, timeRewardSystem, TimeRewardSystemProtocol.s3366Info)
	if not pack then return end

	LDataPack.writeData(pack, 2, dtByte, is3366, dtByte, record)
	LDataPack.flush(pack)
end

local function getAward( actor, pack )
	local var = getStaticVar(actor)
	local is3366 = var.tx3366 or false
	local record = var.record
	local lvl_3366 = var.lvl3366 or 0

	if not is3366 then
		LActor.sendTipmsg( actor, tips.ta010 )
		return
	end

	if record then
		LActor.sendTipmsg( actor, tips.ta001 )
		return
	end

	local awardConf
	for i,v in ipairs(Award3366Conf) do
		if lvl_3366 >= v.lvl[1] and lvl_3366 <= v.lvl[2] then
			awardConf = v
			break
		end
	end

	if not awardConf then
		print("award3366conf no config....", lvl_3366)
		return
	end

	if Item.getBagEmptyGridCount(actor) < awardConf.needBag then
		return LActor.sendTipmsg(actor, tips.oa003)
	end

	var.record = 1

	--发奖励
	local cl3366LiBao = 780
	for _, iteminfo in pairs(awardConf.items) do
		LActor.giveAward(actor, iteminfo.type, iteminfo.num, cl3366LiBao, iteminfo.param, "3366_libao", iteminfo.bind);
	end

	sendStatu(actor)
end

local function onNewDay( actor )
	local var = getStaticVar(actor)
	var.record = nil
	sendStatu(actor)
end

actorevent.reg(aeNewDayArrive, onNewDay)
netmsgdispatcher.reg(timeRewardSystem, TimeRewardSystemProtocol.cGet3366Award, getAward)

