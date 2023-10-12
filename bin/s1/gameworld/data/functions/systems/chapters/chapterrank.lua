
--关卡排行榜
module("chapterrank", package.seeall)

--[[
--
--
--]]


local rankingListName = "chapterrank"
local rankingListFile = "chapterrank.rank"
local rankingListMaxSize = 1000
local rankingListBoardSize = 100
local rankingListColumns = {"name", "power", "vipLevel", "monthCard"}

local function updateDynamicFirstCache(actor_id)
    local rank = Ranking.getRanking(rankingListName)
	local  rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
	if rankTbl == nil then 
		rankTbl = {} 
	end
	if #rankTbl ~= 0 then 
		local prank = rankTbl[1]
		if actor_id == nil or actor_id == Ranking.getId(prank) then  
			morship.updateDynamicFirstCache(Ranking.getId(prank),RankingType_ChapterLevel)
		end
	end
end



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
                Ranking.addColumn( rank, rankingListColumns[i] )
            end
        end
    end

    local col = Ranking.getColumnCount(rank)
    for i=col+1,#rankingListColumns do
        Ranking.addColumn(rank, rankingListColumns[i])
    end
    Ranking.save(rank, rankingListFile)

    Ranking.addRef(rank)
	updateDynamicFirstCache()
end

function updateRankingList(actor, chapterLevel)
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return end
    local actorId = LActor.getActorId(actor)
    local item = Ranking.getItemPtrFromId(rank, actorId)
    if item ~= nil then
        local p = Ranking.getPoint(item)
        if p < chapterLevel then
            Ranking.setItem(rank, actorId, chapterLevel)
        end
    else
        item = Ranking.tryAddItem(rank, actorId, chapterLevel)
        if item == nil then return end
        --创建榜单
        Ranking.setSub(item, 0, LActor.getName(actor))
    end
    Ranking.setSub(item, 1, tostring(LActor.getActorPower(actorId)))
    Ranking.setSubInt(item, 2, LActor.getVipLevel(actor))
    Ranking.setSubInt(item, 3, LActor.getMonthCard(actor))
	updateDynamicFirstCache(LActor.getActorId(actor))
end
function getrank(actor)
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return 0 end

    return Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1
end

function notifyRankingList(actor)
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return end
    local  rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Ranking, Protocol.sRankingCmd_ResRankingData)
    if npack == nil then return end

    if rankTbl == nil then rankTbl = {} end
    LDataPack.writeShort(npack, RankingType_ChapterLevel)
    LDataPack.writeShort(npack, #rankTbl)
    print("====================")
    print(#rankTbl)
    print("====================")

    if rankTbl and #rankTbl > 0 then
        for i = 1, #rankTbl do
            local prank = rankTbl[i]
            LDataPack.writeData(npack, 7,
                dtShort, i,                 --rank
                dtInt, Ranking.getId(prank), --id
                dtString, Ranking.getSub(prank, 0),--name
                dtDouble, Ranking.getSub(prank,1), --power
                dtShort, Ranking.getSub(prank,2),--vip
                dtInt, Ranking.getPoint(prank), --chapterLevel
                dtShort, tonumber(Ranking.getSub(prank, 3)) or 0 --monthCard
            )
        end
    end
    LDataPack.writeShort(npack, Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1)
    LDataPack.flush(npack)
end

function onReqRanking(actor)
    notifyRankingList(actor)
end

function resetRankingList()
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return end
    --[[local  rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize)
    if rankTbl == nil or #rankTbl <= 0 then return end

    local configIndex = 1
    for i = 1, #rankTbl do
        local config = XXXXRankConfig[configIndex]
        while config ~= nil do
            if i <= config.maxRank then
                break
            end
            configIndex = configIndex + 1
            config = XXXXXXRankConfig[configIndex]
        end
        if config then
            local mailData = {}
            mailData.head = XXXXXBaseConfig.rankMailTitle
            mailData.context = string.format(XXXXBaseConfig.rankMailContent, Ranking.getPoint(rankTbl[i]),i)
            mailData.tAwardList = config.rewards
            mailsystem.sendMailById(Ranking.getId(rankTbl[i]), mailData)
        end
    end
    --]]
    Ranking.clearRanking(rank)
end

function releaseRankingList()
    local rank = Ranking.getRanking(rankingListName)
    Ranking.save(rank, rankingListFile)
    Ranking.release(rank)
end

--table.insert(InitFnTable, initRankingList)
--table.insert(FinaFnTable, releaseRankingList)

engineevent.regGameStartEvent(initRankingList)
engineevent.regGameStopEvent(releaseRankingList)
--engineevent.regNewDay(resetRankingList)

_G.onReqChapterLevelRanking = onReqRanking
