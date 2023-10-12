module("subactivitytype11", package.seeall)
--[[
data define:
    rewardsRecord 按位读取
    taskInfo = {
    [索引] = {
      times 完成次数
      isReward 是否已领奖
    }
}
--]]

local subType = 11
local daySecond = 24 * 60 * 60

--下发数据
local function writeRecord(npack, record, conf, id, actor)
    if nil == record then record = {} end
    LDataPack.writeInt(npack, record.rewardsRecord or 0)

    --先保存当前位置，后面再插入数据
    local oldPos = LDataPack.getPosition(npack)
    LDataPack.writeShort(npack, 0)

    if nil == record.taskInfo then record.taskInfo = {} end

    local count = 0
    for actId, cfg in pairs(ActivityType11_2Config or {}) do
        if actId == id then
            for k, data in ipairs(cfg or {}) do
                if record.taskInfo[k] then
                    LDataPack.writeShort(npack, k)
                    LDataPack.writeInt(npack, record.taskInfo[k].times or 0)
                    LDataPack.writeByte(npack, record.taskInfo[k].isReward and 1 or 0)
                    count = count + 1
                end
            end

            break
        end
    end

    local newPos = LDataPack.getPosition(npack)

     --往前面插入数据
    LDataPack.setPosition(npack, oldPos)
    LDataPack.writeShort(npack, count)
    LDataPack.setPosition(npack, newPos)
end

--任务更新
function updateTask(actor, taskType, param, count)
    local actorId = LActor.getActorId(actor)
    for id, config in pairs(ActivityType11_2Config or {}) do
        if false == activitysystem.activityTimeIsEnd(id) then
            local record = activitysystem.getSubVar(actor, id)
            if nil == record.taskInfo then record.taskInfo = {} end

            --任务类型和辅助变量都一样的话才能更新
            for k, conf in ipairs(config or {}) do
                if (conf.type == taskType and taskcommon.checkParam(taskType, param, conf.param or 0)) then
                    if nil == record.taskInfo then record.taskInfo = {} end
                    if nil == record.taskInfo[k] then record.taskInfo[k] = {} end
                    if (record.taskInfo[k].times or 0) < conf.dayLimit then
                        record.taskInfo[k].times = (record.taskInfo[k].times or 0) + count
                        if (record.taskInfo[k].times or 0) > conf.dayLimit then record.taskInfo[k].times = conf.dayLimit end

                        activitysystem.sendActivityData(actor, id)
                    end
                end
            end
        end
    end
end

--获取积分对应的最高奖励
local function getHighReward(totalScore, conf)
    local cfg = nil

    for i=#(conf or {}), 1, -1 do
        if totalScore >= conf[i].score then cfg = conf[i] break end
    end

    return cfg
end

--计算总积分, 如果单项配置有天数限制, 只算到单项配置对应的天数
local function getTotalScore(id, record, conf)
    if nil == record.taskInfo then record.taskInfo = {} end

    --活动开到第几天了
    local days = activitysystem.getBeginDays(id)

    local totalScore = 0
    for k, cfg in pairs(conf or {}) do
        if record.taskInfo[k] and (cfg.day or 0) <= days then
            totalScore = totalScore + math.floor((record.taskInfo[k].times or 0) / cfg.target) * cfg.score
        end
    end

    return totalScore
end

local function checkCanAward(type, actor, record, id, idx, config)
    local actorId = LActor.getActorId(actor)
    local conf = nil
    local reward = nil

    --拿到活动id对应的所有单项配置
    for k, cfg in pairs(ActivityType11_2Config) do
        if id == k then conf = cfg break end
    end

    if not conf then print("subactivitytype11.checkCanAward:conf is nil, id:"..tostring(id)..", actorId:"..tostring(actorId)) return false end

    if nil == record.taskInfo then record.taskInfo = {} end

    --1表示领取总积分奖励，2表示领取单项积分奖励
    if 1 == type then
        if not config[idx] then
            print("subactivitytype11.checkCanAward:type1 conf is nil, id:"..tostring(id)..", idx:"..tostring(idx)..", actorId:"..tostring(actorId))
            return false
        end

        --同索引领过不能再领
        if System.bitOPMask(record.rewardsRecord or 0, idx) then
            print("subactivitytype11.checkCanAward:type1 already reward, actorId:"..tostring(actorId)..", idx:"..tostring(idx))
            return false
        end

        --奖励类型1只能领取其中一个奖励
        --if 1 == (config[idx].rewardType or 0) and 0 ~= (record.rewardsRecord or 0) then
         --   print("subactivitytype11.checkCanAward:type1 rewardType1 already reward, actorId:"..tostring(actorId))
         --   return false
        --end

        --奖励类型1只能邮件领取
        if 1 == (config[idx].rewardType or 0) then
            print("subactivitytype11.checkCanAward:type1 rewardType1 can not get reward, actorId:"..tostring(actorId))
            return false
        end

        --计算总积分
        local totalScore = getTotalScore(id, record, conf)

        --积分够了才能领
        if totalScore < config[idx].score then
             print("subactivitytype11.checkCanAward:type1 not enough, idx:"..tostring(idx)..", score:"..tostring(totalScore)..", id:"..tostring(actorId))
            return false
        end

        reward = config[idx].reward
    elseif 2 == type then
        if not conf[idx] then
            print("subactivitytype11.checkCanAward:type2 conf is nil, id:"..tostring(id)..", idx:"..tostring(idx)..", actorId:"..tostring(actorId))
            return false
        end

        if not record.taskInfo[idx] then record.taskInfo[idx] = {} end

        -- 没奖励不能领
        if not conf[idx].reward then
            print("subactivitytype11.checkCanAward:type2 reward not exist, idx:"..tostring(idx)..", actorId:"..tostring(actorId))
            return false
        end

        --领过没
        if record.taskInfo[idx].isReward then
            print("subactivitytype11.checkCanAward:type2 already reward, idx:"..tostring(idx)..", actorId:"..tostring(actorId))
            return false
        end

        --次数是否够了
        if (record.taskInfo[idx].times or 0) < conf[idx].dayLimit then
            print("subactivitytype11.checkCanAward:type2 times not enough, idx:"..tostring(idx)..", actorId:"..tostring(actorId))
            return false
        end

        reward = conf[idx].reward
    end

    return true, reward
