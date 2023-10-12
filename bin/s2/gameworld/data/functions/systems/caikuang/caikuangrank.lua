-- 采矿排行榜
module("caikuangrank", package.seeall)

-- 需要改
local rankingListName = "caikuangrank"
local rankingListFile = "caikuangrank.rank"
local rankingListMaxSize = 2000
local rankingListBoardSize = 2000
local rankingListColumns = {}
local rankListType = RankingType_CaiKuang  -- todo
local needUpdateFirst = false


-- 不需要改
local function updateDynamicFirstCache(actor_id)
	if not needUpdateFirst then return end

	local rank = Ranking.getRanking(rankingListName)
	local rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
	if rankTbl == nil then
		rankTbl = {}
	end
	if #rankTbl ~= 0 then
		local prank = rankTbl[1]
		if actor_id == nil or actor_id == Ranking.getId(prank) then
			morship.updateDynamicFirstCache(Ranking.getId(prank), rankListType)
		end
	end
end

-- 不需要改
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
	updateDynamicFirstCache()

	-- 需要修改
	caikuangscene.rebuildRank()
end

-- 不需要改
local function releaseRankingList()
	local rank = Ranking.getRanking(rankingListName)
	Ranking.save(rank, rankingListFile)
	Ranking.release(rank)
end

-- 不需要改
function getrank(actor)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return 0 end

	return Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1
end

-- 不需要改
function resetRankingList()
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	Ranking.clearRanking(rank)
end

-- 需要改
function updateRankingList(actor, value)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	local actorId = LActor.getActorId(actor)
	local item = Ranking.getItemPtrFromId(rank, actorId)
	if item ~= nil then
		Ranking.setItem(rank, actorId, value)
	else
		item = Ranking.addItem(rank, actorId, value)
		if item == nil then return end
		-- 创建榜单
		Ranking.setSub(item, 0, LActor.getName(actor))
	end
	updateDynamicFirstCache(actorId)
end


engineevent.regGameStartEvent(initRankingList)
engineevent.regGameStopEvent(releaseRankingList)


-- 不需要改
function getRankList()
	local rank = Ranking.getRanking(rankingListName)
	local rankTbl = nil
	if rank then
		rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize) or {}
	end
	return rankTbl
end

-- 不需要改
function getRankItemValue(rankTbl, i)
	local prank = rankTbl[i]
	if not prank then return end

	local id = Ranking.getId(prank)
	local point = Ranking.getPoint(prank)
	local cols = {}
	for i, colname in ipairs(rankingListColumns) do
		cols[colname] = Ranking.getSub(prank, i-1)
	end

	return id, point, cols
end

-- 不需要改
function updateRankId(id, point, cols)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	local actorId = id
	local item = Ranking.getItemPtrFromId(rank, actorId)
	if item ~= nil then
		Ranking.setItem(rank, actorId, point)
	else
		item = Ranking.addItem(rank, actorId, point)
		if item == nil then return end
	end
	
	-- 更新榜单
	for i, colname in ipairs(rankingListColumns) do
		if cols[colname] then
			Ranking.setSub(item, i-1, cols[colname])
		end
	end

	updateDynamicFirstCache(actorId)
end

function updateRank(actor, point, cols)
	local actorid = LActor.getActorId(actor)
	return updateRankId(id, point, cols)
end

-- 不需要改
function removeRankItemId(id)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	Ranking.removeId(rank, id)
end

-- 不需要改
function removeRankItem(actor)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	Ranking.removeId(rank, LActor.getActorId(actor))
end

-- 不需要改
function getRankId(id)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return 0 end

	return Ranking.getItemIndexFromId(rank, id) + 1
end

-- getRankList()
-- getRankItemValue(rankTbl, i)

-- resetRankingList()

-- updateRankId(id, point, cols)
-- updateRank(actor, point, cols)

-- removeRankItemId(id)
-- removeRankItem(actor)

-- getRankId(id)
-- getrank(actor)
