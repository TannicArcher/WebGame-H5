
--[[
data define:

    rechargeDaysAwards = {
        rewardDays  已领取天数集合
        isRecharge    今天是否充值过了   0表示没有，1有
        rechargeDays  已充值天数
    }
--]]

module("rechargedaysawards", package.seeall)

local function getStaticData(actor)
    local var = LActor.getStaticVar(actor)
    if nil == var.rechargeDaysAwards then var.rechargeDaysAwards = {} end
    if nil == var.rechargeDaysAwards.rewardDays then var.rechargeDaysAwards.rewardDays = {} end

    return var.rechargeDaysAwards
end

--判断该索引的奖励是否领取过了
local function checkRewardIsGet(actor, index)
    local var = getStaticData(actor)
    for i=1, #var.rewardDays do
        if index == var.rewardDays[i] then return true end
    end

    return false
end

local function sendRechargeDaysInfo(actor)
 	local data = getStaticData(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_RechargeDaysAward)

    LDataPack.writeShort(npack, #data.rewardDays)
    for i=1, #data.rewardDays do LDataPack.writeShort(npack, data.rewardDays[i]) end

    LDataPack.writeShort(npack, data.rechargeDays or 0)

    LDataPack.flush(npack)
end

local function onRecharge(actor, count)
    local var = getStaticData(actor)

    --充值天数已经到尽头了
    if #RechargeDaysAwardsConfig <= (var.rechargeDays or 0) then return end

    --今天有充值过了没
    if 1 == (var.isRecharge or 0) then return end

    var.isRecharge = 1
    var.rechargeDays = (var.rechargeDays or 0) + 1

    sendRechargeDaysInfo(actor)
end

local function onGetReward(actor, pack)
    local var = getStaticData(actor)
    local actorId = LActor.getActorId(actor)
    local index = LDataPack.readShort(pack)

    --先做个简单判断
    if index > (var.rechargeDays or 0) then
        print("rechargedaysawards.onGetReward:index more than rechargeDays, index:"..tostring(index)..", actorId:"..tostring(actorId))
        return
    end

    --领过没
    if true == checkRewardIsGet(actor, index) then
        print("rechargedaysawards.onGetReward:already get reward, index:"..tostring(index)..", actorId:"..tostring(actorId))
        return
    end

    local conf = RechargeDaysAwardsConfig[index]
    if not conf then
        print("rechargedaysawards.onGetReward:conf is nil, index:"..tostring(index)..", actorId:"..tostring(actorId))
        return
    end

    if not LActor.canGiveAwards(actor, conf.awardList) then
        print("rechargedaysawards.onGetReward:canGiveAwards is false, actorId:"..tostring(actorId))
        return
    end

    --记录
    var.rewardDays[#var.rewardDays+1] = index

    LActor.giveAwards(actor, conf.awardList, "rechargedayaward, id:".. tostring(index))

    sendRechargeDaysInfo(actor)
end

local function onLogin(actor)
    sendRechargeDaysInfo(actor)
end

local function onNewday(actor, isLogin)
    local var = getStaticData(actor)
    if #RechargeDaysAwardsConfig > (var.rechargeDays or 0) then
        if 1 == var.isRecharge then var.isRecharge = 0 end
    end
end

actorevent.reg(aeRecharge, onRecharge)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewday)

netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cRechargeCmd_RechargeDaysAward, onGetReward)

function test(actor, index)
end
