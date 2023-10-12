--充值限购活动
module("subactivitytype2", package.seeall)


local p = Protocol
local subType = 2
local function writeRewardRecord(npack, record, config, id, actor)
	if npack == nil then return end
	if config == nil then
		LDataPack.writeShort(npack, 0)
		return
	end
	local gdata = activitysystem.getGlobalVar(id)
	local count = #config
	LDataPack.writeShort(npack, count)
	for i=1,count do
		LDataPack.writeShort(npack, record and record.data and record.data.rewardsRecord and record.data.rewardsRecord[i] or 0)
		LDataPack.writeShort(npack, gdata and gdata.rewardsRecord and gdata.rewardsRecord[i] or 0)
		LDataPack.writeInt(npack, gdata and gdata.crossRewardsRecord and gdata.crossRewardsRecord[i] or 0)
		LDataPack.writeInt(npack, gdata and gdata.crossRewardRec and gdata.crossRewardRec[i] or 0)
	end
	LDataPack.writeInt(npack, record and record.data and record.data.totalRecharge or 0)
end

local function checkLiBaoReward(index, config, actor, record, gdata)
	if config[index] == nil then
		return false
	end
	local cfg = config[index]
	if index < 0 or index > 32 then
		print("config is err, index is invalid.."..index)
		return false
	end

	if LActor.getVipLevel(actor) < cfg.vip then
		return false
	end
	
	if (record.data.totalRecharge or 0) < (cfg.needRecharge or 0) then
		return false
	end
	
	--价钱
	if LActor.getCurrency(actor, cfg.currencyType or 2) < cfg.price then
		return false
	end

	--个人购买次数
	if cfg.count and (record.data.rewardsRecord[index] or 0)  >= cfg.count then
		return false
	end

	--全服购买次数
	if cfg.scount and gdata.rewardsRecord and (gdata.rewardsRecord[index] or 0)  >= cfg.scount then
		return false
	end

	--判断一天的限时
	if cfg.limitTime and #cfg.limitTime >= 2 then
		local h, m, s = System.getTime()
		if cfg.limitTime[1] > h or (cfg.limitTime[1] == h and cfg.limitTime[2] > m)  then
			return false
		end
	end

	if not LActor.canGiveAwards(actor, cfg.rewards) then
		return false
	end

	return true
end

local function getCrossCountReward(id, config, actor, record, index, subIdx)
	if config[index] == nil then
		print(LActor.getActorId(actor).." subactivitytype2.getCrossCountReward config is nil index:"..index)
		return
	end
	local conf = config[index]
	if record.data == nil then record.data = {} end
	if record.data.rewardsRecord == nil then record.data.rewardsRecord = {} end
	--判断是否有购买过这个礼包
	if (record.data.rewardsRecord[index] or 0) <= 0 then
		print(LActor.getActorId(actor).." subactivitytype2.getCrossCountReward not have buy index:"..index)
		return
	end
	--判断配置是否存在
	local cfg = conf.countReward and conf.countReward[subIdx]
	if not cfg then
		print(LActor.getActorId(actor).." subactivitytype2.getCrossCountReward cfg is nil index:"..index..",subIdx:"..subIdx)
		return
	end
	if not record.data.crossRewardRec then record.data.crossRewardRec = {} end
	--判断这个奖励是否已经领取过
	if System.bitOPMask(record.data.crossRewardRec[index] or 0, subIdx) then
		print(LActor.getActorId(actor).." subactivitytype2.getCrossCountReward is double rec index:"..index..",subIdx:"..subIdx)
		return
	end
	--判断次数是否满足条件
	local gdata = activitysystem.getGlobalVar(id)
	if gdata.crossRewardsRecord == nil then gdata.crossRewardsRecord = {} end --跨服总购买次数
	if gdata.rewardsRecord == nil then gdata.rewardsRecord = {} end --单服总购买次数
	if math.max((gdata.rewardsRecord[index] or 0), (gdata.crossRewardsRecord[index] or 0)) < cfg.count then
		print(LActor.getActorId(actor).." subactivitytype2.getCrossCountReward count limit index:"..index..",subIdx:"..subIdx)
		return
	end
	--获取奖励
	LActor.giveAwards(actor, cfg.reward, "act type2 cbcr")
	--记录已经领取
	record.data.crossRewardRec[index] = System.bitOpSetMask(record.data.crossRewardRec[index] or 0, subIdx, true)
end

