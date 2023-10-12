module("dailyfuben", package.seeall)


--[[
dailyFubenData = {
	[id]={
	     short usedCount,       --已使用次数
	     short buyCount,        --已购买次数
	     short reservedCount, --保留次数(付费次数)
	     isClear     --1已通关,nil没有
	}
}
 ]]
local p = Protocol
local EquipBagCount = 20   --扫荡限制空闲格子数

local function getData(actor)
	local data = LActor.getStaticVar(actor)
	if data == nil then return nil end
	if data.dailyFubenData == nil then
		data.dailyFubenData = {}
	end
	return data.dailyFubenData
end

local function getFbIdByLv(actor, conf)
	if type(conf.fbId) ~= "table" then
		return conf.fbId
	end
	--local zs = LActor.getZhuanShengLevel(actor)
	--local fbTable = conf.fbId[1]
	--local index = 1
	--if zs > 0 then
	--	fbTable = conf.fbId[2]
	--	index = zs
	--else
	--	local lv = LActor.getLevel(actor)
	--	index = math.floor((lv - conf.levelLimit)/conf.fbLvSpan) + 1		
	--end
	--if #fbTable < index then
	--	index = #fbTable
	--end
	--return fbTable[index]
	local lv = LActor.getLevel(actor)
	for _,v in ipairs(conf.fbId) do
		if v.s <= lv and lv <= v.e then
			return v.id
		end
	end
	return nil
end

local function getDropIdByLv(lv, conf)
	if type(conf.dropId) ~= "table" then
		return conf.dropId
	end
	--local dropTable = conf.dropId[1]
	--local index = 1
	--if zs > 0 then
	--	dropTable = conf.dropId[2]
	--	index = zs
	--else
	--	index = math.floor((lv - conf.levelLimit)/conf.fbLvSpan) + 1
	--end
	--if #dropTable < index then
	--	index = #dropTable
	--end
	--return dropTable[index]
	for _,v in ipairs(conf.dropId) do
		if v.s <= lv and lv <= v.e then
			return v.id
		end
	end
end

local function onLogin(actor)
	local data = getData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Fuben, Protocol.sFubenCmd_DailyFbInitData)
	local pos = LDataPack.getPosition(npack)
	LDataPack.writeShort(npack, 0)

	local count = 0
	for _, conf in pairs(DailyFubenConfig) do
		LDataPack.writeInt(npack, conf.id)
		local d = data[conf.id] or {}
		LDataPack.writeShort(npack, d.usedCount or 0)
		LDataPack.writeShort(npack, d.buyCount or 0)
		LDataPack.writeShort(npack, d.reservedCount or 0)
		LDataPack.writeByte(npack, d.isClear or 0)
		count = count + 1
	end
	local nowPos = LDataPack.getPosition(npack)
	LDataPack.setPosition(npack, pos)
	LDataPack.writeShort(npack, count)
	LDataPack.setPosition(npack, nowPos)

	LDataPack.flush(npack)
end

local function onNewDay(actor, login)
	local data = getData(actor)
    print("dailyfuben on new day.."..LActor.getActorId(actor))
	for _, conf in pairs(DailyFubenConfig) do
		if data[conf.id] == nil then data[conf.id] = {} end
		local usedCount = data[conf.id].usedCount or 0
		local leftCount = (data[conf.id].buyCount or 0)	 + (data[conf.id].reservedCount or 0)
		if usedCount > conf.freeCount then
			leftCount = leftCount - (usedCount - conf.freeCount)
		end

		data[conf.id].usedCount = nil
		data[conf.id].buyCount = nil
		data[conf.id].reservedCount = leftCount
	end

	if not login then
		onLogin(actor)
	end
end

--等级是否可以扫荡
local function canSweep(actor, conf)
	if not conf.sweepLevel then return false end

	local level = LActor.getZhuanShengLevel(actor) * 1000
	level = level + LActor.getLevel(actor)
	if level < conf.sweepLevel then return false end

	return true
end

