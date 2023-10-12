--排行榜相关函数
module("rankfunc", package.seeall)

-- 初始化排行榜
function initRank(rankName, rankFile, maxNum, coloumns, initSave)
	local rank = Ranking.getRanking(rankName)
	if rank == nil then
		rank = Ranking.add(rankName, maxNum, 0)
		if rank == nil then
			print("can not add rank:"..rankName..","..rankFile)
			return 
		end
		if Ranking.load(rank, rankFile) == false and coloumns then
			-- 创建排行榜
			for i=1, #coloumns do
				Ranking.addColumn( rank, coloumns[i] )
			end
		end
	end

	if coloumns then 
		local col = Ranking.getColumnCount(rank)
		for i=col+1,#coloumns do
			Ranking.addColumn(rank, coloumns[i])
		end
	end
	Ranking.addRef(rank)

	if initSave then
		Ranking.save(rank, rankFile)
	end

	return rank
end

function getRankIndex(rankItem)
	if not rankItem then return -1 end
	return Ranking.getIndexFromPtr(rankItem) + 1
end

function updateRank(rank, id, point, ...)
	if not rank then return nil end
	-- local idx = Ranking.getItemIndexFromId(rank, id)
	local item = Ranking.getItemPtrFromId(rank, id)
	if item then
		item = Ranking.updateItem(rank, id, point)
	else
		item = Ranking.addItem(rank, id, point)
	end

	for i,v in ipairs(arg) do
		Ranking.setSub(item, i-1, v)
	end

	return item
end

function setRank(rank, id, point, ...)
	if not rank then return nil end
	-- local idx = Ranking.getItemIndexFromId(rank, id)
	local item = Ranking.getItemPtrFromId(rank, id)
	if item then
		-- item = Ranking.updateItem(rank, id, point)
		Ranking.setItem(rank, id, point)
	else
		item = Ranking.addItem(rank, id, point)
	end

	for i,v in ipairs(arg) do
		Ranking.setSub(item, i-1, v)
	end

	return item
end

