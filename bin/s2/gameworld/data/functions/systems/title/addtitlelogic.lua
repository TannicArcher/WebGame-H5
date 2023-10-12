module("addtitlelogic", package.seeall)

local rtConf = RankTitleConf
local rankTitleTbl = {}
local titleRankTbl = {}

function init()
	local tbl
	local name
	local rTbl
	for i=1, #rtConf do
		tbl = rtConf[i]
		name = nil
		if tbl.rId then
			name = tbl.rId
		elseif tbl.rName then
			name = tbl.rName
		end
		if name ~= nil then
			if rankTitleTbl[name] == nil then rankTitleTbl[name] = {} end
			rTbl = rankTitleTbl[name]
			rTbl[#rTbl + 1] = tbl

			if titleRankTbl[tbl.tId] == nil then titleRankTbl[tbl.tId] = {} end
			rTbl = titleRankTbl[tbl.tId]
			rTbl[#rTbl + 1] = tbl
		end
	end
end

function sRankUpdate(rId)

	local rank = Ranking.getStaticRank(rId)

	local rtTbl = rankTitleTbl[rId]
	if rtTbl == nil then return end

	if rank then
		local tbl
		local id
		local actor
		local d_var = System.getDyanmicVar()
		if d_var.sRankTitle == nil then d_var.sRankTitle = {} end
		local rtVar = d_var.sRankTitle
		local idx = 0
		local adds = {}
		local dels = {}
		local tempIdx = 0

		for i=1, #rtTbl do
			tbl = rtTbl[i]
			idx = tbl.rIdx - 1
			id = Ranking.getSRIdFromIdx(rank, idx)
			if id ~= 0 then

				if rtVar[idx] then
					if rtVar[idx].id ~= id then
						actor = LActor.getActorById(rtVar[idx].id or 0)
						if actor then
							tempIdx = #dels + 1
							dels[tempIdx] = {}
							dels[tempIdx].aId = rtVar[idx].id
							dels[tempIdx].tId = tbl.tId
						end
					end
					tempIdx = #adds + 1
					adds[tempIdx] = {}
					adds[tempIdx].aId = id
					adds[tempIdx].tId = tbl.tId

				else
					tempIdx = #adds + 1
					adds[tempIdx] = {}
					adds[tempIdx].aId = id
					adds[tempIdx].tId = tbl.tId
				end
			else

				if rtVar[idx] then
					actor = LActor.getActorById(rtVar[idx].id or 0)
					if actor then
						tempIdx = #dels + 1
						dels[tempIdx] = {}
						dels[tempIdx].aId = rtVar[idx].id
						dels[tempIdx].tId = tbl.tId
					end
				end
			end
		end

		for i=1, #dels do
			actor = LActor.getActorById(dels[i].aId)
			titlesystem.delitle(actor, dels[i].tId, true)
		end

		for i=1, #adds do
			actor = LActor.getActorById(adds[i].aId)
			if actor then
				titlesystem.addTitle(actor, adds[i].tId)
			else
				System.offlineChangeTitle(adds[i].aId, 2, adds[i].tId)
			end
		end
		d_var.sRankTitle = {}
	end
end

function dRankUpdate(rName)

	local rank = Ranking.getRanking(rName)
	local rtTbl = rankTitleTbl[rName]
	if rtTbl == nil then return end

	if rank then
		local tbl
		local item
		local id
		local actor
		local d_var = System.getDyanmicVar()
		if d_var.dRankTitle == nil then d_var.dRankTitle = {} end
		local rtVar = d_var.dRankTitle
		local idx = 0

		local adds = {}
		local dels = {}
		local tempIdx = 0

		for i=1, #rtTbl do
			tbl = rtTbl[i]
			idx = tbl.rIdx - 1
			item = Ranking.getItemFromIndex(rank, idx)
			if item then
				id = Ranking.getId(item)

				if rtVar[idx] then
					if rtVar[idx].id ~= id then
						actor = LActor.getActorById(rtVar[idx].id or 0)
						-- titlesystem.delitle(actor, tbl.tId, true)
						if actor then
							tempIdx = #dels + 1
							dels[tempIdx] = {}
							dels[tempIdx].aId = rtVar[idx].id
							dels[tempIdx].tId = tbl.tId
						end
					end

					-- actor = LActor.getActorById(id)
					-- if actor then
					-- 	titlesystem.addTitle(actor, tbl.tId)
					-- else
					-- 	System.offlineChangeTitle(id, 2, tbl.tId)
					-- end

					tempIdx = #adds + 1
					adds[tempIdx] = {}
					adds[tempIdx].aId = id
					adds[tempIdx].tId = tbl.tId

				else
					-- actor = LActor.getActorById(id)
					-- if actor then
					-- 	titlesystem.addTitle(actor, tbl.tId)
					-- else
					-- 	System.offlineChangeTitle(id, 2, tbl.tId)
					-- end
					tempIdx = #adds + 1
					adds[tempIdx] = {}
					adds[tempIdx].aId = id
					adds[tempIdx].tId = tbl.tId
				end
			else
				if rtVar[idx] then
					actor = LActor.getActorById(rtVar[idx].id or 0)
					-- titlesystem.delitle(actor, tbl.tId, true)
					if actor then
						tempIdx = #dels + 1
						dels[tempIdx] = {}
						dels[tempIdx].aId = rtVar[idx].id
						dels[tempIdx].tId = tbl.tId
					end
				end

			end
		end

		for i=1, #dels do
			actor = LActor.getActorById(dels[i].aId)
			titlesystem.delitle(actor, dels[i].tId, true)
		end

		for i=1, #adds do
			actor = LActor.getActorById(adds[i].aId)
			if actor then
				titlesystem.addTitle(actor, adds[i].tId)
			else
				System.offlineChangeTitle(adds[i].aId, 2, adds[i].tId)
			end
		end

		d_var.dRankTitle = {}
	end
end

-- function delTitle(rank)
-- 	local tbl
-- 	local item
-- 	local id
-- 	local actor
-- 	for i=1, #rtConf do
-- 		tbl = rtConf[i]
-- 		item = Ranking.getItemFromIndex(rank, tbl.rIdx - 1)
-- 		if item then
-- 			id = Ranking.getId(item)
-- 			actor = LActor.getActorById(id)
-- 			if actor then
-- 				titlesystem.delitle(actor, tbl.tId, true)
-- 			-- else
-- 				-- System.offlineChangeTitle(id, 1, tbl.tId)
-- 			end
-- 		end
-- 	end
-- end

--刷新排行榜之前要清掉之前的人的称号
function dRankUpdateBefore(rName)

	local rank = Ranking.getRanking(rName)
	local rtTbl = rankTitleTbl[rName]
	if rtTbl == nil then return end

	if rank then
		local tbl
		local item
		local id
		-- local actor
		local d_var = System.getDyanmicVar()
		if d_var.dRankTitle == nil then d_var.dRankTitle = {} end
		local rtVar = d_var.dRankTitle
		local idx = 0

		for i=1, #rtTbl do
			tbl = rtTbl[i]
			idx = tbl.rIdx - 1
			item = Ranking.getItemFromIndex(rank, idx)
			if item then
				id = Ranking.getId(item)
				-- actor = LActor.getActorById(id)
				-- if actor then
				-- 	titlesystem.delitle(actor, tbl.tId, true)
				-- end
				if id ~= 0 then
					rtVar[idx] = {}
					rtVar[idx].id = id
				end
			end
		end
	end
end
function sRankUpdateBefore(rId)
	local rank = Ranking.getStaticRank(rId)
	local rtTbl = rankTitleTbl[rId]
	if rtTbl == nil then return end
	if rank then
		local tbl
		local id
		-- local actor

		local d_var = System.getDyanmicVar()
		if d_var.sRankTitle == nil then d_var.sRankTitle = {} end
		local rtVar = d_var.sRankTitle
		local idx = 0

		for i=1, #rtTbl do
			tbl = rtTbl[i]
			idx = tbl.rIdx - 1
			id = Ranking.getSRIdFromIdx(rank, idx)
			if id ~= 0 then
				-- actor = LActor.getActorById(id)
				-- if actor then
				-- 	titlesystem.delitle(actor, tbl.tId, true)
				-- end
				rtVar[idx] = {}
				rtVar[idx].id = id

			end
		end
	end
end


function onLogin(actor, firstLogin)
	local tbl
	local id
	local rank
	-- local item
	-- for i=1, #rtConf do
	-- 	tbl = rtConf[i]
	-- 	id = 0
	-- 	if tbl.rId then
	-- 		rank = Ranking.getStaticRank(tbl.rId)
	-- 		if rank then
	-- 			id = Ranking.getSRIdFromIdx(rank, tbl.rIdx - 1)
	-- 		end
	-- 	elseif tbl.rName then
	-- 		rank = Ranking.getRanking(tbl.rName)
	-- 		if rank then
	-- 			item = Ranking.getItemFromIndex(rank, tbl.rIdx - 1)
	-- 			if item then
	-- 				id = Ranking.getId(item)
	-- 			end
	-- 		end
	-- 	end

	-- 	if id ~= LActor.getActorId(actor) then
	-- 		titlesystem.delitle(actor, tbl.tId, true)
	-- 	end
	-- end
	local isDel = true
	local item
	local aId = LActor.getActorId(actor)
	for k,v in pairs(titleRankTbl) do
		isDel = true
		for i=1, #v do
			tbl = v[i]
			if tbl.rId then
				rank = Ranking.getStaticRank(tbl.rId)
				if rank then
					id = Ranking.getSRIdFromIdx(rank, tbl.rIdx - 1)
					if id == aId then
						isDel = false
						break
					end
				end
			elseif tbl.rName then
				rank = Ranking.getRanking(tbl.rName)
				if rank then
					item = Ranking.getItemFromIndex(rank, tbl.rIdx - 1)
					if item then
						id = Ranking.getId(item)
						if id == aId then
							isDel = false
							break
						end
					end
				end
			end
		end
		if isDel == true then
			titlesystem.delitle(actor, k, true)
		end
	end

	titlesystem.getTitlesInfo(actor, nil)
end

_G.staticRankUpdate = sRankUpdate
_G.dynamicRankUpdate = dRankUpdate

_G.sRankUpdateBefore = sRankUpdateBefore
_G.dRankUpdateBefore = dRankUpdateBefore

--actorevent.reg(aeUserLogin, onLogin)
table.insert(InitFnTable, init)