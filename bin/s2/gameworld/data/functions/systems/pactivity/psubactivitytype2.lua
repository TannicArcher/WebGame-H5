--充值限购活动
module("psubactivitytype2", package.seeall)


local p = Protocol
local subType = 2
local function writeRewardRecord(npack, record, config, id, actor)
	if npack == nil then return end
	if config == nil then
		LDataPack.writeShort(npack, 0)
		return
	end
	-- local gdata = activitysystem.getGlobalVar(id)
	local count = #config
	LDataPack.writeShort(npack, count)
	for i=1,count do
		LDataPack.writeShort(npack, record and record.data and record.data.rewardsRecord and record.data.rewardsRecord[i] or 0)
		-- LDataPack.writeShort(npack, gdata and gdata.rewardsRecord and gdata.rewardsRecord[i] or 0)
		LDataPack.writeShort(npack,0)
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

local function getLiBaoReward(id, typeconfig, actor, record, packet)
	local index = LDataPack.readShort(packet)
	local config = typeconfig[id]

	--初始化记录
	if record.data == nil then record.data = {} end
	if record.data.rewardsRecord == nil then record.data.rewardsRecord = {} end
	--全局变量
	-- local gdata = activitysystem.getGlobalVar(id)
	-- if gdata.rewardsRecord == nil then gdata.rewardsRecord = {} end

	-- local ret = checkLiBaoReward(index, config, actor, record, gdata)
	local ret = checkLiBaoReward(index, config, actor, record, {})

	if ret then
		--记录
		record.data.rewardsRecord[index] = (record.data.rewardsRecord[index] or 0) + 1
		-- gdata.rewardsRecord[index] = (gdata.rewardsRecord[index] or 0) + 1

		LActor.changeCurrency(actor, config[index].currencyType or 2, -config[index].price, "pact type2 "..id.."_"..index)
		LActor.giveAwards(actor, config[index].rewards, "pactivity type2 rewards")
	end

	--公告广播
	if config[index].notice then
		noticemanager.broadCastNotice(config[index].notice, LActor.getName(actor))
	end
	
	local npack = LDataPack.allocPacket(actor, p.CMD_PActivity, p.sPActivityCmd_GetRewardResult)
	LDataPack.writeByte(npack, ret and 1 or 0)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, index)
	LDataPack.writeInt(npack, record.data.rewardsRecord[index] or 0)
	-- LDataPack.writeInt(npack, gdata.rewardsRecord[index] or 0)
	LDataPack.writeInt(npack, 0)
	LDataPack.flush(npack)
end

local function onReCharge(id, conf)
	return function(actor, val)
		-- 判断活动是否开启过，未开启的活动不处理
		if not pactivitysystem.isPActivityOpened(actor, id) then
			return
		end
		-- 判断活动是否结束
		if pactivitysystem.isPActivityEnd(actor, id) then return end
		--获取活动的记录变量
		local var = pactivitysystem.getSubVar(actor, id)
		if not var.data then var.data = {} end
		--记录累计充值
		if var.data.totalRecharge == nil then var.data.totalRecharge = 0 end
		var.data.totalRecharge = var.data.totalRecharge + val
		pactivitysystem.sendActivityData(actor, id)
	end
end

local function initFunc(id, conf)
	actorevent.reg(aeRecharge, onReCharge(id, conf))
end

--注册一类活动配置
pactivitysystem.regConf(subType, PActivity2Config)
pactivitysystem.regInitFunc(subType, initFunc)
pactivitysystem.regWriteRecordFunc(subType, writeRewardRecord)
pactivitysystem.regGetRewardFunc(subType, getLiBaoReward)

