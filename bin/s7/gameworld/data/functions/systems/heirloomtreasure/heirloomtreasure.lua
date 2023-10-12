--传世寻宝
module("heirloomtreasure", package.seeall)


--[[
data define:
    count  			    总寻宝次数
    weekCount           周寻宝次数
    reward   			累计奖励  按位读取
    resetTime           累计奖励重置时间
	blissVal			祝福值
	sequenceId			序列ID
	sequenceAward		序列奖励，按位读取
	freeCount			每天免费次数
--]]

local huntOnce = 0
local huntTenth = 1

heirloomRecord = heirloomRecord or {}

local function getHeirloomTreasure(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then
		return nil
	end
	if var.heirloomTreasure == nil then
		var.heirloomTreasure = {}
		var.heirloomTreasure.count = 0
		var.heirloomTreasure.freeCount = HeirloomTreasureConfig.freeCount
	end

	return var.heirloomTreasure
end

local function getSystemTreasure()
	local var = System.getStaticVar()
	if nil == var.heirloomTreasure then var.heirloomTreasure = {} end

	return var.heirloomTreasure
end

--获取随机序列id
local function getRandomId()
	return math.random(1, HeirloomTreasureConfig.sequence)
end

--获取前几次特殊掉落id
local function getPerDropId(actor)
	local var = getHeirloomTreasure(actor)
	if HeirloomTreasureConfig.perDrop then return HeirloomTreasureConfig.perDrop[var.count+1] end

	return nil
end

--获取祝福值掉落id，祝福值未满则返回nil
local function getBlessDropId(actor)
	local var = getHeirloomTreasure(actor)
	if (var.blissVal or 0) >= HeirloomTreasureConfig.maxBlissVal then
		var.blissVal = nil
		return HeirloomTreasureConfig.blissDropId
	end

	return nil
end

local function heirloomTreasureLog(actor, pack)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Heirloom, Protocol.sHeirloomCmd_TreasureLog)
    if npack == nil then return end
    LDataPack.writeByte(npack, #heirloomRecord)
    for _, v in ipairs(heirloomRecord) do
        LDataPack.writeString(npack, v.actorname)
        LDataPack.writeInt(npack, v.itemid)
    end
    LDataPack.flush(npack)
end

--检测开启等级
local function checkLevel(actor)
	if HeirloomTreasureConfig.openZSlevel > LActor.getZhuanShengLevel(actor) then
		print("heirloomtreasure.checkLevel: check level failed. actorId:"..LActor.getActorId(actor)..", level:"..LActor.getZhuanShengLevel(actor))
		return false
	end

	--开服天数限制
	local openDay = System.getOpenServerDay() + 1
	if openDay < HeirloomTreasureConfig.openDay then
		print("heirloomtreasure.checkLevel: openDay limit. actorId:"..LActor.getActorId(actor)..", level:"..LActor.getLevel(actor))
		return false
	end

	return true
end

--获取掉落库
local function getDropId(actor)
	local var = getHeirloomTreasure(actor)
	local conf = nil
	local hefuCount = hefutime.getHeFuCount()
	local hefuConf = HLSequencePoolConf[hefuCount]
	if hefuConf ~= nil then conf = hefuConf[var.sequenceId] end

	--先获取前几次特殊掉落id
	local dropId = getPerDropId(actor)

	--再判断祝福值是否满了
	if not dropId then dropId = getBlessDropId(actor) end

	--然后判断是否到了指定次数的终身库
	if not dropId and conf ~= nil and conf.pool ~= nil then
		for k, v in pairs(conf.pool or {}) do
			if (var.count+1 or 0) == v[1] then
				if false == System.bitOPMask(var.sequenceAward or 0, k) then
					dropId = v[2]
					var.sequenceAward = System.bitOpSetMask(var.sequenceAward or 0, k, true)
				end
			end
		end
	end

	--没找到指定次数的终身库再找对应的倍数掉落库
	if not dropId then
		for k, v in ipairs(HeirloomTreasureConfig.specialDrop or {}) do
			if 0 == (var.count+1) % v.count then dropId = v.id break end
		end
	end

	--最后是普通掉落组
	if not dropId then dropId = HeirloomTreasureConfig.ordinaryDrop end

	return dropId
end

local function addRecord(actor, id)
    if #heirloomRecord >= HeirloomTreasureConfig.huntRecordSize then
        table.remove(heirloomRecord, 1)
    end
    table.insert(heirloomRecord, {actorname=LActor.getActorName(LActor.getActorId(actor)), itemid=id})

    heirloomTreasureLog(actor)
end

local function hunt(actor, count)
	local tItemList = {}
	local var = getHeirloomTreasure(actor)
	for i=1, count do
		--获取掉落id
		local dropId = getDropId(actor)

		local tAwardList = drop.dropGroup(dropId)
		local hasQua = false
		var.count = var.count + 1
		var.weekCount = (var.weekCount or 0) + 1
		if tAwardList then
			for _, tb in pairs(tAwardList) do
				LActor.giveItemToDepot(actor, tb.id, tb.count, "heirloomtreasure")
				table.insert(tItemList, tb)

				local itemCfg = ItemConfig[tb.id]
                if AwardType_Item == tb.type and tb.id == HeirloomTreasureConfig.clearItemId then
                	hasQua = true
                	print("heirloomtreasure.hunt to clearItemId, aid:"..LActor.getActorId(actorId)..",i:"..i..",vc:"..(var.count))
					print("heirloomtreasure.hunt to clearItemId, aid:"..LActor.getActorId(actorId)..",dropId:"..dropId)
                end

				if itemCfg.needNotice == 1 then
					noticemanager.broadCastNotice(HeirloomTreasureConfig.huntNotice,
						LActor.getActorName(LActor.getActorId(actor)), item.getItemDisplayName(tb.id))

					addRecord(actor, tb.id)
				end
			end

			--抽到指定物品清空祝福值和总抽奖次数
			if hasQua then
				var.blissVal = nil
				var.count = 0
			else
				var.blissVal = (var.blissVal or 0) + HeirloomTreasureConfig.addBlissVal
			end
		end
	end

	return tItemList
end

local function resTreasureHunt(actor, type, tItemList)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Heirloom, Protocol.sHeirloomCmd_TreasureHunt)
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

