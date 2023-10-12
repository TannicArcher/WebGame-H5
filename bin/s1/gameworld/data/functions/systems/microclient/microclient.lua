--微端福利
module("systems.microclient.microclient", package.seeall)
setfenv(1, systems.microclient.microclient)

require("protocol")
require("microclient.microclientconf")

local actorevent = require("actorevent.actorevent")
local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local questsys = require("systems.questsystem.questsystem")

require("quest.customquestconf")
local MicroClientQueset = MicroClientQueset

local ScriptTips  = Lang.ScriptTips
local System = System
local miscsSystem = SystemId.miscsSystem
local MiscsSystemProtocol = MiscsSystemProtocol

local function getSysVar( actor )
	local var = LActor.getSysVar(actor)
	if var.microclient == nil then
		var.microclient = {}
	end

	return var.microclient
end

local function checkMcSub( actor, idx )
	local dynaVar = LActor.getDyanmicVar(actor)
	local info = dynaVar.microclientinfo or 0 

	return System.bitOPMask(info, idx - 1)
end

local function sendStatus( actor )
	local var = getSysVar(actor)
	local record = var.dayAward or 0
	local down = var.downAward or 0
	
	local pack = LDataPack.allocPacket(actor, miscsSystem, MiscsSystemProtocol.sSendMicroClientStaus)
	if not pack then return end

	LDataPack.writeInt(pack, record)
	LDataPack.writeByte(pack, down)
	LDataPack.flush(pack)
end

local function getDayAward( actor, pack )
	local idx = LDataPack.readByte(pack)

	if idx <= 0 or idx > #MicroClientConf.awards then 
		print("client send idx error:", idx)
		return
	end

	if LActor.getRealLevel(actor) < MicroClientConf.showLvl then
		LActor.sendTipmsg(actor, ScriptTips.mc001)
		return
	end

	local var = getSysVar(actor)
	local record = var.dayAward or 0

	if System.bitOPMask(record, idx - 1) then
		LActor.sendTipmsg(actor, ScriptTips.mc002)
		return
	end


	--if not checkMcSub(actor, 1) then
	--	LActor.sendTipmsg(actor, ScriptTips.mc003)
	--	return
	--end

	--if not checkMcSub(actor, idx) then
	--	return
	--end

	local conf = MicroClientConf.awards[idx]
	if not conf then return end

	if Item.getBagEmptyGridCount(actor) < conf.needBagCnt then
		LActor.sendTipmsg(actor, ScriptTips.mc004)
		return
	end

	var.dayAward = System.bitOpSetMask(record, idx - 1, true)

	for i, item in ipairs(conf.items) do
		LActor.addItem(actor, item.param, item.quality, item.strong, item.num, item.bind, "microclient_dayaward", 217)
	end

	sendStatus(actor)
end

--获取下载奖励
local function getDownAward( actor )
	--if not checkMcSub(actor, 1) then
	--	LActor.sendTipmsg(actor, ScriptTips.mc003)
	--	return
	--end

	local var = getSysVar(actor)
	local down = var.downAward or 0

	if down ~= 0 then
		LActor.sendTipmsg(actor, ScriptTips.mc005)
		return
	end

	local conf = MicroClientConf.downloadAward
	if Item.getBagEmptyGridCount(actor) < conf.needBagCnt then
		LActor.sendTipmsg(actor, ScriptTips.mc004)
		return
	end

	var.downAward = 1
	for i, item in ipairs(conf.items) do
		LActor.addItem(actor, item.param, item.quality, item.strong, item.num, item.bind, "microclient_download_award", 218)
	end

	sendStatus(actor)

	LActor.sendTipmsg(actor, ScriptTips.mc006)
end

local function onNewDay(actor)
	local var = getSysVar(actor)
	var.dayAward = nil

	sendStatus(actor)
end

local function onLogin(actor )
	sendStatus(actor)
end

local function getMicroClientInfo( actor, pack )
	local idx = LDataPack.readByte(pack)
	local sta = LDataPack.readByte(pack)

	if idx <= 0 or idx > #MicroClientConf.awards then return end
	if sta ~= 1 then sta = 0 end

	local dynaVar = LActor.getDyanmicVar(actor)
	local info = dynaVar.microclientinfo or 0 

	dynaVar.microclientinfo = System.bitOpSetMask(info, idx - 1, sta == 1)
end

--微端登陆，完成任务
local function isMicroClient(actor, pack)
	local tmp = LDataPack.readByte(pack)

	if tmp == 1 then
		if LActor.hasQuest(actor, MicroClientQueset.qid) then
			LActor.addQuestValue(actor, MicroClientQueset.qid, MicroClientQueset.tid, MicroClientQueset.count)
		else
			local dynaVar = LActor.getDyanmicVar(actor)
			dynaVar.microClientLogin = 1
		end
	end
end
function checkClientQuest(actor)
	if not actor then return end

	local dynaVar = LActor.getDyanmicVar(actor)
	if not dynaVar or not dynaVar.microClientLogin then return end

	LActor.addQuestValue(actor, MicroClientQueset.qid, MicroClientQueset.tid, MicroClientQueset.count)
end
function initCheckClientQuest()
	questsys.regAcceptQuest(MicroClientQueset.qid, checkClientQuest)
end
table.insert(InitFnTable, initCheckClientQuest)

actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(miscsSystem, MiscsSystemProtocol.cGetMicroClientAward, getDayAward)
netmsgdispatcher.reg(miscsSystem, MiscsSystemProtocol.cGetMcDownLoadAward, getDownAward)
netmsgdispatcher.reg(miscsSystem, MiscsSystemProtocol.cMicroClientInfo, getMicroClientInfo)
netmsgdispatcher.reg(miscsSystem, MiscsSystemProtocol.cIsMicroClient, isMicroClient)
