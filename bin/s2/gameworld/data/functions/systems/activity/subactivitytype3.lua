
--[[
data define:
        cumulation  活动内累计充值金额
        todayVal	今天充值金额
        days[k]     k为配置索引，value为满足该配置金额的累计充值天数，方便扩展
        rewardsRecord  是否已领取了奖励，按位读取
    }
--]]

module("subactivitytype3", package.seeall)

local p = Protocol
local subType = 3
local daySecond = 24 * 60 * 60

-- 发送单笔奖励，需要改变奖励个数
local function sendMailSingleReward( conf, actor, nCnt)
	--发邮件
	local mailData = {head=conf.mailInfo.head, context=conf.mailInfo.context, tAwardList=utils.table_clone(conf.rewards)}
	-- 改变奖励数量
	for k, v in pairs(mailData.tAwardList) do
		v.count = nCnt * v.count
	end
	mailsystem.sendMailById(LActor.getActorId(actor), mailData)
end

local function onReCharge(id, conf)
	return function(actor, val)
		if activitysystem.activityTimeIsEnd(id) then return end

		-- 单笔逻辑类型为4，直接邮件奖励
		for k, v in pairs(conf) do -- k为奖励序号
			if v.type == 4 then
				local nCnt = math.floor(val / v.val)
				if nCnt <= 0 then 
					print(LActor.getActorId(actor) .. ' subactivitytype3.onReCharge nCnt:' .. nCnt )
				else
					-- 发送单笔充值邮件奖励
					sendMailSingleReward(v, actor, nCnt)
				end
			end
		end

		local var = activitysystem.getSubVar(actor, id)
		local lastVal = var.todayVal or 0    --之前的充值金额
		var.todayVal = lastVal + val         --最新的充值金额

		if var.days == nil then var.days = {} end

		var.cumulation = (var.cumulation or 0) + val

		for k,v in pairs(conf) do
			if v.type == 1 then
				if lastVal < v.val and var.todayVal >= v.val then var.days[k] = (var.days[k] or 0) + 1 end
			end
		end

		activitysystem.sendActivityData(actor, id)
	end
end

local function onReChargeNewDay(id, conf)
	return function(actor)
		if activitysystem.activityTimeIsEnd(id) then return end

		local var = activitysystem.getSubVar(actor, id)
		var.todayVal = 0
	end
end

--获取活动当前是第几天
local function getActivityBeginDay(id)
	local beginTime = activitysystem.getBeginTime(id)
	return math.ceil((System.getNowTime() - beginTime-20) / daySecond)
end

local function checkCanAward(var, k,v, id)
	if v.type == 1 then
		if (v.day or 0) <= (var.days and var.days[k] or 0) then
			return true
		end
	elseif v.type == 2 then
		if (var.cumulation or 0) >= (v.val or 0) then
			return true
		end
	elseif v.type == 3 then
		if (var.todayVal or 0) >= (v.val or 0) then
			if id then
				local days = getActivityBeginDay(id)
				if days == v.day then return true end
				print("subactivitytype3.checkCanAward:type 3 error, id:"..tostring(id)..", begindays:"..tostring(days)..", day:"..tostring(v.day))
			else
				print("subactivitytype3.checkCanAward:id is nil")
			end
			return false
		end
	end
	return false
end

local function onReChargeLogin(id, conf)
	return function(actor)
		if activitysystem.activityTimeIsEnd(id) then
			local var = activitysystem.getSubVar(actor, id)

			local aId = LActor.getActorId(actor)
			for k,v in pairs(conf) do
				if checkCanAward(var, k,v,id) and not System.bitOPMask(var.rewardsRecord or 0, k) then
					var.rewardsRecord = System.bitOpSetMask(var.rewardsRecord or 0, k, true)
					--发邮件
					local mailData = {head=v.mailInfo.head, context=v.mailInfo.context, tAwardList=v.rewards}
					mailsystem.sendMailById(aId, mailData)
				end
			end
			var = nil
		end
	end
end
--======================其他辅助函数 ========== end
-- 函数参数添加id,actor,补充完整
local function writeRecord(npack, record, conf, id, actor)
	-- 配置中type为4时，是单笔充值判定,奖励序号一定是从1开始，所以type为4时，必须保证在最后
	local nMax = 0
	for i=1,#conf do
		if conf[i].type == 4 then break end
		nMax = i
	end

	if nil == record then record = {} end
	-- LDataPack.writeShort(npack, #conf)
	LDataPack.writeShort(npack, nMax)
	local days = record.days or {}
	-- for i=1, #conf do LDataPack.writeShort(npack, days[i] or 0) end
	for i=1, nMax do LDataPack.writeShort(npack, days[i] or 0) end
	LDataPack.writeInt(npack, record.todayVal or 0)
	LDataPack.writeInt(npack, record.cumulation or 0)
	LDataPack.writeInt(npack, record.rewardsRecord or 0)
end

local function getReward(id, typeconfig, actor, record, packet)
	local actorId = LActor.getActorId(actor)
	local idx = LDataPack.readShort(packet)
    local conf = typeconfig[id]
    if nil == conf or nil == conf[idx] then
		print("subactivitytype3.getReward:conf is nil, id:"..tostring(id)..", actorId:"..tostring(actorId))
		return
	end

	-- 单笔充值奖励，不能由客户端领取奖励
	if conf[idx].type == 4 then
		print("subactivitytype3.getReward isType4, index:"..tostring(idx)..", actorId:"..tostring(actorId))
		return
	end

	--是否已领
    if System.bitOPMask(record.rewardsRecord or 0, idx) then
    	print("subactivitytype3.getReward:already get reward, index:"..tostring(idx)..", actorId:"..tostring(actorId))
    	return
    end

	--是否可以领
    if not checkCanAward(record, idx, conf[idx], id) then
    	print("subactivitytype3.getReward:can not get reward, index:"..tostring(idx)..", actorId:"..tostring(actorId))
    	return
    end

    if not LActor.canGiveAwards(actor, conf[idx].rewards) then
		print("subactivitytype3.getReward:canGiveAwards is false, actorId:"..tostring(actorId))
		return
	end

    record.rewardsRecord = System.bitOpSetMask(record.rewardsRecord or 0, idx, true)
    LActor.giveAwards(actor, conf[idx].rewards, "subtype3 rewards, idx:"..tostring(idx)..",type:"..tostring(conf[idx].type))

   activitysystem.sendActivityData(actor, id)
end

local function initFunc(id, conf)
	actorevent.reg(aeRecharge, onReCharge(id, conf))
	actorevent.reg(aeNewDayArrive, onReChargeNewDay(id, conf))
	actorevent.reg(aeUserLogin, onReChargeLogin(id, conf))
end

subactivities.regConf(subType, ActivityType3Config)
subactivities.regInitFunc(subType, initFunc)
subactivities.regWriteRecordFunc(subType, writeRecord)
subactivities.regGetRewardFunc(subType, getReward)

