--跨服竞技场排行
module("crossarenarank", package.seeall)


---------------------------跨服------------------------------
local rankingListName = "crossarenarank"
local rankingListFile = "crossarenarank.rank"
local rankingListMaxSize = 1000
local rankingListBoardSize = 200
local rankingListColumns = {"vipLevel", "name", "power", "metal", "sId"}

--更新排行榜信息到游戏服
local function updateRankDataToComServer()
	local rank = Ranking.getRanking(rankingListName)
	if not rank then return end

	local rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize)
	if rankTbl == nil then rankTbl = {} end

	local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, CrossSrvCmd.SCCross3vs3)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCCross3vs3_UpdateRank)
	
	local rankCount = #rankTbl
	LDataPack.writeInt(pack, rankCount)
	for i = 1, rankCount do
		local prank = rankTbl[i]
		LDataPack.writeData(pack, 7,
				dtShort, i,
				dtInt, Ranking.getId(prank),
				dtInt, Ranking.getPoint(prank),
				dtInt, Ranking.getSub(prank, 0),
				dtString, Ranking.getSub(prank, 1),
				dtInt, Ranking.getSub(prank, 2),
				dtInt, Ranking.getSub(prank, 3),
				dtInt, Ranking.getSub(prank, 4))
	end

	System.sendPacketToAllGameClient(pack, 0)
end

--初始化
function initRankingList()
    local rank = Ranking.getRanking(rankingListName)
    if rank  == nil then
        rank = Ranking.add(rankingListName, rankingListMaxSize)
        if rank == nil then
            print("can not add rank:"..rankingListName)
            return
        end
        if Ranking.load(rank, rankingListFile) == false then
            -- 创建排行榜
            for i=1, #rankingListColumns do
                Ranking.addColumn(rank, rankingListColumns[i])
            end
        end
    end

    local col = Ranking.getColumnCount(rank)
    for i = col+1, #rankingListColumns do
        Ranking.addColumn(rank, rankingListColumns[i])
    end
    Ranking.save(rank, rankingListFile)

    Ranking.addRef(rank)

	updateRankDataToComServer()
end

--更新排行榜
function updateRankingList(actorId, name, vipLevel, power, metal, sId, score)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end

	local item = Ranking.getItemPtrFromId(rank, actorId)
	if item ~= nil then
		local p = Ranking.getPoint(item)
		if p < score then
			Ranking.setItem(rank, actorId, score)
		end
	else
		item = Ranking.tryAddItem(rank, actorId, score)
		if item == nil then return end
		--创建榜单
		Ranking.setSubInt(item, 0, vipLevel)
		Ranking.setSub(item, 1, name)
		Ranking.setSub(item, 2, power)
		Ranking.setSub(item, 3, metal)
		Ranking.setSub(item, 4, sId)
		-- Ranking.setSubInt(item, 3, LActor.getMonthCard(actor))
	end

	-- updateDynamicFirstCache(LActor.getActorId(actor))
end

--每个月重置排行榜
_G.ResetCrossArenaRankingList = function()
	if System.isCommSrv() then return end

	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end

	--发奖励
	local rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize)
	if rankTbl == nil then rankTbl = {} end

	local idx = 1
	for _, v in ipairs(CrossArenaBase.rankAward) do
		for i = idx, v.rankIdx do
			local prank = rankTbl[i]
			if prank then
				local aid = Ranking.getId(prank)
				local sId = tonumber(Ranking.getSub(prank, 3))
				print("crossarenarank send rank mail "..aid.." "..sId)
				mailsystem.sendMailById(aid, v.mail, sId)
			else
				break
			end
		end
		idx = v.rankIdx + 1
	end

	Ranking.clearRanking(rank)
end

function releaseRankingList()
	local rank = Ranking.getRanking(rankingListName)
	Ranking.save(rank, rankingListFile)
	Ranking.release(rank)
end

if not System.isCommSrv() then
	engineevent.regGameStartEvent(initRankingList)
	engineevent.regGameStopEvent(releaseRankingList)
end



---------------------------本服------------------------------
--[[
	CrossArenaRankData [排名] = {score 分数, sId, actorId, name, vipLevel, power}
--]]
CrossArenaRankData = CrossArenaRankData or {}

local function getRankData()
	return CrossArenaRankData
end

--收到跨服排行榜返回的数据
local function recvDataFromBattle(sId, sType, dp)
	local data = getRankData()
	if not data then return end

	local count = LDataPack.readInt(dp)
	for i = 1, count do
		data[i] = {
			actorId = LDataPack.readInt(pack),
			score = LDataPack.readInt(pack),
			vipLevel = LDataPack.readInt(pack),
			name = LDataPack.readString(pack),
			power = LDataPack.readInt(pack),
			metal = LDataPack.readInt(pack),
			sId = LDataPack.readInt(pack)
		}
	end
end

local function sendRankData(actor)
	local data = getRankData()
	if not data then data = {} end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_SendRankInfo)
	if not pack then return end

	local actorId = LActor.getActorId(actor)
	local myPos = 0
	LDataPack.writeInt(pack, #data)
	for k, v in ipairs(data) do
		LDataPack.writeInt(pack, k)
		LDataPack.writeInt(pack, v.actorId)
		LDataPack.writeInt(pack, v.score)
		LDataPack.writeInt(pack, v.vipLevel)
		LDataPack.writeString(pack, v.name)
		LDataPack.writeInt(pack, v.metal)
		LDataPack.writeInt(pack, v.sId)
		if v.actorId == actorId then
			myPos = k
		end
	end
	LDataPack.writeInt(pack, myPos)

	LDataPack.flush(pack)
end




if System.isCommSrv() then
	csmsgdispatcher.Reg(CrossSrvCmd.SCCross3vs3, CrossSrvSubCmd.SCCross3vs3_UpdateRank, recvDataFromBattle)
	netmsgdispatcher.reg(Protocol.CMD_Cross3Vs3, Protocol.cCross3Vs3_GetRankInfo, sendRankData)
end

local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.corssr = function(actor, args)
	local tmp = tonumber(args[1])
	if tmp == 1 then
		local data = getRankData()
		if not data then return end

		data[1] = {
			actorId = 16,
			score = 1000,
			vipLevel = 1,
			name = "荣耀暗黑",
			power = 2500000,
			metal = 1,
			sId = 16
		}
		data[2] = {
			actorId = 65552,
			score = 1000,
			vipLevel = 1,
			name = "阳光刀剑",
			power = 2500000,
			metal = 1,
			sId = 16
		}
		data[3] = {
			actorId = 131088,
			score = 1000,
			vipLevel = 1,
			name = "演绎格格",
			power = 2500000,
			metal = 1,
			sId = 16
		}
		data[4] = {
			actorId = 196624,
			score = 1000,
			vipLevel = 1,
			name = "流水梦幻",
			power = 2500000,
			metal = 1,
			sId = 16
		}

		sendRankData(actor)
	end
end