--获取免费次数
local function getFreeCount(actor, huntCount)
	local var = getHeirloomTreasure(actor)
	local freeCount = var.freeCount
	if huntCount <= freeCount then
		freeCount = huntCount
		var.freeCount = var.freeCount - huntCount
	else
		var.freeCount = 0
	end

	return freeCount
end

function treasureHunt(actor, type)
	if false == checkLevel(actor) then return end
	local actorId = LActor.getActorId(actor)

	local huntCount, needYuanBao
	if type == huntOnce then
		huntCount, needYuanBao = 1, HeirloomTreasureConfig.huntOnce
	else
		huntCount, needYuanBao = 10, HeirloomTreasureConfig.huntTenth
	end

	--仓库大小判断
	local depcount = LActor.getDepotCount(actor)
	if depcount + huntCount > TreasureHuntConfig.maxCount then
		print("heirloomtreasure.treasureHunt depcount is max,aid:"..LActor.getActorId(actor)..",depcount:"..depcount..",huntCount:"..huntCount)
		return
	end

	local var = getHeirloomTreasure(actor)

	--随机终身库id
	if not var.sequenceId then var.sequenceId = getRandomId() end

	--获取免费次数
	local freeCount = getFreeCount(actor, huntCount)

	--因为最大寻宝次数是huntCount，所以要判断道具+免费次数是否大于huntCount
	local needItemCount = 0
	if huntCount > freeCount then
		local haveItemCount = LActor.getItemCount(actor, HeirloomTreasureConfig.huntItem)
		if haveItemCount > 0 then
			if haveItemCount + freeCount < huntCount then
				huntCount = haveItemCount + freeCount
				needItemCount = haveItemCount
			else
				needItemCount = huntCount - freeCount
			end
		else
			if 0 ~= freeCount then huntCount = freeCount end
		end
	end
	if needItemCount > 0 then LActor.costItem(actor, HeirloomTreasureConfig.huntItem, needItemCount, "heirloomtreasure") end

	--免费次数为0且消耗道具为0则扣元宝
	if 0 >= freeCount and 0 >= needItemCount then
		if needYuanBao > LActor.getCurrency(actor, NumericType_YuanBao) then
			print("heirloomtreasure.treasureHunt:money not enough, actorId:"..tostring(actorId))
			return
		end

		LActor.changeCurrency(actor, NumericType_YuanBao, -needYuanBao, "heirloomtreasure")
	end

	local tItemList = hunt(actor, huntCount)

	if tItemList then
		resTreasureHunt(actor, type, tItemList)
		sendRewardInfo(actor)
	end
	actorevent.onEvent(actor, aeXunBao, 3, huntCount)
