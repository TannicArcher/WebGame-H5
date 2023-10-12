module("tiantirank", package.seeall)

local rankingListName      = "tiantirank"
local rankingListFile      = "tiantirank.rank"
local rankingListMaxSize   = TianTiConstConfig.maxRankCount
local rankingListBoardSize = TianTiConstConfig.showRankCount
local rankingListColumns   = {"name","tianti_level","tianti_id","job","sex","win_count"}



local function getData()
	local var = System.getStaticVar()
	if var == nil then 
		return nil
	end
	if var.tiantirank == nil then 
		var.tiantirank = {}
	end
	return var.tiantirank
end

local function initData()
	local var = getData()
	if var.last_week_data == nil then 
		var.last_week_data = {}
	end
	if var.last_week_data_len == nil then 
		var.last_week_data_len = 0
	end
end

local function updateDynamicFirstCache(actor_id)
    local rank = Ranking.getRanking(rankingListName)
	local  rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
	if rankTbl == nil then 
		rankTbl = {} 
	end
	if #rankTbl ~= 0 then 
		local prank = rankTbl[1]
		if actor_id == nil or actor_id == Ranking.getId(prank) then  
			morship.updateDynamicFirstCache(Ranking.getId(prank),RankingType_TianTi)
		end
	end
end



function initRankingList()
	print("tiantirank,initRankingList")
    local rank = Ranking.getRanking(rankingListName)
    if rank  == nil then
        rank = Ranking.add(rankingListName, rankingListMaxSize)
        if rank == nil then
            print("tiantirank,initRankingList,can not add rank:"..rankingListName)
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
	initData()
	updateDynamicFirstCache()
end

local function showRank()
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return end
    local  rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
    if rankTbl == nil then rankTbl = {} end
	if rankTbl and #rankTbl > 0 then
		for i = 1, #rankTbl do
			local prank = rankTbl[i]

			print(Ranking.getId(prank))
			print(Ranking.getSub(prank,0))
			print(Ranking.getSub(prank,1))
			print(Ranking.getSub(prank,2))
			print(Ranking.getPoint(prank))
		end
	end
end



