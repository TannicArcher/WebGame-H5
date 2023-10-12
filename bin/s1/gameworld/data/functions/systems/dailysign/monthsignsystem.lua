module("monthsignsystem", package.seeall)

--[[
rewardDay 已签到天数
isReward 当天是否已签到 0未签到，1已签到
signDays  --累计签到天数,会重置为0
rewardIndex --已领取累计签到奖励的最新配置索引
--]]

--获取玩家月签到信息
local function getMonthSignData(actor)
	local var = LActor.getStaticVar(actor) 
	if nil == var.monthSign then var.monthSign = {} end
	
	return var.monthSign
end

--初始化签到信息
local function initMonthSignData(actor)
	local var = getMonthSignData(actor)
	var.rewardDay = 0
end

--初始化连续签到信息
local function initSignDayData(actor)
	local var = getMonthSignData(actor)
	var.signDays = 0
	var.rewardIndex = 0
end

--检测开放等级
local function checkOpenLevel(actor)
	local level = LActor.getLevel(actor)
	if (level < (MonthSignBaseConfig.openLevel or 0)) then return false end

	return true
end

--检测是否已签到
local function checkMonthSign(actor)
	local var = getMonthSignData(actor)
	if 0 == (var.isReward or 0) then return false end

	return true
end

--检测累计签到奖励是否全部领取完
local function checkSignDaysRewardIsFinish(actor)
	local var = getMonthSignData(actor)
	if #MonthSignDaysConfig <= (var.rewardIndex or 0) then return true end

	return false
end

--判断签到是否结束了一个循环
local function checkSignIsFinish(actor)
	local var = getMonthSignData(actor)
	if #MonthSignConfig <= (var.rewardDay or 0) then return true end

	return false
end

--获取签到天数对应的配置
local function getDayConfig(signDay)
	local dayConfig = MonthSignConfig[signDay]
	if not dayConfig then print("monthsignsystem.getDayConfig:dayConfig is null, day:"..tostring(day)) return nil end

	return dayConfig
end

--发送数据
local function sendData(actor)
	local data = getMonthSignData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_DailySign, Protocol.sDailySignCmd_MonthSignInfo)

	LDataPack.writeShort(npack, (data.rewardDay or 0) + 1)
	LDataPack.writeByte(npack, data.isReward or 0)
	LDataPack.writeShort(npack, data.signDays or 0)
	LDataPack.writeShort(npack, data.rewardIndex or 0)
	
	LDataPack.flush(npack)
end

local function rewardDouble(reward)
	for k, v in pairs(reward or {}) do
		v.count = v.count * 2
	end
end

--发送奖励
local function sendReward(actor, signDay)
	local vipLv = LActor.getVipLevel(actor)
	local dayConfig = getDayConfig(signDay)
	if not dayConfig then return end

	local award = utils.table_clone(dayConfig.rewards)

	--vip等级是否满足双倍要求
	if dayConfig.vipLabel then
		if vipLv >= dayConfig.vipLabel then rewardDouble(award) end
	end

	if not LActor.canGiveAwards(actor, award) then
        print("monthsignsystem.sendReward:can not give awards")
        return
	end

	LActor.giveAwards(actor, award, "monthSignReward")

	--记录
	local var = getMonthSignData(actor)
	var.isReward = 1
	var.signdays = (var.signdays or 0) + 1
end

--领取签到奖励
local function onGetMonthSignReward(actor)
	--等级判断
	if false == checkOpenLevel(actor) then return end

	--是否已签到
	if checkMonthSign(actor) then print("monthsignsystem.onGetMonthSignReward:already sign, actorId:"..tostring(LActor.getActorId(actor))) return end

	local var = getMonthSignData(actor)
	sendReward(actor, (var.rewardDay or 0) + 1)

	sendData(actor)
end

--领取累计签到奖励
local function onGetMonthSignDaysReward(actor)
	--等级判断
	if false == checkOpenLevel(actor) then return end

	local var = getMonthSignData(actor)
	local actorId = LActor.getActorId(actor)

	--获取配置
	local index = (var.rewardIndex or 0) + 1
	local config = MonthSignDaysConfig[index]
	if not config then print("monthsignsystem.onGetMonthSignDaysReward:config is null, index:"..tostring(index)..",actorId:"..tostring(actorId)) 
		return 
	end

	--判断累计签到次数是否满足
	if config.days > (var.signDays or 0) then 
		print("monthsignsystem.onGetMonthSignDaysReward:sign days is not enough, day:"..tostring(var.signDays)..",actorId:"..tostring(actorId)) 
		return 
	end

	if not LActor.canGiveAwards(actor, config.rewards) then
        print("monthsignsystem.onGetMonthSignDaysReward:can not give awards,actorId:"..tostring(actorId))
        return
	end

	LActor.giveAwards(actor, config.rewards, "signDaysReward")
	var.rewardIndex = (var.rewardIndex or 0) + 1

	sendData(actor)
end

local function onLogin(actor)
	--等级判断
	if false == checkOpenLevel(actor) then return end

	sendData(actor)
end

local function onNewDay(actor, login)
	--等级判断
	if false == checkOpenLevel(actor) then return end

	--当天签到要第二天才+1
	local var = getMonthSignData(actor)
	if 1 == (var.isReward or 0) then var.rewardDay = (var.rewardDay or 0) + 1 end
	
	--是否开始新的循环
	if checkSignIsFinish(actor) then initMonthSignData(actor) end

	--是否可以重置累计签到奖励
	if true == checkSignDaysRewardIsFinish(actor) then initSignDayData(actor) end

	--每天重置
	var.isReward = 0

	if not login then
		onLogin(actor)
	end
end

local function onLevelUp(actor, level)
	if MonthSignBaseConfig.openLevel == level then sendData(actor) end
end

actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeLevel, onLevelUp)

netmsgdispatcher.reg(Protocol.CMD_DailySign, Protocol.cDailySignCmd_ReqGetMonthSignReward, onGetMonthSignReward)
netmsgdispatcher.reg(Protocol.CMD_DailySign, Protocol.cDailySignCmd_ReqGetMonthSignDaysReward, onGetMonthSignDaysReward)


