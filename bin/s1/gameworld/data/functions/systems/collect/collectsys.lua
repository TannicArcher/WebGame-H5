module("systems.collect.collectsys", package.seeall)
setfenv(1, systems.collect.collectsys)

local actorevent = require("actorevent.actorevent")
local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local abase = require("systems.awards.abase")

local systemId = SystemId.miscsSystem
local protocol = MiscsSystemProtocol
local ScriptTips = Lang.ScriptTips

require("collect.collectconf")
config = CollectConf

function getCollectVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var then return end

	if not var.collectsys then
		var.collectsys = {}
	end

	return var.collectsys
end

function sendCollectInfo(actor, flg)
	local pack = LDataPack.allocPacket(actor, systemId, protocol.sCollectGift)
	if not pack then return end
	LDataPack.writeByte(pack,flg)
	LDataPack.flush(pack)
end

function recvCollect(actor, packet)
	local var = getCollectVar(actor)
	if not var then return end

	if var.hasCollect then return end

	local count = 0
	for _,c in ipairs(config.awards) do
		if c.rewardtype == qatItem then count = count + 1 end
	end

	if count > Item.getBagEmptyGridCount(actor) then
		LActor.sendTipmsg(actor, ScriptTips.collect002, ttMessage)
		return
	end

	abase.sendAwards(actor, config.awards, "collect")

	sendCollectInfo(actor, 1)

	var.hasCollect = 1

	LActor.sendTipmsg(actor, ScriptTips.collect001, ttMessage)
end

function userLogin(actor)
	local level = LActor.getRealLevel(actor)
	if level < config.openLevel then return end

	local var = getCollectVar(actor)
	if not var then return end

	if not var.hasCollect then
		sendCollectInfo(actor, 0) 
	else
		sendCollectInfo(actor, 1)
	end
end

actorevent.reg(aeUserLogin, userLogin)
actorevent.reg(aeLevel, userLogin)

netmsgdispatcher.reg(systemId, protocol.cCollectGift, recvCollect)