local function onBuyCount(actor, packet)
	local id = LDataPack.readInt(packet)
	local conf = DailyFubenConfig[id]
	if conf == nil then return end

	local data = getData(actor)
	if data[id] == nil then data[id]  = {} end

	local buyCount = data[id].buyCount or 0
	local reservedCount = data[id].reservedCount or 0
	local usedCount = data[id].usedCount or 0

	local leftCount = buyCount + reservedCount + conf.freeCount - usedCount
	if leftCount >= 10 then
		print("每日副本  剩余次数过多，不能购买")
		return
	end

	if buyCount >= conf.buyCount + (conf.vipBuyCount[LActor.getVipLevel(actor)] or 0) then
		print("每日副本 购买次数达到上限， actor:%d", LActor.getActorId(actor))
		return
	end

	local needMoney = conf.buyPrice[buyCount] or 0
	if needMoney > LActor.getCurrency(actor, NumericType_YuanBao) then
		print("每日副本 元宝不够 不能购买， actor:%d", LActor.getActorId(actor))
		return
	end

	LActor.changeYuanBao(actor, 0-needMoney, "buy dailyfuben count"..tostring(id))
	data[id].buyCount = buyCount + 1

	local npack =  LDataPack.allocPacket(actor,  Protocol.CMD_Fuben, Protocol.sFubenCmd_DailyFbUpdateData)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, usedCount)
	LDataPack.writeShort(npack, buyCount + 1)
	LDataPack.writeShort(npack, reservedCount)
	LDataPack.flush(npack)
end

local function onSweeping(actor,packet) 
	local id = LDataPack.readInt(packet)
	local isDouble = LDataPack.readByte(packet)
	local conf = DailyFubenConfig[id]
	if conf == nil then return end

	local data = getData(actor)
	if data[id] == nil then data[id]  = {} end

	local buyCount = data[id].buyCount or 0
	local reservedCount = data[id].reservedCount or 0
	local usedCount = data[id].usedCount or 0

	--用完免费次数才可以花元宝扫荡
	if conf.freeCount > usedCount then
		print("dailyfuben.onChallenge: freeCount not used out, fubenId:"..tostring(id)..", actorId:"..tostring(LActor.getActorId(actor)))
		return
	end

	local leftCount = buyCount + reservedCount + conf.freeCount - usedCount
	if leftCount >= 10 then
		print("dailyfuben leftCount is max, actor:%d", LActor.getActorId(actor))
		return
	end

	if buyCount >= conf.buyCount + (conf.vipBuyCount[LActor.getVipLevel(actor)] or 0) then
		print("dailyfuben buyCount is max, actor:%d", LActor.getActorId(actor))
		return
	end

	local needMoney = conf.buyPrice[buyCount] or 0
	if isDouble ~= 0 then
		if not conf.buyDoublePrice then --没有配置这个的;表示允许双倍领取
			print("dailyfuben not have doublePrice, actor:%d", LActor.getActorId(actor))
			return
		end
		needMoney = conf.buyDoublePrice[buyCount] or 0
	end

	--贵族加成
	needMoney = monthcard.updateSweepCost(actor, needMoney)

	if needMoney > LActor.getCurrency(actor, NumericType_YuanBao) then
		print("dailyfuben yuanbao insufficient, actor:%d", LActor.getActorId(actor))
		return
	end

	LActor.changeYuanBao(actor, 0-needMoney, "buy dailyfuben count")
	data[id].buyCount = buyCount + 1
	data[id].usedCount = usedCount + 1

	local npack =  LDataPack.allocPacket(actor,  Protocol.CMD_Fuben, Protocol.sFubenCmd_DailyFbUpdateData)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, usedCount + 1)
	LDataPack.writeShort(npack, buyCount + 1)
	LDataPack.writeShort(npack, reservedCount)
	LDataPack.writeByte(npack, data[id].isClear or 0)
	LDataPack.flush(npack)

	local rewards = drop.dropGroup(getDropIdByLv(LActor.getLevel(actor), conf))
	if isDouble ~= 0 then
		--给出双倍奖励
		for _,v in ipairs(rewards) do
			v.count = v.count + v.count
		end
	end
	LActor.giveAwards(actor, rewards , "dailyfuben sweeping rewards")
	
	local fbId = getFbIdByLv(actor, conf)
	actorevent.onEvent(actor,aeEnterFuben,fbId,false)
	actorevent.onEvent(actor,aeFinishFuben,fbId,InstanceConfig[fbId].type)
	actorevent.onEvent(actor,aeDayFuBenSweep)

end

