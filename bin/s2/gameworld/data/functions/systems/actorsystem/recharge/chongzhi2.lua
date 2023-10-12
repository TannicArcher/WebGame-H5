--[[
a)	例如：玩家开服第一天没有完成任意一档的首次充值，则第二天仍然显示首次充值的界面。如果玩家在某天完成了任意一档的首次充值，则第二天显示对应活动循环周期的每日充值
b)	活动循环周期：开服前7天每天变化，开服第8天起，每7天为一个活动循环周期，共包括7组活动，每天采用对应的活动内容
与chognzhi1区别是没有a条,其他一样
ccccc!!!!, 未领取的还要邮件发!!!++++++ 已经做在登陆时处理
--]]


module("chongzhi2", package.seeall)


--[[
data define:

    chongzhi2Data = {
        payCount -- number      已冲金额
        recordDay -- number 1,  记录对应的天数
        rewardRecord -- number  bitset  领取记录
    }
--]]


local p = Protocol
local function getStaticData(actor)
    local var = LActor.getStaticVar(actor)
    if (var == nil) then return end

    if (var.chongzhi2Data == nil) then
        var.chongzhi2Data = {}
    end

    return var.chongzhi2Data
end

local function getConfig(recordDay)
    recordDay = recordDay or System.getOpenServerDay()
    local type, day
    if recordDay > 6 then
        type, day = 2, recordDay % 7
    else
        type, day = 1, recordDay
    end

    if ChongZhi2Config == nil or ChongZhi2Config[type] == nil then
        return nil
    end
    return ChongZhi2Config[type][day]
end

local function updateInfo(actor)
    local data = getStaticData(actor)
    local npack = LDataPack.allocPacket(actor, p.CMD_Recharge, p.sRechargeCmd_UpdateChongZhi2)
    if npack == nil then return end

    LDataPack.writeInt(npack, data.payCount or 0)
    LDataPack.writeInt(npack, data.rewardRecord or 0)
    LDataPack.flush(npack)
end

local function onReqReward(actor, packet)
    local index = LDataPack.readShort(packet)

    local data = getStaticData(actor)

    if System.bitOPMask(data.rewardRecord or 0, index) then
        log_print(LActor.getActorId(actor) .. " chongzhi2.onReqReward:record ")
        return
    end

    local config = getConfig(data.recordDay)
    if config == nil then
        log_print(LActor.getActorId(actor) .. " chongzhi2.onReqReward:config error.".. tostring(data.recordDay or System.getOpenServerDay()))
        return
    end

    if config[index] == nil then
        log_print(LActor.getActorId(actor) .. " chongzhi2.onReqReward:config error ".. index)
        return
    end

    if config[index].pay > (data.payCount or 0) then
        log_print(LActor.getActorId(actor) .. " chongzhi2.onReqReward:pay count not enough")
        return
    end

    if not LActor.canGiveAwards(actor, config[index].awardList) then
        return
    end

    data.rewardRecord = System.bitOpSetMask(data.rewardRecord or 0, index, true)

    LActor.giveAwards(actor, config[index].awardList, "chongzhi2")

    updateInfo(actor)
	log_print(LActor.getActorId(actor) .. " chongzhi2.onReqReward:ok")
end

local function onRecharge(actor, count)
    local data = getStaticData(actor)
    data.payCount = (data.payCount or 0) + count

    updateInfo(actor)
end


local function sendInitInfo(actor)
    local data = getStaticData(actor)
    local npack = LDataPack.allocPacket(actor, p.CMD_Recharge, p.sRechargeCmd_InitChongZhi2)
    if npack == nil then return end

    LDataPack.writeShort(npack, data.recordDay or System.getOpenServerDay())
    LDataPack.writeInt(npack, data.payCount or 0)
    LDataPack.writeInt(npack, data.rewardRecord or 0)

    LDataPack.flush(npack)
end

local function onLogin(actor)
    sendInitInfo(actor)
end

local function onNewDay(actor, isLogin)
    local data = getStaticData(actor)
    --补发奖励
    local config = getConfig(data.recordDay)
    if config then
        for index, conf in pairs(config) do
            if System.bitOPMask(data.rewardRecord or 0, index) == false and
                    (data.payCount or 0) >= conf.pay then
                local content = string.format(ChongZhiBaseConfig.mailContent2, conf.pay)
                local mailData = {head=ChongZhiBaseConfig.mailTitle2, context=content, tAwardList=conf.awardList}
                mailsystem.sendMailById(LActor.getActorId(actor), mailData)
                log_print(LActor.getActorId(actor) .. "chongzhi2.onNewDay:2 zhen de you zhe zhong ren !!!  ") --我看下真有这个必要做这个邮件补发么
            end
        end
    end
    --重置记录
    data.hasPayed = ((LActor.getRecharge(actor) > 0) and 1) or 0
    data.payCount = 0
    data.recordDay = System.getOpenServerDay()
    data.rewardRecord = 0
    --更新客户端
    if not isLogin then
        sendInitInfo(actor)
    end
	log_print(LActor.getActorId(actor) .. "chongzhi2.onNewDay:ok  ") 
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeRecharge, onRecharge)

netmsgdispatcher.reg(p.CMD_Recharge, p.cRechargeCmd_ReqRewardChongZhi2, onReqReward)
