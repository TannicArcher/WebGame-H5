-- 消费排行榜
module("consumeybrank", package.seeall)

--排行榜的常量定义
local rankingListName = "ConsumeYBrank"
local rankingListFile = "ConsumeYBrank.rank"
local rankingListMaxSize = 2000
local rankingListBoardSize = 20
local rankingListColumns = { "name" }

--[[更新第一名玩家的数据到C++排行榜缓存里,暂时无用
local function updateDynamicFirstCache(actor_id)
    local rank = Ranking.getRanking(rankingListName)
    local rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
    if rankTbl == nil then
        rankTbl = {}
    end
    if #rankTbl ~= 0 then
        local prank = rankTbl[1]
        if actor_id == nil or actor_id == Ranking.getId(prank) then
            morship.updateDynamicFirstCache(Ranking.getId(prank), RankingType_ConsumeYB)
        end
    end
end
]]

--初始化排行榜
local function initRankingList()
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
    for i=col+1,#rankingListColumns do
        Ranking.addColumn(rank, rankingListColumns[i])
    end

    Ranking.save(rank, rankingListFile)
    Ranking.addRef(rank)
    --updateDynamicFirstCache()
end

--保存排行榜
local function releaseRankingList()
    local rank = Ranking.getRanking(rankingListName)
    Ranking.save(rank, rankingListFile)
    Ranking.release(rank)
end

--获取玩家排名
function getrank(actor)
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return 0 end

    return Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1
end

--清空排行榜
function resetRankingList()
    print("start to resetRankingList")
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return end
    Ranking.clearRanking(rank)
    print("end to resetRankingList")
end

--更新排行榜数据
function updateRankingList(actor, value)
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return end
    local actorId = LActor.getActorId(actor)
    local item = Ranking.getItemPtrFromId(rank, actorId)
    if item ~= nil then
        local p = Ranking.getPoint(item)
        -- if p < value then
            Ranking.setItem(rank, actorId, value)
        -- end
    else
        --只增不降的用tryAddItem
        --会降的用addItem
        item = Ranking.tryAddItem(rank, actorId, value)
        if item == nil then return end
        -- 创建榜单
        Ranking.setSub(item, 0, LActor.getName(actor))
    end
    --updateDynamicFirstCache(actorId)
end

function sendDaBiaoData(npack, actor, id, rankType, conf, index)
    local record = activitysystem.getSubVar(actor, id)
    local useyuanbao = record.data.useyuanbao or 0
    LDataPack.writeInt(npack, useyuanbao)

    local myIdx = 0
    local rank = Ranking.getRanking(rankingListName)
    local rankTbl = nil
    if rank then
        rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize)

        myIdx = Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1
    end

    LDataPack.writeInt(npack, myIdx)
    if rankTbl == nil then rankTbl = {} end
    LDataPack.writeShort(npack, #rankTbl)
    for i = 1, #rankTbl do
        local prank = rankTbl[i]
        LDataPack.writeData(npack, 4,
            dtShort, i,							--rank
            dtInt, Ranking.getId(prank), 		--actorid
            dtString, Ranking.getSub(prank, 0), --name
            dtInt, Ranking.getPoint(prank)      --useyuanbao
        )
    end
end

function sendRankingReward(id, rankType, conf)
    local rank = Ranking.getRanking(rankingListName)
    local rankTbl = nil
    if rank then
        rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize)
    end
    if rankTbl == nil then rankTbl = {} end
	print("start send dabiao mail rankType:"..rankType)
    local ranking_conf = conf
	local ii = 1
    for i, v in ipairs(ranking_conf) do
        local prank = rankTbl[ii]
		if not prank then break end
		local p = Ranking.getPoint(prank)
        if p >= v.value then
            local actorid = Ranking.getId(prank)
            local mail_data = {}
            mail_data.head = v.head
            mail_data.context = string.format(v.context, i)
            mail_data.tAwardList = v.rewards
            mailsystem.sendMailById(actorid, mail_data)
			print(id .. ":" .. ii .. ":" .. i .. " send dabiao ranking mail " .. actorid)
			--公告广播
			if v.notice then
				noticemanager.broadCastNotice(v.notice, Ranking.getSub(prank, 0))
			end
			ii = ii + 1
        end
    end
	--一个活动结束后清空排行榜
	resetRankingList()
end

--监听充值数据,如果以后消费排行榜活动需要多开,这里要改为不同的活动使用不同的榜
local function onuseyuanbao(id, conf)
	return function(actor, value)
		if activitysystem.activityTimeIsEnd(id) then return end
		local record = activitysystem.getSubVar(actor, id)
		record.data.useyuanbao = (record.data.useyuanbao or 0) + value
		updateRankingList(actor, record.data.useyuanbao)
	end
end

--由对应的活动调用初始化,目前只有类型4用到了
function init(id, conf)
	if conf[0].rankType == RankingType_ConsumeYB then
		actorevent.reg(aeConsumeYuanbao, onuseyuanbao(id, conf))
	end
end

engineevent.regGameStartEvent(initRankingList)
engineevent.regGameStopEvent(releaseRankingList)
