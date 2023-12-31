
--[[
data define:
        cumulation  活动内累计充值金额
        todayVal	今天充值金额
        days[k]     k为配置索引，value为满足该配置金额的累计充值天数，方便扩展
        rewardsRecord  是否已领取了奖励，按位读取
    }
--]]

module("psubactivitytype3", package.seeall)

local p = Protocol
local subType = 3
local daySecond = 24 * 60 * 60

local function onReCharge(id, conf)
	return function(actor, val)
		-- 判断活动是否开启过，未开启的活动不处理
		if not pactivitysystem.isPActivityOpened(actor, id) then
			return
		end
		if pactivitysystem.isPActivityEnd(actor, id) then return end

		local var = pactivitysystem.getSubVar(actor, id)
		local lastVal = var.todayVal or 0    --之前的充值金额
		var.todayVal = lastVal + val         --最新的充值金额

		if var.days == nil then var.days = {} end

		var.cumulation = (var.cumulation or 0) + val

		for k,v in pairs(conf) do
			if v.type == 1 then
				if lastVal < v.val and var.todayVal >= v.val then var.days[k] = (var.days[k] or 0) + 1 end
			end
		end

		pactivitysystem.sendActivityData(actor, id)

	end
end

local function onReChargeNewDay(id, conf)
	return function(actor)
		-- 判断活动是否开启过，未开启的活动不处理
		if not pactivitysystem.isPActivityOpened(actor, id) then
			return
		end
		if pactivitysystem.isPActivityEnd(actor, id) then return end

		local var = activitysystem.getSubVar(actor, id)
		var.todayVal = 0
	end
end

--获取活动当前是第几天
local function getActivityBeginDay(actor, id)
	local beginTime = pactivitysystem.getBeginTime(actor, id)
	return math.ceil((System.getNowTime() - beginTime-20) / daySecond)
end

local function checkCanAward(actor, var, k,v, id)
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
				local days = getActivityBeginDay(actor, id)
				if days == v.day then return true end
				print("psubactivitytype3.checkCanAward:type 3 error, id:"..tostring(id)..", begindays:"..tostring(days)..", day:"..tostring(v.day))
			else
				print("psubactivitytype3.checkCanAward:id is nil")
			end
			return false
		end
	end
	return false
end

local function onReChargeLogin(id, conf)
	return function(actor)
		-- 判断活动是否开启过，未开启的活动不处理
		if not pactivitysystem.isPActivityOpened(actor, id) then
			return
		end
		if pactivitysystem.isPActivityEnd(actor, id) then
			local var = pactivitysystem.getSubVar(actor, id)

			local aId = LActor.getActorId(actor)
			for k,v in pairs(conf) do
				if checkCanAward(actor, var, k,v,id) and not System.bitOPMask(var.rewardsRecord or 0, k) then
					var.rewardsRecord = System.bitOpSetMask(var.rewardsRecord or 0, k, true)
					--发邮件
					local mailData = {head=v.mailInfo.head, context=v.mailInfo.context, tAwardList=v.rewards}
					mailsystem.sendMailById(aId, mailData)
					print("psubactivitytype3.onReChargeLogin sendmail,actor:" .. LActor.getActorId(actor) .. ",id:" .. id .. ",k:" .. k)
				end
			end
			var = nil
		end
	end
end
--======================其他辅助函数 ========== end

local function writeRecord(npack, record, conf)
	if nil == record then record = {} end
	LDataPack.writeShort(npack, #conf)
	local days = record.days or {}
	for i=1, #conf do LDataPack.writeShort(npack, days[i] or 0) end
	LDataPack.writeInt(npack, record.todayVal or 0)
	LDataPack.writeInt(npack, record.cumulation or 0)
	LDataPack.writeInt(npack, record.rewardsRecord or 0)
end

local function getReward(id, typeconfig, actor, record, packet)
	local actorId = LActor.getActorId(actor)
	local idx = LDataPack.readShort(packet)
    local conf = typeconfig[id]
    if nil == conf or nil == conf[idx] then
		print("psubactivitytype3.getReward:conf is nil, id:"..tostring(id)..", actorId:"..tostring(actorId))
		return
	end

	--是否已领
    if System.bitOPMask(record.rewardsRecord or 0, idx) then
    	print("psubactivitytype3.getReward:already get reward, index:"..tostring(idx)..", actorId:"..tostring(actorId))
    	return
    end

	--是否可以领
    if not checkCanAward(actor, record, idx, conf[idx], id) then
    	print("psubactivitytype3.getReward:can not get reward, index:"..tostring(idx)..", actorId:"..tostring(actorId))
    	return
    end

    if not LActor.canGiveAwards(actor, conf[idx].rewards) then
		print("psubactivitytype3.getReward:canGiveAwards is false, actorId:"..tostring(actorId))
		return
	end

    record.rewardsRecord = System.bitOpSetMask(record.rewardsRecord or 0, idx, true)
    LActor.giveAwards(actor, conf[idx].rewards, "psubtype3 rewards, idx:"..tostring(idx)..",type:"..tostring(conf[idx].type))

   pactivitysystem.sendActivityData(actor, id)
end

local function initFunc(id, conf)
	actorevent.reg(aeRecharge, onReCharge(id, conf))
	actorevent.reg(aeNewDayArrive, onReChargeNewDay(id, conf))
	actorevent.reg(aeUserLogin, onReChargeLogin(id, conf))
end

pactivitysystem.regConf(subType, PActivity3Config)
pactivitysystem.regInitFunc(subType, initFunc)
pactivitysystem.regWriteRecordFunc(subType, writeRecord)
pactivitysystem.regGetRewardFunc(subType, getReward)

