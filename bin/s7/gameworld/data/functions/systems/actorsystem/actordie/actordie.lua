module("systems.actordie.actordie" , package.seeall)
setfenv(1, systems.actordie.actordie)

local actorevent   = require("actorevent.actorevent")
local resurrection = require("systems.miscs.resurrection")
local changemodel  = require("actorevent.changemodel")

require("protocol")
require("misc.relivecdtime")
--本脚本实现了死亡后选择复活模式的功能
local getIntProperty = LActor.getIntProperty
local protocol = defaultSystemProtocol
local systemId = SystemId.enDefaultEntitySystemID

local ReliveCdConf      = ReliveCdConf
local ResurrectTimeConf = ResurrectTimeConf
local ReLiveAttConf     = ReLiveAttConf
local SafeHpConf        = SafeHpConf
local RESURRECTTIME     = ReLiveAttConf.resurrecttime --复活超时
local DEF_RELIVE_CD     = ReLiveAttConf.reliveCdTime --复活CD

local RESURRECT_INDX, TOTAL_RELIVE_INDX = 1, 2

local actorDieInFubn = {}
local actorDieInScene = {}
local inFuben = 0
local inScene = 1

local reliveTime = 8

local function reg(regType, id, proc, notDefault)
	if not id then
		print("actorDie reg fubenId = nil")
		assert(false)
	end
	if not proc then
		print("actorDie reg proc = nil")
		assert(false)
	end

	id = tonumber(id)
	local procList
	if regType == inFuben then
		if not actorDieInFubn[id] then
			actorDieInFubn[id] = {}
			actorDieInFubn[id].procList = {}
		end
		if notDefault then
			actorDieInFubn[id].notDefault = true
		end
		procList = actorDieInFubn[id].procList
	elseif regType == inScene then
		if not actorDieInScene[id] then
			actorDieInScene[id] = {}
			actorDieInScene[id].procList = {}
		end
		if notDefault then
			actorDieInScene[id].notDefault = true
		end
		procList = actorDieInScene[id].procList
	else
		print("actorDie reg regType error")
		assert(false)
	end

	for _, func in ipairs(procList) do
		if func == proc then
			return false
		end
	end
	table.insert(procList, proc)
	return true
end

function regByScene(id, proc, notDefault)
	reg(inScene, id, proc, notDefault)
end

function regByFuben(id, proc, notDefault)

	reg(inFuben, id, proc, notDefault)
end

local function defaultDieFunc(actor, killer)
	local ownername = ""
	local killername = ""
	local servername = ""
	local job, sex, actorId, petId, level, campId = 0, 0, 0, 0, 0, 0

	--获取击杀者信息
	if killer then
		killername = LActor.getName(killer)

		if LActor.isPet(killer) then
			killer = LActor.getMonsterOwner(killer)
			ownername = LActor.getName(killer)
		end

		if LActor.isActor(killer) then
			actorId = LActor.getActorId(killer)
			level = getIntProperty(killer, P_LEVEL)
			sex = getIntProperty(killer, P_SEX)
			job = getIntProperty(killer, P_VOCATION)
			servername = WarFun.getServerName(LActor.getServerId(killer))
			campId = LActor.getCampId(killer)
		end
	end

	if not LActor.hasMapAreaAttri(actor, aaNotRelive) then
		--设置复活超时
		local sceneId = LActor.getSceneId(actor)

		local conf = ResurrectTimeConf[sceneId]
		LActor.setReliveTimeOut(actor, conf and conf[TOTAL_RELIVE_INDX] or RESURRECTTIME)
		--立即复活cd时间(需等待reliveCd秒,才能原地复活)

		local reliveCd = ReliveCdConf[sceneId] or DEF_RELIVE_CD
		local time_now = System.getNowTime()
		local var = LActor.getStaticVar(actor)

		--安全复活也带上CD
		var.canReliveTime = time_now + reliveCd
		var.canResurrectTime = time_now + (conf and conf[RESURRECT_INDX] or 0)

		local freeCount = resurrection.getFreeCount(actor)
		local yb = resurrection.getReliveYb(actor)

		--发送复活对话框
		local pack = LDataPack.allocPacket(actor, systemId, protocol.sDieDialog)
		if not pack then return end
		LDataPack.writeData(pack, 14,
			dtInt, RESURRECTTIME,
			dtInt, actorId,
			dtInt, petId,
			dtInt, level,
			dtInt, sex,
			dtInt, job,
			dtString, killername,
			dtString, ownername,
			dtInt, reliveCd,
			dtChar, freeCount or 0,
			dtChar, (conf and conf[RESURRECT_INDX] or 0),
			dtInt, yb or 0,
			dtString, servername,
			dtChar, campId)
		LDataPack.flush(pack)
	end
end

local function onEvent(tbl, id, ...)
	local callTbl = tbl[id]
	if callTbl == nil then
		return false
	end
	if not callTbl.notDefault then
		defaultDieFunc(...)
	end

	for _, func in ipairs(callTbl.procList) do
		func(...)
	end
	return true
end

--回城复活
function safeResurrection(actor)
	if getIntProperty(actor,P_HP) == 0 then
		local maxhp = getIntProperty(actor,P_MAXHP)
		local sceneId = LActor.getSceneId(actor)
		local safeHp = SafeHpConf[sceneId] or ReLiveAttConf.safeHp
		LActor.changeHp(actor, math.ceil(maxhp * safeHp))

		LActor.relive(actor)
		--复活保护
		LActor.addBuff(actor,GlobalConfig.reliveBuffId, nil, reliveTime)

		LActor.clearReliveTimeOut(actor)
	end
end

--注意killer不一定存在
function onActorDieEvent(actor, killer)
	--判定状态：如果是换血状态的话则不再触发下面的逻辑
	if LActor.hasActorState(actor, esUsingOtherHp) then
		-- LActor.addBuff(actor, RELIVE_BUFF)
		changemodel.removeOtherHp(actor)
		changemodel.onUsingOtherHpOver(actor, killer)
		return
	end

	-- 收回宠物
	LActor.petCallBack(actor, true)

	local fubenId = LActor.getFubenId(actor)
	if fubenId > 0 then
		if onEvent(actorDieInFubn, fubenId, actor, killer) then return end
	end

	local sceneId = LActor.getSceneId(actor)
	if onEvent(actorDieInScene, sceneId, actor, killer) then return end

	defaultDieFunc(actor, killer, sceneId)
end

_G.onActorDieEvent = onActorDieEvent

actorevent.reg(aeReliveTimeOut, safeResurrection)

