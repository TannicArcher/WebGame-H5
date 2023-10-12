--遭遇战排行榜
module("skirmishranking", package.seeall)

--[[
--
--
--]]

local rankingListName = "skirmishrank"
local rankingListFile = "skirmishrank.rank"
local rankingListMaxSize = SkirmishBaseConfig.rankMaxSize
local rankingListBoardSize = SkirmishBaseConfig.rankBoardSize
local rankingListColumns = {"name", "job", "sex", "level", "zsLevel", "vipLevel", "monthcard"}


local function updateDynamicFirstCache(actor_id)
    local rank = Ranking.getRanking(rankingListName)
	local  rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
	if rankTbl == nil then 
		rankTbl = {} 
	end
	if #rankTbl ~= 0 then 
		local prank = rankTbl[1]
		if actor_id == nil or actor_id == Ranking.getId(prank) then  
			morship.updateDynamicFirstCache(Ranking.getId(prank),RankingType_Skirmish)
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

function updateRankingList(actor, fame)
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return end
	local level = LActor.getLevel(actor)
	if level < RANK_MIN_LEVEL then return end
    local actorId = LActor.getActorId(actor)
    local item = Ranking.getItemPtrFromId(rank, actorId)
    if item ~= nil then
        local p = Ranking.getPoint(item)
        Ranking.setItem(rank, actorId, p + fame)
    else
        item = Ranking.tryAddItem(rank, actorId, fame)
        if item == nil then return end
        --创建榜单
        Ranking.setSub(item, 0, LActor.getName(actor))
        Ranking.setSubInt(item, 1, LActor.getJob(actor))
        Ranking.setSubInt(item, 2, LActor.getSex(actor))
    end
    Ranking.setSubInt(item, 3, level)
    Ranking.setSubInt(item, 4, LActor.getZhuanShengLevel(actor))
    Ranking.setSubInt(item, 5, LActor.getVipLevel(actor))
    Ranking.setSubInt(item, 6, LActor.getMonthCard(actor))
    
	updateDynamicFirstCache(LActor.getActorId(actor))
end

--新增后台设置声望接口
function setRankingList(actor, fame)
	local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return end
    local actorId = LActor.getActorId(actor)
    local item = Ranking.getItemPtrFromId(rank, actorId)
    if item ~= nil then
		local p = Ranking.getPoint(item)
		if p == fame then return end
        Ranking.setItem(rank, actorId, fame)
    else
        if fame > 0 then
	        item = Ranking.tryAddItem(rank, actorId, fame)
	        if item == nil then return end
	        --创建榜单
	        Ranking.setSub(item, 0, LActor.getName(actor))
	        Ranking.setSubInt(item, 1, LActor.getJob(actor))
	        Ranking.setSubInt(item, 2, LActor.getSex(actor))
        end
    end
    Ranking.setSubInt(item, 3, LActor.getLevel(actor))
    Ranking.setSubInt(item, 4, LActor.getZhuanShengLevel(actor))
    Ranking.setSubInt(item, 5, LActor.getVipLevel(actor))
    Ranking.setSubInt(item, 6, LActor.getMonthCard(actor))

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
    LDataPack.writeShort(npack, RankingType_Skirmish)
    LDataPack.writeShort(npack, #rankTbl)
    print("====================")
    print("skirmish rank size:")
    print(#rankTbl)
    print("====================")

    if rankTbl and #rankTbl > 0 then
        for i = 1, #rankTbl do
            local prank = rankTbl[i]
            LDataPack.writeData(npack, 10,
                dtShort, i,                 --rank
                dtInt, Ranking.getId(prank), --id
                dtString, Ranking.getSub(prank, 0),--name
                dtByte, Ranking.getSub(prank,1), --job
                dtByte, Ranking.getSub(prank,2),--sex
                dtShort, Ranking.getSub(prank,3), --level
                dtShort, Ranking.getSub(prank,4), --zslevel
                dtShort, Ranking.getSub(prank,5), --viplevel
                dtInt, Ranking.getPoint(prank), --fame
                dtShort, tonumber(Ranking.getSub(prank, 6)) or 0 --monthcaard
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
	print("resetRankingList on newday")
    dRankUpdateBefore(rankingListName)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	local  rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
	if rankTbl == nil or #rankTbl <= 0 then return end

    local configIndex = 1
	for i = 1, #rankTbl do
        local config = SkirmishRankConfig[configIndex]
        while config ~= nil do
            if i <= config.maxRank then
                break
            end
            configIndex = configIndex + 1
            config = SkirmishRankConfig[configIndex]
        end
        if config then
            local mailData = {}
            mailData.head = SkirmishBaseConfig.rankMailTitle
            mailData.context = string.format(SkirmishBaseConfig.rankMailContent, Ranking.getPoint(rankTbl[i]),i)
            mailData.tAwardList = config.rewards
            mailsystem.sendMailById(Ranking.getId(rankTbl[i]), mailData)
        end
	end

	Ranking.clearRanking(rank)
    dynamicRankUpdate(rankingListName)

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
engineevent.regNewDay(resetRankingList)

_G.onReqSkirmishRanking = onReqRanking
