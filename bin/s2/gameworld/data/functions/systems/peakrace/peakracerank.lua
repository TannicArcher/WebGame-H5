--巅峰赛季点赞排行榜(游戏服and跨服)
module("peakracerank", package.seeall)
--排行榜的常量定义
local rankingListName = "PeakRaceRank"
local rankingListFile = "PeakRaceRank.rank"
local rankingListMaxSize = 100
local rankingListBoardSize = 100
local rankingListColumns = { "sid", "name"}

--初始化排行榜
local function initRankingList()
	local rank = Ranking.getRanking(rankingListName)
	if rank  == nil then
		rank = Ranking.add(rankingListName, rankingListMaxSize)
		if rank == nil then
			print("peakracerank.initRankingList can not add rank:"..rankingListName)
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
end

--保存排行榜
local function releaseRankingList()
	local rank = Ranking.getRanking(rankingListName)
	Ranking.save(rank, rankingListFile)
	Ranking.release(rank)
end

--清空排行榜
function resetRankingList()
	print("peakracerank.resetRankingList start")
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	Ranking.clearRanking(rank)
	Ranking.save(rank, rankingListFile)
	print("peakracerank.resetRankingList ok")
end

--添加一个数据到排行
function addToRank(aid, name, sid)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	local item = Ranking.getItemPtrFromId(rank, aid)
	if not item then
		item = Ranking.tryAddItem(rank, aid, 0)
		if item == nil then return end
		--创建一个数据
		Ranking.setSub(item, 0, sid)
		Ranking.setSub(item, 1, name)
	end
end

--请求排行榜数据
function reqRankData(npack)
	local rank = Ranking.getRanking(rankingListName)
	if rank then
		local rcount = Ranking.getRankItemCount(rank)
		print("peakracerank.reqRankData rcount:"..rcount)
		LDataPack.writeShort(npack, rcount)
		for r=0,rcount-1 do
			local item = Ranking.getItemFromIndex(rank, r)
			LDataPack.writeInt(npack, Ranking.getId(item))
			LDataPack.writeString(npack, Ranking.getSub(item, 1))
			LDataPack.writeInt(npack, tonumber(Ranking.getSub(item, 0)))
			LDataPack.writeInt(npack, Ranking.getPoint(item))
		end
	else
		LDataPack.writeShort(npack, 0)
	end
end

--发放排名邮件奖励{rk:排名,mid:邮件id}
function sendRankMailReward(rk, mid)
	print("peakracerank.sendRankMailReward rk:"..rk..", mid:"..mid)
	local rank = Ranking.getRanking(rankingListName)
	if not rank then return false end
	local item = Ranking.getItemFromIndex(rank, rk-1)
	if not item then return false end
	local actorid = Ranking.getId(item)
	local sid = tonumber(Ranking.getSub(item, 0))
	if actorid and sid then
		print("peakracerank.sendRankMailReward rk:"..rk..", mid:"..mid..",to aid:"..actorid..",sid:"..sid)
		mailcommon.sendMailById(actorid, mid, sid)
	end
	return true
end

--更新排行榜点赞数
function updatePoint(aid)
	--获取排行榜
	local rank = Ranking.getRanking(rankingListName)
	if not rank then
		print("peakracerank.reqLike rank is nil")
		return false
	end
	--获取这个人有没上榜
	local item = Ranking.getItemPtrFromId(rank, aid)
	if not item then
		print("peakracerank.reqLike item is nil,aid:"..aid)
		return false
	end
	Ranking.updateItem(rank, aid, 1)
	return true
end

engineevent.regGameStartEvent(initRankingList)
engineevent.regGameStopEvent(releaseRankingList)