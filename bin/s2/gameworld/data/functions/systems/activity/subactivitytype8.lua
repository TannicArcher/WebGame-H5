--活动副本
module("subactivitytype8", package.seeall)

local p = Protocol
local subType = 8

local noticeId = 164

--发送活动信息
local function writeRecord(npack, record, config, id)
	if npack == nil then return end
	if record == nil then record = {} end
	LDataPack.writeInt(npack, record.winRecord or 0)
end

--请求挑战副本
local function getReward(id, typeconfig, actor, record, packet)
	local index = LDataPack.readShort(packet)
	local config = typeconfig[id]
	if config[index] == nil then return end
	local cfg = config[index]
	if index < 0 or index > 32 then
		print(LActor.getActorId(actor).." type8 config is err, index is invalid.."..index)
		return
	end
	
	--判断是否赢过
	if System.bitOPMask(record.winRecord or 0, index) then
    	print("subactivitytype8.getReward:already get reward, index:"..tostring(index)..", actorId:".. LActor.getActorId(actor))
    	return
    end
	--判断是否满足前置条件
	if cfg.cond and not System.bitOPMask(record.winRecord or 0, cfg.cond) then
    	print("subactivitytype8.getReward:can not cond, index:"..tostring(index)..", actorId:".. LActor.getActorId(actor))
    	return
    end	
	--判断是否够元宝
	if LActor.getCurrency(actor, NumericType_YuanBao) < cfg.ybCount then
		print("subactivitytype8.getReward:not have yb, index:"..tostring(index)..", actorId:".. LActor.getActorId(actor))
		return
	end
	LActor.changeCurrency(actor, NumericType_YuanBao, -cfg.ybCount, "act type8 "..id.."_"..index)
	--创建副本
	local hfuben = Fuben.createFuBen(cfg.fbid)
	if hfuben == 0 then
		print(LActor.getActorId(actor).." subactivitytype8.getReward create fuben failed."..cfg.fbid)
		return
	end
	local ins = instancesystem.getInsByHdl(hfuben)
	if not ins then 
		print(LActor.getActorId(actor).." subactivitytype8.getReward ins is nil "..cfg.fbid)
		return
	end
	ins.data.index = index
	--设置已经通过某个副本
	record.winRecord = System.bitOpSetMask(record.winRecord or 0, index, true)
	--进入副本
	LActor.enterFuBen(actor, hfuben)
end

--副本胜利回调
local function onWinOrLose(id, conf, index)
	return function(ins)
		if ins.data.index ~= index then return end
		local actor = ins:getActorList()[1]
		if not actor then return end
		--设置副本奖励
		local cfg = conf[index]
		local rewards = drop.dropGroup(cfg.rewards)
		--判断公告
		for _, v in ipairs(rewards or {}) do
			if v.type == 1 and ItemConfig[v.id] and ItemConfig[v.id].needNotice == 1 then
				local itemName = item.getItemDisplayName(v.id)
				noticemanager.broadCastNotice(noticeId, LActor.getName(actor), itemName)
			end
		end
		--设置奖励
		instancesystem.setInsRewards(ins, actor, rewards)
	end
end

--退出副本时的处理
local function onExitFb(id, conf, index)
	return function(ins, actor)
		if ins.data.index ~= index then return end
		if ins.is_end then return end
		local cfg = conf[index]
		--发邮件
		local rewards = drop.dropGroup(cfg.rewards)
		local mailData = {head=cfg.mailInfo.head, context=cfg.mailInfo.context, tAwardList=rewards}
		mailsystem.sendMailById(LActor.getActorId(actor), mailData)
	end
end

--获取奖励之前
local function onFitterRewards(id, conf, index)
	return function(ins, actor)
		if not ins.is_end then return end
		local info = ins.actor_list[LActor.getActorId(actor)]
		if not info or info.rewards == nil then
			print(LActor.getActorId(actor).." type8.onFitterRewards not info rewards")
			return false
		end
		--背包装不下就用邮件并返回
		if not LActor.canGiveAwards(actor, info.rewards) then
			local cfg = conf[index]
			--发邮件
			local mailData = {head=cfg.mailInfo.head, context=cfg.mailInfo.context, tAwardList=info.rewards}
			mailsystem.sendMailById(LActor.getActorId(actor), mailData)
			info.rewards = nil
			return false
		end
		return true
	end	
end

--副本中下线的处理
local function onOffline(ins, actor)
    --手动调用退出副本，否则虽然会触发退出副本，但是上线会自动进入副本中
    LActor.exitFuben(actor)
end

--每日重置挑战次数
local function onReChargeNewDay(id, conf)
	return function(actor)
		if activitysystem.activityTimeIsEnd(id) then return end
		local var = activitysystem.getSubVar(actor, id)
		var.winRecord = 0
	end
end

local function initFunc(id, conf)
	for index,v in pairs(conf) do
		insevent.registerInstanceWin(v.fbid, onWinOrLose(id, conf, index))
		insevent.registerInstanceLose(v.fbid, onWinOrLose(id, conf, index))
		insevent.registerInstanceExit(v.fbid, onExitFb(id, conf, index))
		insevent.registerInstanceGetRewards(v.fbid, onFitterRewards(id, conf, index))
		insevent.registerInstanceOffline(v.fbid, onOffline)
	end
	actorevent.reg(aeNewDayArrive, onReChargeNewDay(id, conf))
end

--注册一类活动配置
subactivities.regConf(subType, ActivityType8Config)
subactivities.regInitFunc(subType, initFunc)
subactivities.regWriteRecordFunc(subType, writeRecord)
subactivities.regGetRewardFunc(subType, getReward)