local function onChallenge(actor, packet)
	local actorId = LActor.getActorId(actor)
	local id = LDataPack.readInt(packet)
	--检查次数
	local conf = DailyFubenConfig[id]
	if conf == nil then return end

	--if conf.levelLimit > LActor.getChapterLevel(actor) then
    if conf.levelLimit > LActor.getLevel(actor) then
		print("dailyfuben.onChallenge check level failed. actor:"..LActor.getActorId(actor)..", id:"..id)
		return
	end
    --if conf.zsLevel > LActor.getZhuanShengLevel(actor) then
     --   print("daily fuben check zslevel failed. actor:%d, id:%d", LActor.getActorId(actor), id)
      --  return
    --end
	
	if conf.monthcard and not monthcard.isOpenMonthCard(actor) then
		print("dailyfuben.onChallenge check monthcard failed. actor:"..LActor.getActorId(actor)..", id:"..id)
		return
	end
	if conf.privilege and not monthcard.isOpenPrivilege(actor) then
		print("dailyfuben.onChallenge check privilege failed. actor:"..LActor.getActorId(actor)..", id:"..id)
		return
	end
	if conf.specialCard and not privilegemonthcard.isOpenPrivilegeCard(actor) then
		print("dailyfuben.onChallenge check specialCard failed. actor:"..LActor.getActorId(actor)..", id:"..id)
		return
	end

	local data = getData(actor)
	if data[id] == nil then data[id] = {} end
	local usedCount = data[id].usedCount or 0
	local buyCount = data[id].buyCount or 0
	local reservedCount = data[id].reservedCount or 0

	if buyCount + conf.freeCount + reservedCount - usedCount <= 0 then
		print("daily fuben check count failed. actor:%d, id:%d", LActor.getActorId(actor), id)
		return
	end

	if LActor.isInFuben(actor) then
		print("daily fuben check fuben failed .actor is in fuben. actor: ".. LActor.getActorId(actor))
		return
	end

	--如果是特权且已通关该副本则直接扫荡
	if data[id].isClear and (true == privilegemonthcard.isOpenPrivilegeCard(actor) or canSweep(actor, conf))then
		--判断背包格子数
		if (conf.costType or 0) == 1 and EquipBagCount > LActor.getEquipBagSpace(actor) then
			print("dailyfuben.onChallenge: equip bag not enough, id:"..tostring(actorId))
			return
		end

		--大于或等于免费次数则不能扫荡
		if conf.freeCount <= usedCount then
			print("dailyfuben.onChallenge: freeCount limit, fubenId:"..tostring(id)..", actorId:"..tostring(actorId))
			return
		end

		data[id].usedCount = usedCount + 1

		local rewards = drop.dropGroup(getDropIdByLv(LActor.getLevel(actor), conf))
		LActor.giveAwards(actor, rewards, "privilege sweeping")
		local fbId = getFbIdByLv(actor, conf)
		actorevent.onEvent(actor,aeEnterFuben,fbId,false)
		actorevent.onEvent(actor,aeFinishFuben,fbId,InstanceConfig[fbId].type)
		actorevent.onEvent(actor,aeDayFuBenSweep)
	else
		--获取副本Id
		local fbId = getFbIdByLv(actor, conf)
		if not fbId then
			print(LActor.getActorId(actor).." dailyfuben.onChallenge, fbId is nil, actor_lv:"..LActor.getLevel(actor)..",id:"..id)
			return
		end
		--创建副本
		local hfuben = Fuben.createFuBen(fbId)
		if hfuben == 0 then
			print("create dailyfuben failed."..conf.id)
			return
		end
		
		--记录进入前的数据, 在副本里有可能升级
		local ins = instancesystem.getInsByHdl(hfuben)
		if ins ~= nil then
			ins.data.did = conf.id
			ins.data.lv = LActor.getLevel(actor)
		end
		--进入副本
		LActor.enterFuBen(actor, hfuben)
		
		--扣次数
	    if (conf.costType or 0) == 0 then
	        data[id].usedCount = usedCount + 1
	    end
	end

	--通知客户端更新每日副本信息
	local npack =  LDataPack.allocPacket(actor,  Protocol.CMD_Fuben, Protocol.sFubenCmd_DailyFbUpdateData)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, data[id].usedCount or 0)
	LDataPack.writeShort(npack, buyCount)
	LDataPack.writeShort(npack, reservedCount)
	LDataPack.writeByte(npack, data[id].isClear or 0)
	LDataPack.flush(npack)
end

