
--[[
multidayrecharge = {
    todayrecharge = 0, --今日已充值金额
    isrec = 0, --是否已经领取
    useday = 1, --当前在第几天充值(默认值:1)
}
--]]

module("multidayrecharge", package.seeall)

local function getStaticData(actor)
    local var = LActor.getStaticVar(actor)
    if nil == var.multidayrecharge then var.multidayrecharge = {} end
    return var.multidayrecharge
end

local function sendRechargeDaysInfo(actor)
 	local var = getStaticData(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_MultiDayRechargeData)
    LDataPack.writeInt(npack, var.todayrecharge or 0)
    LDataPack.writeChar(npack, var.isrec or 0)
    LDataPack.writeShort(npack, var.useday or 1)
    LDataPack.flush(npack)
end

local function onRecharge(actor, count)
    if ChongZhiBaseConfig.MultiDayRechargeOpenDay and ChongZhiBaseConfig.MultiDayRechargeOpenDay > System.getOpenServerDay() + 1 then
        print(LActor.getActorId(actor).." multidayrecharge.onRecharge open day is limit")
        return
    end
    if ChongZhiBaseConfig.MultiDayRechargeOpenLv and 
        ChongZhiBaseConfig.MultiDayRechargeOpenLv > (LActor.getZhuanShengLevel(actor)*1000 + LActor.getLevel(actor)) then
        print(LActor.getActorId(actor).." multidayrecharge.onRecharge open level is limit")
        return
    end
    local var = getStaticData(actor)
    var.todayrecharge = (var.todayrecharge or 0) + count
    sendRechargeDaysInfo(actor)
end

--根据开服天数获取奖励配置
local function GetAwards(conf)
    local openday = System.getOpenServerDay() + 1
    --寻找一份 满足开服天数条件并最大程度接近当前开服天数的key
    local getday = nil
    for day,reward in pairs(conf.awardList or {}) do
        if day <= openday then --配置的时间比开服时间要小的
            if not getday or getday < day then --找到一个最大的
                getday = day
            end
        end
    end
    if not getday then
        print("multidayrecharge.GetAwards getday is nil conf.id:"..conf.id..",openday:"..openday)
        return {}
    end
    return conf.awardList[getday]
end

--客户端请求获取奖励
local function onGetReward(actor, pack)
    local var = getStaticData(actor)
    --领过没
    if var.isrec and var.isrec ~= 0 then
        print(LActor.getActorId(actor).." multidayrecharge.onGetReward already get reward")
        return
    end
    --判断配置是否存在
    local conf = MultiDayRechargeConfig[var.useday or 1]
    if not conf then
        print(LActor.getActorId(actor).." multidayrecharge.onGetReward config is nil useday:"..(var.useday or 1))
        return
    end
    --判断是否达到充值条件
    if (var.todayrecharge or 0) < conf.num then
        print(LActor.getActorId(actor).." multidayrecharge.onGetReward num is limit useday:"..(var.useday or 1)..","..(var.todayrecharge or 0))
        return
    end

    local awards = GetAwards(conf)
    if not LActor.canGiveAwards(actor, awards) then
        print(LActor.getActorId(actor).."multidayrecharge.onGetReward canGiveAwards is false")
        return
    end

    --记录
    var.isrec = 1

    LActor.giveAwards(actor, awards, "multidayrecharge "..(var.useday or 1))

    sendRechargeDaysInfo(actor)
end

local function onLogin(actor)
    sendRechargeDaysInfo(actor)
end

local function trySendRewardMail(actor)
    local var = getStaticData(actor)
    --没领取又有充值记录
    if (not var.isrec or var.isrec == 0) and var.todayrecharge and var.todayrecharge > 0 then
        --获取配置
        local conf = MultiDayRechargeConfig[var.useday or 1]
        if not conf then
            print(LActor.getActorId(actor).." multidayrecharge.trySendRewardMail config is nil useday:"..(var.useday or 1))
            return
        end
        --判断是否达到充值条件
        if var.todayrecharge >= conf.num then
            var.isrec = 1
            --根据开服天数获取奖励
            local awards = GetAwards(conf)
            --发送邮件
            local mailData = {head=ChongZhiBaseConfig.MultiDayRechargeTitle, context=ChongZhiBaseConfig.MultiDayRechargeContent, tAwardList=awards}
            mailsystem.sendMailById(LActor.getActorId(actor), mailData)
        end
    end
end

local function onNewday(actor, isLogin)
    local var = getStaticData(actor)
    trySendRewardMail(actor)
    var.todayrecharge = nil
    if var.isrec and var.isrec ~= 0 then
        var.useday = (var.useday or 1) + 1
        if var.useday > #MultiDayRechargeConfig then
            var.useday = 1
        end
    end
    var.isrec = nil
    if not isLogin then
        sendRechargeDaysInfo(actor)
    end
end

local function initGlobalData()
    actorevent.reg(aeRecharge, onRecharge)
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeNewDayArrive, onNewday)

    netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cRechargeCmd_GetMultiDayRechargeAward, onGetReward)
end

table.insert(InitFnTable, initGlobalData)

local gmsystem    = require("systems.gm.gmsystem")
local gm = gmsystem.gmCmdHandlers
gm.mulitdayrecharge = function( actor, arg )
    onGetReward(actor, nil)
    return true
end
