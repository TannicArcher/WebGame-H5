-- 限时掉落
module("subactivitytype21", package.seeall)
--[[
data define:
	daily = {
			[indx] = count -- 每天的次数
		}
}
--]]

local subType = 21

-- 发送邮件奖励
local function sendMail(actor, reward, conf)
	local mail = {head = conf.mailInfo.head, context=conf.mailInfo.context, tAwardList=reward}
    mailsystem.sendMailById(LActor.getActorId(actor), mail)
end

-- 直接进入背包，约定一定能够进入背包的
local function giveReward(actor, reward, indx, id)
	if not LActor.canGiveAwards(actor, reward) then
		print("subactivitytype21 giveAwards not enough,actor:"..LActor.getActorId(actor)..",id:"..id..",indx:"..indx) 
		return 
	end
	LActor.giveAwards(actor, reward, "type21 indx:"..tostring(indx))
end

-- 处理任务
local function handleTask(actor, id, indx, taskType, param, count, conf, record)
	-- check
	if conf.type ~= taskType then return end
	if not taskcommon.checkParam(taskType, param, conf.param or 0) then
		-- print("xxxxxxxxx handleTask check fail,actor,"..LActor.getActorId(actor)..",indx:"..indx..",taskType:"..taskType..",param:"..param)
		return
	end
	-- 每日限制
	if conf.dayLimit and (record.daily and record.daily[indx] or 0) >= conf.dayLimit then
		print("subactivitytype21 handleTask,dailyLimit actor,"..LActor.getActorId(actor)..",id:"..id..
			",indx:"..indx..",conf.dailyLimit:"..conf.dayLimit..",count:"..record.daily[indx])
		return
	end
	-- rate and reward
	if not conf.rate or not conf.reward then
		-- 配置错误
		return
	end
	local rnd = math.random(1, 10000)
	if rnd <= conf.rate then
		local rewType = conf.rewardType or 0
		local dropID = conf.reward or 0
		if not (rewType > 0 and rewType <=2 and dropID > 0) then
			return
		end
		local reward = drop.dropGroup(dropID)
		-- 初始化每天 record
		if not record.daily then record.daily = {} end
		-- 增加计数
		record.daily[indx] = (record.daily[indx] or 0) + 1
		-- 发奖励
		if rewType == 1 then
			sendMail(actor, reward, conf)
		elseif rewType == 2 then
			giveReward(actor, reward, indx, id)
		end
	end
end

-- task update 
function updateTask(actor, taskType, param, count)
    local actorId = LActor.getActorId(actor)
    for id, config in pairs(ActivityType21Config or {}) do
        if not activitysystem.activityTimeIsEnd(id) then
            local record = activitysystem.getSubVar(actor, id)
            for k, conf in ipairs(config or {}) do
                handleTask(actor, id, k, taskType, param, count, conf, record)
            end
        end
    end
end

-- 每日重置
local function onNewDay(id, conf)
    return function(actor)
		local var = activitysystem.getSubVar(actor, id)
		if activitysystem.activityTimeIsEnd(id) then
			var.daily = nil
			return
		end
        -- 每日重置次数
        if var.daily then
        	for indx,v in pairs(conf) do
				if v.dayLimit then
					var.daily[indx] = nil
				end
			end
		end
    end
end

local function initFunc(id, conf)
    actorevent.reg(aeNewDayArrive, onNewDay(id, conf))
end

subactivities.regConf(subType, ActivityType21Config)
subactivities.regInitFunc(subType, initFunc)
