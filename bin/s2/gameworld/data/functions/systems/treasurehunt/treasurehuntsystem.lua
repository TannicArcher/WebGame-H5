module("treasurehuntsystem", package.seeall)

local huntOnce = 0
local huntTenth = 1

HuntRecord = HuntRecord or {}  -- {actorname, itemname}[]
local keyList = {}
for k in pairs(treasurehuntlevel or {}) do
	keyList[#keyList+1] = k
end
table.sort(keyList)

local hfKeyList = {}
--获取对应的时间段配置
for i, hefuconfig in pairs(TreasureHuntHefu) do
	local kl = {}
	for k in pairs(hefuconfig or {}) do
		kl[#kl+1] = k
	end
	table.sort(kl)
	hfKeyList[i] = kl
end

local function getGlobalData()
	local var = System.getStaticVar()
	if var == nil then return nil end

	if var.treasurehunt == nil then
		var.treasurehunt = {}
		var.treasurehunt.count = 0
	end
	return var.treasurehunt
end

local function getStaticVar(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then 
		return nil
	end
	if var.treasurehunt == nil then 
		var.treasurehunt = {}
		var.treasurehunt.count = 0--TreasureHuntConfig.initCount
	end
	return var.treasurehunt
end


function treasureHunt(actor, type)
	local huntCount, needYuanBao
	if (type == huntOnce) then
		huntCount, needYuanBao = 1, TreasureHuntConfig.huntOnce
	else
		huntCount, needYuanBao = 10, TreasureHuntConfig.huntTenth
	end

	--先判断道具是否足够
	local haveItemCount = LActor.getItemCount(actor, TreasureHuntConfig.huntItem)
	if haveItemCount > 0 and haveItemCount < huntCount then
		huntCount = haveItemCount
	end
	
	--仓库大小判断
	local depcount = LActor.getDepotCount(actor)
	if depcount + huntCount > TreasureHuntConfig.maxCount then
		print("fuwentreasure.treasureHunt depcount is max,aid:"..LActor.getActorId(actor)..",depcount:"..depcount..",huntCount:"..huntCount)
		return
	end
	
	if haveItemCount > 0 then
		--扣除消耗
		LActor.costItem(actor, TreasureHuntConfig.huntItem, huntCount, "treasure hunt")
	else
		local curYuanBao = LActor.getCurrency(actor, NumericType_YuanBao)
		if (needYuanBao > curYuanBao) then
			return
		end
		LActor.changeCurrency(actor, NumericType_YuanBao, -needYuanBao, "treasure hunt")
	end

	local tItemList = hunt(actor, huntCount)
	if (tItemList) then
		resTreasureHunt(actor, type, tItemList)
	end
	actorevent.onEvent(actor, aeXunBao, 1, huntCount)
end

--迭代器
local function pairsByKeys(keylist, config)
	local i = 0
	return function()
		i = i + 1
		return keylist[i], config[keylist[i]]
	end
end

local function getdropGroupId(actor)
	local var = getStaticVar(actor)
	if TreasureHuntConfig.perDrop then
		local dropid = TreasureHuntConfig.perDrop[var.count+1]
		if dropid then
			return dropid
		end
	end

	local level = 0 
	if LActor.getZhuanShengLevel(actor) ~= 0 then 
		level = LActor.getZhuanShengLevel(actor) * 5
	else 
		level = LActor.getLevel(actor)
	end

	--合服的
	local hftimes = hefutime.getHeFuCount()
	local dayConfig = nil

	if 0 == hftimes or nil == hftimes then
		--获取开服时间
		local openDay = System.getOpenServerDay() + 1

		--获取对应的时间段配置
		for key, data in pairsByKeys(keyList, treasurehuntlevel) do
			--如果找不到对应天数的配置，取最早天数的配置，看策划需不需要改
			if not dayConfig then dayConfig = data end
			if openDay <= key then dayConfig = data break end
		end
	else
		local hefuDay = hefutime.getHeFuDay() or 0
		local hefuconfig = TreasureHuntHefu[hftimes]

		if not hefuconfig then
			--找不到合服第 hftimes 天的寻宝配置
			assert(false)
		end

		for key, data in pairsByKeys(hfKeyList[hftimes], hefuconfig) do
			--如果找不到对应天数的配置，取最早天数的配置，看策划需不需要改
			if not dayConfig then dayConfig = data end
			if hefuDay <= key then dayConfig = data break end
		end
	end

	local config = dayConfig[level]
	if config == nil or not next(config) then 
		print("error treasurehunth get dropid ")
		return 1
	end

	local index = 0
	for i,v in pairs(config.cumulativeDropGroupId) do 
		if math.floor((var.count + 1) % v.count) == 0 then 
			index = i
		end
	end
	
	if index == 0 then
		return config.dropGroupId
	else 
		return config.cumulativeDropGroupId[index].dropGroupId
	end
end

local function treasureHunt_record(actor, pack)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_TreasureHunt, Protocol.sTreasureHuntCmd_ResRecord)
    if npack == nil then return end
    LDataPack.writeShort(npack, #HuntRecord)
    for _, v in ipairs(HuntRecord) do
        LDataPack.writeString(npack, v.actorname)
        LDataPack.writeInt(npack, v.itemid)
    end
    LDataPack.flush(npack)
end

local function addRecord(actor, id)
    if #HuntRecord >= TreasureHuntConfig.huntRecordSize then
        table.remove(HuntRecord, 1)
    end
    table.insert(HuntRecord, {actorname=LActor.getActorName(LActor.getActorId(actor)), itemid=id})

    treasureHunt_record(actor)
end

function hunt(actor, count)
	local tItemList = {}
	local var = getStaticVar(actor)
	local gdata = getGlobalData(actor)
	--随机终身库id
	if not var.sequenceId then var.sequenceId = math.random(1, TreasureHuntConfig.sequence) end
	local conf = nil
	local hefuCount = hefutime.getHeFuCount()
	local gHefuConf = THSequenceServerPoolConf[hefuCount]
	local hefuConf = THSequencePoolConf[hefuCount]
	if (gdata.hefuCount or 0) ~= hefuCount then
		--策划要求合服后次数清零
		gdata.count = 0
		gdata.hefuCount = hefuCount
	end
	if (var.hefuCount or 0) ~= hefuCount then
		--策划要求合服后次数清零
		var.count = 0
		--var.sequenceAward = 0
		var.hefuCount = hefuCount
	end
	if hefuConf ~= nil then conf = hefuConf[var.sequenceId] end
	for i=1,count do
		local dropId = nil
		var.count = (var.count or 0) + 1
		gdata.count = (gdata.count or 0) + 1
		--然后判断是否到了指定次数的终身库
		if gHefuConf ~= nil and gHefuConf.pool ~= nil then
			dropId = gHefuConf.pool[gdata.count]
		end
		if not dropId and conf ~= nil and conf.pool ~= nil then
			--[[
			--移植龙城遗留的流程，这边策划的需求不需要那么麻烦
			for k, v in pairs(conf.pool or {}) do
				if (var.count or 0 + 1) == v[1] then
					if false == System.bitOPMask(var.sequenceAward or 0, k) then
						dropId = v[2]
						var.sequenceAward = System.bitOpSetMask(var.sequenceAward or 0, k, true)
					end
				end
			end
			]]
			dropId = conf.pool[var.count]
		end
		if not dropId then dropId = getdropGroupId(actor) end
		local tAwardList = drop.dropGroup(dropId)

		if (tAwardList) then
			for _,tb in pairs(tAwardList) do
				if (tb.type == AwardType_Numeric) then
					LActor.giveAward(actor, tb.type, tb.id, tb.count, "treasure hunt")
				else
					LActor.giveItemToDepot(actor, tb.id, tb.count, "treasure hunt")
					table.insert(tItemList, tb)
                end
				local itemcfg = ItemConfig[tb.id]
                if tb.type == AwardType_Item and itemcfg and itemcfg.needNotice == 1 then
                    noticemanager.broadCastNotice(TreasureHuntConfig.huntNotice,
                        LActor.getActorName(LActor.getActorId(actor)), item.getItemDisplayName(tb.id))

                    --策划要求有转数的装备才记录, 额外要增加15,16,17这些道具类型也要
                    if (itemcfg.zsLevel and itemcfg.zsLevel > 0)
						or (itemcfg.type or 0) == 15
						or (itemcfg.type or 0) == 16
						or (itemcfg.type or 0) == 17
					then 
						addRecord(actor, tb.id)
					end
                end
			end
		end
	end
	return tItemList
end

function resTreasureHunt(actor, type, tItemList)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_TreasureHunt, Protocol.sTreasureHuntCmd_ResHunt)
	if pack == nil then return end

	LDataPack.writeShort(pack, type)
	LDataPack.writeInt(pack, #tItemList)
	for _,tb in ipairs(tItemList) do
		LDataPack.writeData(pack, 2,
							dtInt, tb.id,
							dtInt, tb.count)
	end
	LDataPack.flush(pack)	
end

function treasureHunt_c2s(actor, pack)
	local type = LDataPack.readShort(pack)

	treasureHunt(actor, type)
end


netmsgdispatcher.reg(Protocol.CMD_TreasureHunt, Protocol.cTreasureHuntCmd_Hunt, treasureHunt_c2s)
netmsgdispatcher.reg(Protocol.CMD_TreasureHunt, Protocol.cTreasureHuntCmd_ReqRecord, treasureHunt_record)