end

local function setRewardFlag(type, record, idx)
    if 1 == type then
        record.rewardsRecord = System.bitOpSetMask(record.rewardsRecord or 0, idx, true)
    elseif 2 == type then
         record.taskInfo[idx].isReward = 1
    end
end

local function getReward(id, typeconfig, actor, record, packet)
    local actorId = LActor.getActorId(actor)
    local idx = LDataPack.readShort(packet)
    local type = LDataPack.readShort(packet)

    local conf = typeconfig[id]
    if nil == conf then
        print("subactivitytype11.getReward:conf is nil, id:"..tostring(id)..", actorId:"..tostring(actorId))
        return
    end

    --是否可以领
    local isReward, reward = checkCanAward(type, actor, record, id, idx, conf)
    if not isReward or not reward then
        print("subactivitytype11.getReward:can not get reward, index:"..tostring(idx)..", type:"..tostring(type)..", actorId:"..tostring(actorId))
        return
    end

    if not LActor.canGiveAwards(actor, reward) then
        print("subactivitytype11.getReward:canGiveAwards is false, actorId:"..tostring(actorId))
        return
    end

    --保存领取标识
    setRewardFlag(type, record, idx)

    LActor.giveAwards(actor, reward, "type11 award, idx:"..tostring(idx)..",type:"..tostring(type))

   activitysystem.sendActivityData(actor, id)
end

local function sendMail(actor, conf)
    local mailData = {head=conf.mailInfo.head, context=conf.mailInfo.content, tAwardList=conf.reward}
    mailsystem.sendMailById(LActor.getActorId(actor), mailData)
end

local function sendRewardMail(actor, id, config)
    local record = activitysystem.getSubVar(actor, id)
    if not record then return end

    --拿到活动id对应的所有单项配置
    local conf = nil
    for k, cfg in pairs(ActivityType11_2Config) do
        if id == k then conf = cfg break end
    end

    if not config then
        for k, cfg in pairs(ActivityType11_1Config) do
            if id == k then config = cfg break end
        end
    end

    if config and config[1] then
        if record.isSend then return end
        --只能领最高积分的对应奖励
        if config[1].rewardType then
            if 0 ~= (record.rewardsRecord or 0) then return end
            local rewardConf = getHighReward(getTotalScore(id, record, conf), config)
            if rewardConf then
                sendMail(actor, rewardConf)
                record.rewardsRecord = System.bitOpSetMask(record.rewardsRecord or 0, rewardConf.index, true)
                record.isSend = 1
                print("subactivitytype11.sendRewardMail:send rewardType1 mail success, actorId:"..tostring(LActor.getActorId(actor)))
            end
        else
            local totalScore = getTotalScore(id, record, conf)
            for k, data in pairs(config or {}) do
                if not System.bitOPMask(record.rewardsRecord or 0, data.index) and totalScore >= data.score then
                    sendMail(actor, data)
                    record.rewardsRecord = System.bitOpSetMask(record.rewardsRecord or 0, data.index, true)
                    record.isSend = 1
                    print("subactivitytype11.sendRewardMail:send mail success, actorId:"..tostring(LActor.getActorId(actor)))
                end
            end
        end
    end
end

local function onNewDay(id, conf)
    return function(actor)
        if activitysystem.activityTimeIsEnd(id) then sendRewardMail(actor, id, conf) return end

        --是否每天重置
        if conf and conf[1] and conf[1].isReset then
            local var = activitysystem.getSubVar(actor, id)
            var.taskInfo = nil
            var.rewardsRecord = nil

            activitysystem.sendActivityData(actor, id)
        end
    end
end

local function onLogin(actor)
    for id, info in pairs(ActivityType11_1Config) do
        if activitysystem.activityIsEnd(id) then
            sendRewardMail(actor, id)
        end
    end
end

local function initFunc(id, conf)
    actorevent.reg(aeNewDayArrive, onNewDay(id, conf))
end

subactivities.regConf(subType, ActivityType11_1Config)
subactivities.regInitFunc(subType, initFunc)
subactivities.regWriteRecordFunc(subType, writeRecord)
subactivities.regGetRewardFunc(subType, getReward)

actorevent.reg(aeUserLogin, onLogin)