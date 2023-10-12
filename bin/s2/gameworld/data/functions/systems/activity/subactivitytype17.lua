--幸运转盘
module("subactivitytype17", package.seeall)

--[[
data = {
	todayRecharge = 0,  --当天充值额
	totalScore = 0,  --已得积分
	starsRecord = {},  --已得星星数量记录
	lotteryCount = 0,  --抽奖次数
	rewardsRecord = 0,  --抽奖记录
	lotteryId = 0,  --未领取奖励id
	endTime = 0,  --本轮结束时间
}
]]

local subType = 17

local RType = {
	times = 0,--领取次数奖励
	once = 1,--转盘抽
	--tenc = 2,--十次连抽
}

local function actor_log(actor, str)
	if (not actor) or (not str) then return end
	local aid = LActor.getActorId(actor)
	print("subactivitytype17 aid:" .. aid .. " log:" .. str)
end

--获取抽奖配置
local function getLotteryConfig(id, count)
	local lotteryConf = ActivityType17_3Config[id]
	if not lotteryConf then return end
	local cfg = lotteryConf[count]
	if not cfg then
		return lotteryConf[#lotteryConf]
	end
	return cfg
end

--重置个人跨轮必清数据
local function cleanData(data)
	data.totalScore = 0
	data.starsRecord = nil
	data.lotteryCount = 0
	data.rewardsRecord = 0
	data.lotteryId = 0
end

--领取类型
local rtFunc = {
	[RType.times] = function(id, actor, record, conf)
		if not record.data.lotteryId then
			actor_log(actor, "RType.times not have reward")
			return false, 0
		end
		if System.bitOPMask(record.data.rewardsRecord or 0, record.data.lotteryId) then
			actor_log(actor, "RType.times is receive")
			return false, 0
		end
		
		local reward = conf.group[record.data.lotteryId]
		if not reward then
			actor_log(actor, "reward is nil")
			return false, 0
		end
		record.data.rewardsRecord = System.bitOpSetMask(record.data.rewardsRecord or 0, record.data.lotteryId, true)
		record.data.totalScore = record.data.totalScore - ActivityType17_2Config[id].score
		record.data.lotteryCount = (record.data.lotteryCount or 0) + 1
		LActor.giveAwards(actor, {reward}, "type17 times")  --发奖励
		--更新数据
		if reward.notice ~= nil then
			--广播
			local name = LActor.getName(actor)
			local item = string.format("%sx%d", item.getItemDisplayName(reward.id), reward.count)
			noticemanager.broadCastNotice(reward.notice, name, item)

			local gdata = activitysystem.getGlobalVar(id)
			if not gdata.record then gdata.record = {} end
			table.insert(gdata.record, {name=name, item=record.data.lotteryId})
			if #gdata.record > 20 then table.remove(gdata.record, 1) end
		end
		record.data.lotteryId = nil
		activitysystem.sendActivityData(actor, id)
		return true, 0
	end,
	[RType.once] = function(id, actor, record, conf)
		if not record.data.lotteryId or record.data.lotteryId <= 0 or record.data.lotteryId > #conf.group then
			--正常抽奖
			local randTab = {}
			local randCount = 0
			for i,v in ipairs(conf.group) do
				--判断这一次出不出
				if v.rate and v.rate > 0 then
					--判断是否已经出过
					if not System.bitOPMask(record.data.rewardsRecord or 0, i) then
						table.insert(randTab, {i=i,reward=v})
						randCount = randCount + v.rate
					end
				end
			end
			--在奖池里面随机
			if randCount <= 0 then
				actor_log(actor, "reqLottery not reward, count:"..((record.data.lotteryCount or 0)+1)..", rec:"..(record.data.rewardsRecord or 0))
				return false, 0
			end
			record.data.lotteryId = 0
			local rand = math.random(1,randCount)
			for _,v in ipairs(randTab) do
				if rand <= v.reward.rate then
					record.data.lotteryId = v.i
					break
				end
				rand = rand - v.reward.rate
			end
			if record.data.lotteryId == 0 then
				actor_log(actor, "reqLottery lotteryId=0, count:"..((record.data.lotteryCount or 0)+1)..", rec:"..(record.data.rewardsRecord or 0))
				return false, 0
			end
		end
		return true, record.data.lotteryId
	end,
}

--个人跨天
local function onNewDay(id, conf)
	return function(actor)
		if activitysystem.activityTimeIsEnd(id) then return end

		local var = activitysystem.getSubVar(actor, id)
		var.data.todayRecharge = 0  --每天清充值额

		local gdata = activitysystem.getGlobalVar(id)
		--判断是否新一轮清数据
		if gdata.endTime <= System.getToday() then
			--已到新一轮但onEngineNewDay还没执行时，玩家在线跨新一轮时可能会遇到，提前清数据
			cleanData(var.data)
			var.data.endTime = 0  --标记0表明已重置数据未更新时间
		elseif var.data.endTime == 0 then
			--提前清数据后的第二天，写回时间
			var.data.endTime = gdata.endTime
		elseif var.data.endTime ~= gdata.endTime then
			--更新一轮后玩家上线
			cleanData(var.data)
			var.data.endTime = gdata.endTime
		end
	end
end

--登录事件
local function onLogin(id, conf)
	return function(actor)
		-- 判断活动是否结束
		if activitysystem.activityTimeIsEnd(id) then return end
		local var = activitysystem.getSubVar(actor, id)
		local gdata = activitysystem.getGlobalVar(id)
		if var.data.endTime ~= 0 and var.data.endTime ~= gdata.endTime then
			--活动开始第一天或活动时间调整时可能会遇到，强制执行跨天流程
			local func = onNewDay(id, conf)
			func(actor)
		end
	end
end

--充值事件
local function onReCharge(id, conf)
	return function(actor, val)
		-- 判断活动是否结束
		if activitysystem.activityTimeIsEnd(id) then return end
		--获取活动的记录变量
		local var = activitysystem.getSubVar(actor, id)
		if not var.data then var.data = {} end
		--记录累计充值
		if var.data.todayRecharge == nil then var.data.todayRecharge = 0 end
		if var.data.starsRecord == nil then var.data.starsRecord = {} end

		local oldRecharge = var.data.todayRecharge
		var.data.todayRecharge = var.data.todayRecharge + val

		for i, v in ipairs(conf) do
			if oldRecharge < v.recharge and var.data.todayRecharge >= v.recharge and (var.data.starsRecord[i] or 0) < v.star then
				var.data.starsRecord[i] = (var.data.starsRecord[i] or 0) + 1
				var.data.totalScore = (var.data.totalScore or 0) + v.score
			end
		end

		activitysystem.sendActivityData(actor, id)
	end
end

--系统跨天
local function onEngineNewDay(id, conf)
	return function()
		local gdata = activitysystem.getGlobalVar(id)
		local today = System.getToday()
		if not gdata.endTime or gdata.endTime <= today or (gdata.endTime-today)/utils.day_sec > ActivityType17_2Config[id].days then
			--重置时间
			gdata.endTime = today + ActivityType17_2Config[id].days * utils.day_sec
		end
	end
end

--发送数据
local function writeRecord(npack, record, config, id, actor)
	if not npack then
		actor_log(actor, "writeRecord npack is nil")
		return
	end
	local count = 0
	if config ~= nil then count = #config end
	LDataPack.writeShort(npack, count)
	for i=1,count do
		LDataPack.writeShort(npack, record and record.data and record.data.starsRecord and record.data.starsRecord[i] or 0)
	end
	local gdata = activitysystem.getGlobalVar(id)
	count = #(gdata.record or {})
	LDataPack.writeShort(npack, count)
	for _,v in ipairs(gdata.record or {}) do
		LDataPack.writeString(npack, v.name or "")
		LDataPack.writeChar(npack, v.item or 0)
	end
	LDataPack.writeInt(npack, record and record.data and record.data.totalScore or 0)
	LDataPack.writeInt(npack, record and record.data and record.data.todayRecharge or 0)
	local days = 0
	local today = System.getToday()
	local mf = 0
	if gdata.endTime <= today then
		--已到新一轮但onEngineNewDay还没执行时，基本不可能
		days = ActivityType17_2Config[id].days
	else
		days, mf = math.modf((gdata.endTime - today) / utils.day_sec)
		assert(mf == 0)  --测试用
	end
	LDataPack.writeInt(npack, days)
	LDataPack.writeInt(npack, record and record.data and record.data.rewardsRecord or 0)
end

--请求抽奖/领取奖励
local function getReward(id, typeconfig, actor, record, packet)
	--判断积分是否足够
	if (record.data.totalScore or 0) < ActivityType17_2Config[id].score then
		actor_log(actor, "getReward score not enough")
		return
	end

	if LActor.getEquipBagSpace(actor) <= 0 then
		LActor.sendTipmsg(actor, "背包已满")
		return
	end

	--拿奖池
	local conf = getLotteryConfig(id, (record.data.lotteryCount or 0)+1)
	if not conf then
		actor_log(actor, "reqLottery conf is nil, id:"..tostring(id)..", count:"..tostring((record.data.lotteryCount or 0)+1))
		return
	end
	local rt = LDataPack.readShort(packet)
	local func = rtFunc[rt]
	if not func then
		actor_log(actor, "getReward not func("..rt..") id:"..id)
		return 
	end
	--local ret, index = func(id, typeconfig[id], actor, record, packet, conf)
	local ret, index = func(id, actor, record, conf)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_GetRewardResult)
	LDataPack.writeByte(npack, ret and 1 or 0)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, index or 0)
	LDataPack.writeInt(npack, record.data.rewardsRecord or 0)
	LDataPack.flush(npack)
end

--活动初始化
local function initFunc(id, conf)
	local gdata = activitysystem.getGlobalVar(id)
	local today = System.getToday()
	if not gdata.endTime or gdata.endTime <= today or (gdata.endTime-today)/utils.day_sec > ActivityType17_2Config[id].days then
		--重置时间
		gdata.endTime = today + ActivityType17_2Config[id].days * utils.day_sec
	end
	actorevent.reg(aeUserLogin, onLogin(id, conf))
	actorevent.reg(aeRecharge, onReCharge(id, conf))
	actorevent.reg(aeNewDayArrive, onNewDay(id, conf))
	engineevent.regNewDay(onEngineNewDay(id, conf))
end

subactivities.regConf(subType, ActivityType17_1Config)
subactivities.regInitFunc(subType, initFunc)
subactivities.regWriteRecordFunc(subType, writeRecord)
subactivities.regGetRewardFunc(subType, getReward)
