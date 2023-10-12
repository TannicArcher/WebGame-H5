--战纹寻宝
module("fuwentreasure", package.seeall)


--[[
data define:
    count -- number      总寻宝次数
    weekCount            周寻宝次数
    reward   			累计奖励  按位读取
    resetTime           累计奖励重置时间
	blissVal			祝福值
--]]

local weekDays = 7

local huntOnce = 0
local huntTenth = 1

local FuwenTreasureConfig = FuwenTreasureConfig
local FuwenTreasureLevelConfig = FuwenTreasureLevelConfig

FuwenHuntRecord = FuwenHuntRecord or {} 

local function getFwTreasure(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then
		return nil
	end
	if var.fwtreasure == nil then 
		var.fwtreasure = {}
		var.fwtreasure.count = 0
	end
	return var.fwtreasure
end

local function getSystemTreasure()
	local var = System.getStaticVar()
	if nil == var.fuwenTreasure then var.fuwenTreasure = {} end

	return var.fuwenTreasure
end

--根据等级获取最近的配置
local function getFuwenTreasureLevelConfig(level)
	local conf = nil
	for _,v in ipairs(FuwenTreasureLevelConfig) do
		if v.level <= level and level <= v.levelend then
			conf = v
			break
		end
	end
	return conf
end

local function getdropGroupId(actor)
	local var = getFwTreasure(actor)
	if FuwenTreasureConfig.perDrop then
		local dropid = FuwenTreasureConfig.perDrop[var.count+1]
		if dropid then
			return dropid
		end
	end
	
	local level = challengefbsystem.getChallengeId(actor) + 1
	local config = getFuwenTreasureLevelConfig(level)
	if config == nil then 
		print("fuwentreasure.getdropGroupId:not level config " .. level);
		return 0
	end
	
	if (var.blissVal or 0) >= FuwenTreasureConfig.maxBlissVal then
		var.blissVal = nil
		return config.eDropGroupId
	end
	
	local index = 0
	for i,v in pairs(config.cumulativeDropGroupId) do 
		if math.floor((var.count+1) % v.count) == 0 then 
			index = i
		end
	end
	
	if index == 0 then
		return config.dropGroupId
	else 
		return config.cumulativeDropGroupId[index].dropGroupId
	end
end

local function fwTreasureLog(actor, pack)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_FuWen, Protocol.sFuWenCmd_TreasureLog)
    if npack == nil then return end
    LDataPack.writeByte(npack, #FuwenHuntRecord)
    for _, v in ipairs(FuwenHuntRecord) do
        LDataPack.writeString(npack, v.actorname)
        LDataPack.writeInt(npack, v.itemid)
    end
    LDataPack.flush(npack)
end

--检测开启等级
local function checkLevel(actor)
	if FuwenTreasureConfig.openlevel > LActor.getLevel(actor) then
		print("fuwentreasure.checkLevel: check level failed. actorId:"..LActor.getActorId(actor)..", level:"..LActor.getLevel(actor))
		return false
	end

	return true
end

local function addRecord(actor, id)
    if #FuwenHuntRecord >= FuwenTreasureConfig.huntRecordSize then
        table.remove(FuwenHuntRecord, 1)
    end
    table.insert(FuwenHuntRecord, {actorname=LActor.getActorName(LActor.getActorId(actor)), itemid=id})

    fwTreasureLog(actor)
end

local function hunt(actor, count)
	local tItemList = {}
	local var = getFwTreasure(actor)
	--随机终身库id
	if not var.sequenceId then var.sequenceId = math.random(1, FuwenTreasureConfig.sequence) end
	local conf = nil
	local hefuCount = hefutime.getHeFuCount()
	local hefuConf = FuwenSequencePoolConf[hefuCount]
	if hefuConf ~= nil then conf = hefuConf[var.sequenceId] end
	for i=1,count do
		local dropId = nil
		--然后判断是否到了指定次数的终身库
		if conf ~= nil and conf.pool ~= nil then
			for k, v in pairs(conf.pool or {}) do
				if (var.count or 0 + 1) == v[1] then
					if false == System.bitOPMask(var.sequenceAward or 0, k) then
						dropId = v[2]
						var.sequenceAward = System.bitOpSetMask(var.sequenceAward or 0, k, true)
					end
				end
			end
		end

		if not dropId then dropId = getdropGroupId(actor) end
		local tAwardList = drop.dropGroup(dropId)
		-- table.print(tAwardList)
		local hasQua = false
		var.count = var.count + 1
		var.weekCount = (var.weekCount or 0) + 1
		if (tAwardList) then
			for _,tb in pairs(tAwardList) do
				if (tb.type == AwardType_Numeric) then
					LActor.giveAward(actor, tb.type, tb.id, tb.count, "fwtreasure")
					table.insert(tItemList, tb)
				else
					LActor.giveItemToDepot(actor, tb.id, tb.count, "fwtreasure")
					table.insert(tItemList, tb)
                end
				local itemCfg = ItemConfig[tb.id]
                if tb.type == AwardType_Item and itemCfg then
					if itemCfg.needNotice == 1 then
						noticemanager.broadCastNotice(FuwenTreasureConfig.huntNotice,
							LActor.getActorName(LActor.getActorId(actor)), item.getItemDisplayName(tb.id))
						addRecord(actor, tb.id)
					end
					if itemCfg.type == ItemType_FuWen and itemCfg.quality == FuwenTreasureConfig.blissQua then
						hasQua = true
						print("fuwentreasure.hunt to GoldFuwen, aid:"..LActor.getActorId(actorId)..",i:"..i..",vc:"..(var.count))
						print("fuwentreasure.hunt to GoldFuwen, aid:"..LActor.getActorId(actorId)..",dropId:"..dropId)
					end
                end
			end
			if hasQua then
				var.blissVal = nil
			else
				var.blissVal = (var.blissVal or 0) + FuwenTreasureConfig.addBlissVal
			end
		end
	end
	return tItemList
end

local function resTreasureHunt(actor, type, tItemList)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_FuWen, Protocol.sFuWenCmd_TreasureHunt)
	if pack == nil then return end

	LDataPack.writeByte(pack, type)
	LDataPack.writeByte(pack, #tItemList)
	for _,tb in ipairs(tItemList) do
		LDataPack.writeData(pack, 2,
							dtInt, tb.id,
							dtByte, tb.count)
	end
	LDataPack.flush(pack)	
end

function treasureHunt(actor, type)
	if false == checkLevel(actor) then return end
	
	local huntCount, needYuanBao
	if (type == huntOnce) then
		huntCount, needYuanBao = 1, FuwenTreasureConfig.huntOnce
	else
		huntCount, needYuanBao = 10, FuwenTreasureConfig.huntTenth
	end
	
	--先判断道具是否足够
	local haveItemCount = LActor.getItemCount(actor, FuwenTreasureConfig.huntItem)
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
		LActor.costItem(actor, FuwenTreasureConfig.huntItem, huntCount, "fwtreasure")
	else
		local curYuanBao = LActor.getCurrency(actor, NumericType_YuanBao)
		if (needYuanBao > curYuanBao) then
			return
		end
		LActor.changeCurrency(actor, NumericType_YuanBao, -needYuanBao, "fwtreasure")
	end
	
	local tItemList = hunt(actor, huntCount)
	-- table.print(tItemList)
	if (tItemList) then
		resTreasureHunt(actor, type, tItemList)
		sendRewardInfo(actor)
	end
	actorevent.onEvent(actor, aeXunBao, 2, huntCount)
end


--判断该索引的奖励是否领取了
local function checkCanReward(actor, index)
	local var = getFwTreasure(actor)
	if System.bitOPMask(var.reward or 0, index) then return false end

	return true
end

--判断周抽奖次数是否满足
local function checkCountIsIllegal(actor, index)
	local var = getFwTreasure(actor)
	local conf = FuwenTreasureRewardConfig[index]

	if conf.needTime > (var.weekCount or 0) then return true end

	return false
end

--初始化奖励信息
local function initRewardInfo(actor, nowTime)
	if not actor then return end
	local var = getFwTreasure(actor)
	var.resetTime = nowTime

	if var.weekCount or var.reward then
		var.weekCount = 0
		var.reward = 0

		return true
	end

	return false
end

local function fwTreasureC2S(actor, pack)
	local type = LDataPack.readByte(pack)

	treasureHunt(actor, type)
end

function sendRewardInfo(actor)
 	local data = getFwTreasure(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_FuWen, Protocol.sFuWenCmd_RewardInfo)

    LDataPack.writeInt(npack, data.reward or 0)
    LDataPack.writeInt(npack, data.weekCount or 0)
	LDataPack.writeInt(npack, data.blissVal or 0)
    LDataPack.flush(npack)
	--print("data.blissVal="..(data.blissVal or 0))
end

local function getReward(actor, pack)
	local index = LDataPack.readInt(pack)
	local var = getFwTreasure(actor)
	local actorId = LActor.getActorId(actor)

	--索引判断
	if index < 1 or index > #FuwenTreasureRewardConfig then 
		print("fuwentreasure.getReward:index is illegal, index:"..tostring(index)..",actorId:"..tostring(actorId))
		return
	end

	--抽奖次数判断
	if true == checkCountIsIllegal(actor, index) then
		print("fuwentreasure.getReward:count is not enough, count:"..tostring(var.weekCount or 0)..",actorId:"..tostring(actorId))
		return
	end

	--奖励是否领取了
	if false == checkCanReward(actor, index) then
		print("fuwentreasure.getReward:already get reward, index:"..tostring(index)..",actorId:"..tostring(actorId))
		return
	end

	local conf = FuwenTreasureRewardConfig[index]
	if not LActor.canGiveAwards(actor, conf.reward) then print("fuwentreasure.getReward:canGiveAwards is false") return end

	--发奖励
    LActor.giveAwards(actor, conf.reward, "fuwenreward,index:"..tostring(index))

    var.reward = System.bitOpSetMask(var.reward or 0, index, true)

	sendRewardInfo(actor)
end

local function resetActor(actor)
	local var = getSystemTreasure()
	local data = getFwTreasure(actor)

	if var.resetTime then
		if (data.resetTime or 0) < var.resetTime then initRewardInfo(actor, var.resetTime) end
	end
end

local function onLogin(actor)
	resetActor(actor)
    sendRewardInfo(actor)
end

--重置符文寻宝累计次数 
local function resetFuwenTreasure()
	local var = getSystemTreasure()
	var.resetTime = System.getNowTime()

	print("fuwentreasure.resetFuwenTreasure: time reset, resetTime:"..tostring(var.resetTime))

	local actors = System.getOnlineActorList()
	if actors then
		for i=1, #actors do 
			if true == initRewardInfo(actors[i], var.resetTime) then
				sendRewardInfo(actors[i])
			end
		end
	end
end

actorevent.reg(aeUserLogin, onLogin)

_G.ResetFuwenTreasure = resetFuwenTreasure

netmsgdispatcher.reg(Protocol.CMD_FuWen, Protocol.cFuWenCmd_TreasureHunt, fwTreasureC2S)
netmsgdispatcher.reg(Protocol.CMD_FuWen, Protocol.cFuWenCmd_TreasureLog, fwTreasureLog)
netmsgdispatcher.reg(Protocol.CMD_FuWen, Protocol.cFuWenCmd_GetReward, getReward)



