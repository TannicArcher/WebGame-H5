--[[
	author = 'Roson'
	time   = 06.01.2015
	name   = 连服排行榜
	ver    = 0.1
]]

module("systems.lianfu.lianfurankinghelper", package.seeall)
setfenv(1, systems.lianfu.lianfurankinghelper)

local lianfumanager    = require("systems.lianfu.lianfumanager")
local lianfuutils      = require("systems.lianfu.lianfuutils")

require("protocol")
local LianfuRankCmd = LianfuRankCmd

LianfuRankConf = nil
RANK_TYPE = nil
require("lianfu.lianfurankconf")
LianfuRankConf = LianfuRankConf
RANK_TYPE = LianfuRankConf.RANK_TYPE

local getRankTab = {}

local attList =
{
	P_ALL_ATTACK,
	P_OUT_DEFENCE,
	P_IN_DEFENCE,
	P_MAXHP,
	P_CRITICALSTRIKES,
	P_DEFCRITICALSTRIKES,
	P_HITRATE,
	P_DODGERATE,
	P_IN_ATTACK,
	P_OUT_ATTACK,
}

function regGetRankingUserDataEvent(eventId, proc)
	if getRankTab[eventId] then return end
	getRankTab[eventId] = proc
end

function getRankingUserData(eventId, indx)
	local ret = Ranking.getLianfuRankData(indx - 1)
	if not ret then return end

	local actorId = ret.actorid
	local srvId   = ret.server
	if not actorId or actorId == 0 then return end

	local pk = LDataPack.allocLianFuPacket(LianfuRankCmd.mGetRankData)
	if not pk then return end

	LDataPack.writeData(pk, 2,
		dtInt, eventId,
		dtInt, actorId)

	LianfuFun.sendServerPacket(srvId, pk)
end

function recieveGetRankingUserData(pack)
	local lianfuSid = LianfuFun.getLianfuSid()
	if lianfuSid <= 0 then return end

	local eventId, actorId = LDataPack.readData(pack, 2, dtInt, dtInt)
	local actIndx = Ranking.getActorIndexById(actorId, 1)

	local data = Ranking.getRankingUserData(1, actIndx)
	if not data then return end

	local pk = LDataPack.allocLianFuPacket(LianfuRankCmd.mReSendRankData)
	if not pk then return end

	LDataPack.writeData(pk, 4,
		dtInt, eventId,
		dtInt, System.getServerId(),
		dtInt, actorId,
		dtInt, actIndx)

	local ret = {}
	local insert = table.insert
	for _,attId in ipairs(attList) do
		if data[attId] then
			insert(ret, dtInt)
			insert(ret, attId)
			insert(ret, dtInt)
			insert(ret, data[attId])
		end
	end

	LDataPack.writeData(pk, 1,
		dtChar, #ret / 4)

	LDataPack.writeData(pk, #ret / 2, unpack(ret))

	LianfuFun.sendServerPacket(lianfuSid, pk)
end

function onRecieveGetRankingUserData(pack)
	local eventId, srvId, actorId, actIndx = LDataPack.readData(pack, 4, dtInt, dtInt, dtInt, dtInt)
	local data = {}
	local count = LDataPack.readChar(pack)
	for i=1,count do
		local attId, val = LDataPack.readData(pack, 2, dtInt, dtInt)
		data[attId] = val
	end

	if not getRankTab[eventId] then return end
	getRankTab[eventId](srvId, actorId, actIndx + 1, data)
end

function getSelfAtts(actor)
	local data = {}
	local getIntProperty = LActor.getIntProperty
	for _,v in pairs(attList) do
		local val = getIntProperty(actor, v)
		data[v] = val
	end

	return data
end


lianfumanager.regCmd(LianfuRankCmd.mGetRankData, recieveGetRankingUserData)
lianfumanager.regCmd(LianfuRankCmd.mReSendRankData, onRecieveGetRankingUserData)


