module("guildbattleintegralrank", package.seeall)
--需要改
local rankingListName      = "guildbattleintegralrank"
local rankingListFile      = "guildbattleintegralrank.rank"
local rankingListMaxSize   = GuildBattleConst.integralRaningMaxSize
local rankingListBoardSize = GuildBattleConst.integralRaningMaxSize
local rankingListColumns   = {"name","guild_name","integral"}




--不需要改
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
end

local function showRank()
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return end
    local  rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
    if rankTbl == nil then rankTbl = {} end
	if rankTbl and #rankTbl > 0 then
		for i = 1, #rankTbl do
			local prank = rankTbl[i]
			print(i .. " " .. Ranking.getId(prank) .. "--" .. Ranking.getPoint(prank) .. "--" .. Ranking.getSub(prank,0) .. "--" .. Ranking.getSub(prank,1))
		end
	end
end


--需要改
function updateRankingList(actor,integral)
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return end
    local actorId = LActor.getActorId(actor)
    local item = Ranking.getItemPtrFromId(rank, actorId)
    if item ~= nil then
		local p = Ranking.getPoint(item)
		Ranking.setItem(rank, actorId, integral)
	else
        item = Ranking.addItem(rank, actorId, integral)
        if item == nil then return end
        --创建榜单
    end
    Ranking.setSub(item, 0, LActor.getName(actor))
	local guild_id   = LActor.getGuildId(actor)
	local guild_name = LGuild.getGuildName(LGuild.getGuildById(guild_id))
	Ranking.setSub(item, 1, guild_name)
	Ranking.setSub(item, 2, integral)
--	showRank()
end

--不需要改
function getrank(actor)
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return 0 end

    return Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1
end

--需要改
function notifyRankingList(actor)
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return end
    local  rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_IntegralRanking)
    if npack == nil then return end
	if rankTbl == nil then rankTbl = {} end
	LDataPack.writeInt(npack,#rankTbl)
	for i = 1, #rankTbl do
		local prank = rankTbl[i]
		LDataPack.writeString(npack,Ranking.getSub(prank,0))
		LDataPack.writeString(npack,Ranking.getSub(prank,1))
		LDataPack.writeInt(npack,Ranking.getSub(prank,2))
	end
	LDataPack.flush(npack)
end

--不需要改
function onReqRanking(actor)
    notifyRankingList(actor)
end

--需要改
function resetRankingList()
    -- System.log("guildbattleintegralrank", "resetRankingList", "call", rankingListName)
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return end

    _G.rank_backup(rank)
    Ranking.clearRanking(rank)
end

--不需要改
function releaseRankingList()
    local rank = Ranking.getRanking(rankingListName)
    Ranking.save(rank, rankingListFile)
    Ranking.release(rank)
end

function sendPersonalRankAward(leader_id)
    -- System.log("guildbattleintegralrank", "sendPersonalRankAward", "call")
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	local  rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
	if rankTbl == nil then rankTbl = {} end
    --print("guildbattleintegralrank.sendPersonalRankAward,rank_size:"..(#rankTbl))

    local hefuNormalAward
    local hefuIdx = guildbattle.getHefuActivityIdx()
    if hefuIdx and GuildBattleConst.hefuAward.normal.award[hefuIdx] then
        hefuNormalAward = {}
        local normalConf = GuildBattleConst.hefuAward.normal
        hefuNormalAward.head       = normalConf.title
        hefuNormalAward.context    = normalConf.context
        hefuNormalAward.tAwardList = normalConf.award[hefuIdx]
    end

	for i = 1, #rankTbl do
		local prank    = rankTbl[i]
		local actor_id = Ranking.getId(prank)
		local conf     = GuildBattlePersonalRankAward[i]
		if conf ~= nil then 
			local mail_data = {}
			mail_data.head = GuildBattleConst.personalRankAwardHead
			mail_data.context = string.format(GuildBattleConst.personalRankAwardContext,i)
			mail_data.tAwardList = conf.award
            print(actor_id.." guildbattleintegralrank.sendPersonalRankAward,sendMail")
			mailsystem.sendMailById(actor_id,mail_data)
		end

        if hefuNormalAward and leader_id ~= actor_id then
            mailsystem.sendMailById(actor_id, hefuNormalAward)
        end
	end
end

function getRank(actor)
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return 0 end
    return Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1
end








--table.insert(InitFnTable, initRankingList)
--table.insert(FinaFnTable, releaseRankingList)
 
engineevent.regGameStartEvent(initRankingList)
engineevent.regGameStopEvent(releaseRankingList)
--engineevent.regNewDay(refreshWeek)

local function onIntegralRanking(actor,pack)
	notifyRankingList(actor)
end

netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_IntegralRanking, onIntegralRanking)