local function getLiBaoReward(id, typeconfig, actor, record, packet)
	local index = LDataPack.readShort(packet)
	local config = typeconfig[id]
	local subIdx = LDataPack.readShort(packet)
	--全局变量
	local gdata = activitysystem.getGlobalVar(id)
	if subIdx and subIdx > 0 then --获取跨服购买次数奖励
		getCrossCountReward(id, config, actor, record, index, subIdx)
	else --正常购买礼包
		--初始化记录
		if record.data == nil then record.data = {} end
		if record.data.rewardsRecord == nil then record.data.rewardsRecord = {} end
		if gdata.rewardsRecord == nil then gdata.rewardsRecord = {} end

		local ret = checkLiBaoReward(index, config, actor, record, gdata)

		if ret then
			--记录
			record.data.rewardsRecord[index] = (record.data.rewardsRecord[index] or 0) + 1 --个人购买次数
			gdata.rewardsRecord[index] = (gdata.rewardsRecord[index] or 0) + 1 --全服购买次数

			LActor.changeCurrency(actor, config[index].currencyType or 2, -config[index].price, "act type2 "..id.."_"..index)
			LActor.giveAwards(actor, config[index].rewards, "activity type2 rewards")

			--发购买次数到跨服
			if config[index].countReward and csbase.hasCross then
				local npack = LDataPack.allocPacket()
				LDataPack.writeByte(npack, CrossSrvCmd.SCActivityCmd)
				LDataPack.writeByte(npack, CrossSrvSubCmd.SCActivityCmd_Type2SendNum)

				LDataPack.writeInt(npack, id)
				LDataPack.writeShort(npack, index)

				System.sendPacketToAllGameClient(npack, csbase.GetBattleSvrId(bsBattleSrv))
			end
		end

		--公告广播
		if config[index].notice then
			noticemanager.broadCastNotice(config[index].notice, LActor.getName(actor))
		end
	end
	local npack = LDataPack.allocPacket(actor, p.CMD_Activity, p.sActivityCmd_GetRewardResult)
	LDataPack.writeByte(npack, ret and 1 or 0)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, index)
	LDataPack.writeInt(npack, record.data.rewardsRecord[index] or 0)
	LDataPack.writeInt(npack, gdata.rewardsRecord[index] or 0)
	LDataPack.writeInt(npack, gdata and gdata.crossRewardsRecord and gdata.crossRewardsRecord[i] or 0)
	LDataPack.writeInt(npack, gdata and gdata.crossRewardRec and gdata.crossRewardRec[i] or 0)
	LDataPack.flush(npack)
end

local function onReCharge(id, conf)
	return function(actor, val)
		-- 判断活动是否结束
		if activitysystem.activityTimeIsEnd(id) then return end
		--获取活动的记录变量
		local var = activitysystem.getSubVar(actor, id)
		if not var.data then var.data = {} end
		--记录累计充值
		if var.data.totalRecharge == nil then var.data.totalRecharge = 0 end
		var.data.totalRecharge = var.data.totalRecharge + val
		activitysystem.sendActivityData(actor, id)
	end
end

local function onType2SendNum(sId, sType, dp)
	if System.isCommSrv() then
		local id = LDataPack.readInt(dp)
		local index = LDataPack.readShort(dp)
		local count = LDataPack.readInt(dp)
		--记录跨服区的总购买次数
		local gdata = activitysystem.getGlobalVar(id)
		if gdata.crossRewardsRecord == nil then gdata.crossRewardsRecord = {} end
		gdata.crossRewardsRecord[index] = count
		print("subactivitytype2.onType2SendNum id:"..id..",index:"..index..",count:"..count)
	else
		local id = LDataPack.readInt(dp)
		local index = LDataPack.readShort(dp)
		--购买次数+1
		local svar = System.getStaticVar()
		if not svar then return end
		if not svar.type2BuyNum then svar.type2BuyNum = {} end
		if not svar.type2BuyNum[id] then svar.type2BuyNum[id] = {} end
		svar.type2BuyNum[id][index] = (svar.type2BuyNum[id][index] or 0) + 1
		print("subactivitytype2.onType2SendNum id:"..id..",index:"..index)
		--把总数发给每个单服
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCActivityCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCActivityCmd_Type2SendNum)
		LDataPack.writeInt(npack, id)
		LDataPack.writeShort(npack, index)
		LDataPack.writeInt(npack, svar.type2BuyNum[id][index])
		System.sendPacketToAllGameClient(npack, 0)
	end
end

local function initFunc(id, conf)
	actorevent.reg(aeRecharge, onReCharge(id, conf))
end

--注册一类活动配置
subactivities.regConf(subType, ActivityType2Config)
subactivities.regInitFunc(subType, initFunc)
subactivities.regWriteRecordFunc(subType, writeRewardRecord)
subactivities.regGetRewardFunc(subType, getLiBaoReward)

csmsgdispatcher.Reg(CrossSrvCmd.SCActivityCmd, CrossSrvSubCmd.SCActivityCmd_Type2SendNum, onType2SendNum) --跨服信息,礼包购买次数