end


--判断该索引的奖励是否领取了
local function checkCanReward(actor, index)
	local var = getHeirloomTreasure(actor)
	if System.bitOPMask(var.reward or 0, index) then return false end

	return true
end

--判断周抽奖次数是否满足
local function checkCountIsIllegal(actor, index)
	local var = getHeirloomTreasure(actor)
	local conf = HeirloomTreasureRewardConfig[index]

	if conf.needTime > (var.weekCount or 0) then return true end

	return false
end

--初始化奖励信息
local function initRewardInfo(actor, nowTime)
	if not actor then return end
	local var = getHeirloomTreasure(actor)
	var.resetTime = nowTime

	if var.weekCount or var.reward then
		var.weekCount = 0
		var.reward = 0

		return true
	end

	return false
end

local function HeirloomTreasureC2S(actor, pack)
	local type = LDataPack.readByte(pack)

	treasureHunt(actor, type)
end

function sendRewardInfo(actor)
 	local data = getHeirloomTreasure(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Heirloom, Protocol.sHeirloomCmd_RewardInfo)

    LDataPack.writeInt(npack, data.reward or 0)
    LDataPack.writeInt(npack, data.weekCount or 0)
	LDataPack.writeInt(npack, data.blissVal or 0)
	LDataPack.writeInt(npack, data.freeCount or 0)
    LDataPack.flush(npack)
end

local function getReward(actor, pack)
	local index = LDataPack.readInt(pack)
	local var = getHeirloomTreasure(actor)
	local actorId = LActor.getActorId(actor)

	--索引判断
	if index < 1 or index > #HeirloomTreasureRewardConfig then
		print("heirloomtreasure.getReward:index is illegal, index:"..tostring(index)..",actorId:"..tostring(actorId))
		return
	end

	--抽奖次数判断
	if true == checkCountIsIllegal(actor, index) then
		print("heirloomtreasure.getReward:count is not enough, count:"..tostring(var.weekCount or 0)..",actorId:"..tostring(actorId))
		return
	end

	--奖励是否领取了
	if false == checkCanReward(actor, index) then
		print("heirloomtreasure.getReward:already get reward, index:"..tostring(index)..",actorId:"..tostring(actorId))
		return
	end

	local conf = HeirloomTreasureRewardConfig[index]
	if not LActor.canGiveAwards(actor, conf.reward) then print("heirloomtreasure.getReward:canGiveAwards is false") return end

	--发奖励
    LActor.giveAwards(actor, conf.reward, "heiTrereward,index:"..tostring(index))

    var.reward = System.bitOpSetMask(var.reward or 0, index, true)

	sendRewardInfo(actor)
end

local function resetActor(actor)
	local var = getSystemTreasure()
	local data = getHeirloomTreasure(actor)

	if var.resetTime then
		if (data.resetTime or 0) < var.resetTime then initRewardInfo(actor, var.resetTime) end
	end
end

local function onLogin(actor)
	resetActor(actor)
    sendRewardInfo(actor)
end

local function onNewDay(actor, isLogin)
	if true == checkLevel(actor) then
		local data = getHeirloomTreasure(actor)
		data.freeCount = HeirloomTreasureConfig.freeCount
    	if not isLogin then sendRewardInfo(actor) end
    end
end

--重置寻宝累计次数
local function resetHeirloomTreasure()
	local var = getSystemTreasure()
	var.resetTime = System.getNowTime()

	print("heirloomtreasure.resetHeirloomTreasure: time reset, resetTime:"..tostring(var.resetTime))

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
actorevent.reg(aeNewDayArrive, onNewDay)

_G.ResetHeirloomTreasure = resetHeirloomTreasure

netmsgdispatcher.reg(Protocol.CMD_Heirloom, Protocol.cHeirloomCmd_TreasureHunt, HeirloomTreasureC2S)
netmsgdispatcher.reg(Protocol.CMD_Heirloom, Protocol.cHeirloomCmd_TreasureLog, heirloomTreasureLog)
netmsgdispatcher.reg(Protocol.CMD_Heirloom, Protocol.cHeirloomCmd_GetReward, getReward)

function test(actor, args)
	if 1 == tonumber(args[1]) then
		treasureHunt(actor, tonumber(args[2]))
	elseif 2 == tonumber(args[1]) then
		local data = getHeirloomTreasure(actor)
		data.freeCount = tonumber(args[2])
	end
end