local function onBossWin(ins)
	local actor = ins:getActorList()[1]
	if actor == nil then print("can't find actor") return end --胜利的时候不可能找不到吧

	local conf = DailyFubenConfig[ins.data.did]
	if conf == nil then 
		print("ins.data.did:"..ins.data.did.." not have DailyFubenConfig")
		return 
	end

    local data = getData(actor)
    if data == nil then return end

    --记录通关
    if data[ins.data.did] then data[ins.data.did].isClear = 1 end

	local id = ins.data.did
    if (conf.costType or 0) == 1 then
        if data[id] == nil then data[id] = {} end
        data[id].usedCount = (data[id].usedCount or 0) + 1

        local npack =  LDataPack.allocPacket(actor,  Protocol.CMD_Fuben, Protocol.sFubenCmd_DailyFbUpdateData)

        LDataPack.writeInt(npack, id)
        LDataPack.writeShort(npack, data[id].usedCount or 0)
        LDataPack.writeShort(npack, data[id].databuyCount or 0)
        LDataPack.writeShort(npack, data[id].reservedCount or 0)
        LDataPack.writeByte(npack, data[id].isClear or 0)
        LDataPack.flush(npack)
    end

	local rewards = nil
	
	--附加首次通关掉落
	if conf.firstExDropId then
        if data.passed == nil then data.passed = {} end
		if not data.passed[id] then
			data.passed[id] = 1
			local job = LActor.getJob(actor)
			local did = conf.firstExDropId[job]
			if did then
				rewards = drop.dropGroup(did)
			end
		end
	end
	
	if not rewards then
		rewards = drop.dropGroup(getDropIdByLv(ins.data.lv, conf))
	end
	
	instancesystem.setInsRewards(ins, actor, rewards)
	if conf.bossId then
		actorevent.onEvent(actor,aeDayFuBenWin, conf.id, conf.bossId)
	end
end

local function onBossLose(ins)
	print("dailyfuben.onBossLose")
	local actor = ins:getActorList()[1]
	if actor == nil then return end

	instancesystem.setInsRewards(ins, actor, nil)
end

local function onGetRewards(ins, actor)
    if ins.data.did == nil then return end
    local conf = DailyFubenConfig[ins.data.did]
    if conf == nil then return end
    if conf.rewardNotice == nil then return end
    local info = ins.actor_list[LActor.getActorId(actor)]
    if info == nil or info.rewards == nil then return end
    for _, v in ipairs(info.rewards) do
        if v.type == AwardType_Item and ItemConfig[v.id] and ItemConfig[v.id].needNotice == 1 then
            noticemanager.broadCastNotice(conf.rewardNotice,
            LActor.getActorName(LActor.getActorId(actor)), item.getItemDisplayName(v.id))
        end
    end
end

local function onFitterRewards(ins, actor, rewards)
	if ins.data.did == nil then return false end
    local conf = DailyFubenConfig[ins.data.did]
	if conf == nil then return false end
	if (conf.ybRec or 0) <= 0 then return true end
	--判断钱是否足够
	local yb = LActor.getCurrency(actor, NumericType_YuanBao)
    if yb < (conf.ybRec or 0) then
        return false
    end
	--扣钱
    LActor.changeYuanBao(actor, 0-conf.ybRec, "dailyfuben rec reward did:"..ins.data.did)
	return true
end

function gmcleanfbcount(actor)
	local conf = DailyFubenConfig
	local data = getData(actor)
	if conf == nil then return end

	for _, conf in pairs(DailyFubenConfig) do
		if data[conf.id] == nil then data[conf.id] = {} end
		local usedCount = data[conf.id].usedCount or 0
		local leftCount = (data[conf.id].buyCount or 0)	 + (data[conf.id].reservedCount or 0)
		if usedCount > conf.freeCount then
			leftCount = leftCount - (usedCount - conf.freeCount)
		end

		data[conf.id] = {reservedCount = leftCount }
	end

	if not login then
		onLogin(actor)
	end
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)

netmsgdispatcher.reg(p.CMD_Fuben, p.cFubenCmd_DailyFbChallenge, onChallenge)
netmsgdispatcher.reg(p.CMD_Fuben, p.cFubenCmd_DailyFbBuyCount, onSweeping)

local function regFbEvent(fbId)
	insevent.registerInstanceWin(fbId, onBossWin)
	insevent.registerInstanceLose(fbId, onBossLose)
	insevent.registerInsFittertanceGetRewards(fbId, onFitterRewards)
    insevent.registerInstanceGetRewards(fbId, onGetRewards)
end

for _, v in pairs(DailyFubenConfig) do
	if type(v.fbId) == "table" then
		for _,cfg in ipairs(v.fbId) do
			regFbEvent(cfg.id)
		end
	else
		regFbEvent(v.fbId)
	end
end