function updateRankingList(actor, win_count)
	print("tiantirank,updateRankingList,actorId:"..LActor.getActorId(actor)..",win_count:"..tostring(win_count))
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then 
		print("tiantirank,updateRankingList,actorId:"..LActor.getActorId(actor)..",rank is nil")
		return 
	end
    local actorId = LActor.getActorId(actor)
    local item = Ranking.getItemPtrFromId(rank, actorId)
    if item ~= nil then
		local p = Ranking.getPoint(item)
		Ranking.setItem(rank, actorId, (tianti.getLevel(actor) * 100000000)  + (tianti.getId(actor) * 10000) +  win_count)
	else
        item = Ranking.addItem(rank, actorId, (tianti.getLevel(actor) * 100000000)  + (tianti.getId(actor) * 10000) +  win_count)
        if item == nil then 
			print("tiantirank,updateRankingList,actorId:"..LActor.getActorId(actor)..", add item is nil")
			return 
		end
        --创建榜单
    end
    Ranking.setSub(item, 0, LActor.getName(actor))
    Ranking.setSub(item, 1, tianti.getLevel(actor))
    Ranking.setSub(item, 2, tianti.getId(actor))
	Ranking.setSub(item, 3, LActor.getJob(actor))
	Ranking.setSub(item, 4, LActor.getSex(actor))
	Ranking.setSub(item, 5, win_count)
	updateDynamicFirstCache(LActor.getActorId(actor))
	--	showRank()
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
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Tianti, Protocol.sTiantiCmd_RankData)
    if npack == nil then return end
	if rankTbl == nil then rankTbl = {} end
	--LDataPack.writeInt(npack, Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1)
	LDataPack.writeShort(npack,#rankTbl)
	for i = 1, #rankTbl do
		local prank = rankTbl[i]
		LDataPack.writeInt(npack,Ranking.getId(prank))
		LDataPack.writeString(npack,Ranking.getSub(prank,0)) -- name
		LDataPack.writeInt(npack,Ranking.getSub(prank,1)) -- level 
		LDataPack.writeInt(npack,Ranking.getSub(prank,2)) -- id
		LDataPack.writeInt(npack,Ranking.getSub(prank,5)) -- win_count
		LDataPack.writeByte( npack, Ranking.getSub( prank, 3)) -- job 
		LDataPack.writeByte( npack, Ranking.getSub( prank, 4)) -- sex
	end
	local var = getData() 
	if var.last_week_data_len > rankingListBoardSize then 
		LDataPack.writeShort(npack,rankingListBoardSize)
	else
		LDataPack.writeShort(npack,var.last_week_data_len)
	end
	local i = 1
	while (i <= rankingListBoardSize and i <= var.last_week_data_len) do
		local tbl = var.last_week_data[i]
		LDataPack.writeInt(npack,tbl.actor_id)
		LDataPack.writeString(npack,tbl.name)
		LDataPack.writeInt(npack,tbl.tianti_level)
		LDataPack.writeInt(npack,tbl.tianti_id)
		LDataPack.writeInt(npack,tbl.win_count)
		LDataPack.writeByte( npack, tbl.job)
		LDataPack.writeByte( npack, tbl.sex)
		i = i + 1
	end
	LDataPack.flush(npack)
end


function onReqRanking(actor)
    notifyRankingList(actor)
end


function resetRankingList()
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return end
    Ranking.clearRanking(rank)
end


function releaseRankingList()
    local rank = Ranking.getRanking(rankingListName)
    Ranking.save(rank, rankingListFile)
    Ranking.release(rank)
end

function refreshWeek() 
	local var = getData()
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	dRankUpdateBefore(rankingListName)
	local  rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
	if rankTbl == nil then rankTbl = {} end

	var.last_week_data = {}
	var.last_week_data_len = 1
	for i = 1,#rankTbl do
		local prank      = rankTbl[i]
		local tbl        = {}
		tbl.actor_id     = Ranking.getId(prank)
		tbl.name         = Ranking.getSub(prank,0) -- name
		tbl.tianti_level = Ranking.getSub(prank,1) -- level
		tbl.tianti_id    = Ranking.getSub(prank,2) -- id
		tbl.job			 = Ranking.getSub(prank,3) -- job
		tbl.sex			 = Ranking.getSub(prank,4) -- sex
		tbl.win_count    = Ranking.getSub(prank,5) -- win_count
		print("tiantirank,refreshWeek,last_week_data,tbl["..i.."].name:"..(tbl.name)..",win_count:"..(tbl.win_count))
		--local d = TianTiConstConfig.diamond
		--if d.level == tonumber(tbl.tianti_level) and d.id == tonumber(tbl.tianti_id) then 
		local conf = TianTiRankAwardConfig[var.last_week_data_len]
		var.last_week_data[var.last_week_data_len] = tbl
		var.last_week_data_len = var.last_week_data_len + 1
		if conf ~= nil then 
			local mail_data      = {}
			mail_data.head       = TianTiConstConfig.rankMailHead
			mail_data.context    = string.format(TianTiConstConfig.rankMailContext,i)
			mail_data.tAwardList = conf.award
			mailsystem.sendMailById(tbl.actor_id,mail_data)
		end
		--else 
		--end
	end
	if var.last_week_data_len == 1 then 
		var.last_week_data_len = 0
	else 
		var.last_week_data_len = var.last_week_data_len - 1
	end
	print("tiantirank,refreshWeek,last_week_data_len:"..tostring(var.last_week_data_len))
	resetRankingList()
	dynamicRankUpdate(rankingListName)
	
	local  actors = System.getOnlineActorList()
	if actors ~= nil then
		for i =1,#actors do
			notifyRankingList(actors[i])
		end
	end

	
end

function getCurrWeekFistActorName()
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	local  rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
	if rankTbl == nil then rankTbl = {} end 
	if #rankTbl ~= 0 then 
		return Ranking.getSub(rankTbl[1],0)
	end
	return nil 
end

function getLastWeekFirstActorName()
	local var = getData()
	if var.last_week_data_len ~= 0 then 
		return var.last_week_data[1].name
	end
	return nil
end

function isLastWeekFirst(actor)
	local var = getData()
	if var.last_week_data_len ~= 0 then
		return var.last_week_data[1].actor_id == LActor.getActorId(actor)
	end
	return false
end

engineevent.regGameStartEvent(initRankingList)
engineevent.regGameStopEvent(releaseRankingList)


