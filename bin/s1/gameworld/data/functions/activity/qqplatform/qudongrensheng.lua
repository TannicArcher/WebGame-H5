module("activity.qqplatform.qudongrensheng", package.seeall)
setfenv(1, activity.qqplatform.qudongrensheng)

require("activity.qqplatform.qudongrenshengconf")
local config = QuDongRenShengConf

local postscripttimer = require("base.scripttimer.postscripttimer")
local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local actorevent = require("actorevent.actorevent")
local abase = require("systems.awards.abase")

local systemId = SystemId.yunyingActivitySystem
local protocol = YunyingActivityProtocal
local ScriptTips = Lang.ScriptTips

function sendDownloadStatus(actor)
	local pack = LDataPack.allocPacket(actor, systemId, protocol.sQudongrenshengDownload)
	if not pack then return end

	local var = LActor.getPlatVar(actor)
	LDataPack.writeByte(pack, var.qdrsdownload or 0)
	LDataPack.flush(pack)
end

function sendAwardStatus(actor)
	local pack = LDataPack.allocPacket(actor, systemId, protocol.sQudongrenshengAward)
	if not pack then return end

	local var = LActor.getPlatVar(actor)
	LDataPack.writeByte(pack, var.qdrsaward or 0)
	LDataPack.flush(pack)
end

function randAward()
	local rand = math.random(100)
	local result = 0
	for idx, info in ipairs(config.awards) do
		result = result + info.rate
		if result >= rand then
			return idx
		end
	end
	return 0
end

function giveAward(npc,actorid, awardIdx)
	local actor = LActor.getActorById(actorid)
	if not actor then return end

	local conf = config.awards[awardIdx]
	if not conf then 
		print("awardIdx is error " .. awardIdx)
		return 
	end

	if Item.getBagEmptyGridCount(actor) < #conf.items then
		LActor.sendTipmsg(actor, ScriptTips.qdrs001)
		return 
	end

	local var = LActor.getPlatVar(actor)

	if var.qdrsaward then return end
	var.qdrsaward = 1

	sendAwardStatus(actor)

	abase.sendAwards(actor, conf.items, "qudongrensheng")
end

function clientDownload(actor)
	if System.isBattleSrv() then return end

	local var = LActor.getPlatVar(actor)

	var.qdrsdownload = 1

	sendDownloadStatus(actor)
end

function clientAward(actor)
	if System.isBattleSrv() then return end

	local var = LActor.getPlatVar(actor)

	if not var.qdrsdownload then
		LActor.sendTipmsg(actor, ScriptTips.qdrs002) 
		return 
	end

	if var.qdrsaward then
		LActor.sendTipmsg(actor, ScriptTips.qdrs003)
		return
	end

	if Item.getBagEmptyGridCount(actor) < 1 then
		LActor.sendTipmsg(actor, ScriptTips.qdrs001)
		return 
	end

	local awardIdx = randAward()
	local pack = LDataPack.allocPacket(actor, systemId, protocol.sQudongrenshengAwardIdx)
	if not pack then return end

	LDataPack.writeByte(pack, awardIdx)
	LDataPack.flush(pack)

	postscripttimer.postOnceScriptEvent(nil, config.delay*3000, function(...) giveAward(...) end, LActor.getActorId(actor), awardIdx)
end

function onLogin(actor)
	sendDownloadStatus(actor)
	sendAwardStatus(actor)
end

netmsgdispatcher.reg(systemId, protocol.cQudongrenshengDownload, clientDownload)
netmsgdispatcher.reg(systemId, protocol.cQudongrenshengAward, clientAward)

actorevent.reg(aeUserLogin, onLogin, true)
