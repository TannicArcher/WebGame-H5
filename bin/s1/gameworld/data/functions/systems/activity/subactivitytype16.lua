-- 开服礼包活动 和 类型7一样的
module("subactivitytype16", package.seeall)

local Protocol = _G.Protocol
local subType = 16

local function writeRecord(pack, record, idConfig, id, actor)
    if pack == nil then return end

    if record == nil then
        record = activitysystem.getSubVar(actor, id)
        record.data.rewardsRecord = 0
        record.data.totalRecharge = 0
    end

    LDataPack.writeInt(pack, record.data.rewardsRecord or 0)
    LDataPack.writeInt(pack, record.data.totalRecharge or 0)
end

local function checkReward(index, config, actor, record)
    if config[index] == nil then
        return false
    end
    if index < 0 or index >= 32 then
        print("config is err, index is invalid.."..index)
        return false
    end
    if record.data.rewardsRecord == nil then
        record.data.rewardsRecord = 0
    end

    if System.bitOPMask(record.data.rewardsRecord, index) then
        return false
    end

    if (record.data.totalRecharge or 0) < config[index].recharegeyuanbao then
        return false
    end

    if not LActor.canGiveAwards(actor, config[index].rewards) then
        return false
    end
    return true
end

local function getReward(id, typeconfig, actor, record, packet)
    local index = LDataPack.readShort(packet)
    local config = typeconfig[id]

    local ret = checkReward(index, config, actor, record)
    if ret then
        record.data.rewardsRecord = System.bitOpSetMask(record.data.rewardsRecord, index, true)
        LActor.giveAwards(actor, config[index].rewards, "activity type16 index:"..tostring(index))
    end

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_GetRewardResult)
    LDataPack.writeByte(pack, ret and 1 or 0)
    LDataPack.writeInt(pack, id)
    LDataPack.writeShort(pack, index)
    LDataPack.writeInt(pack, record.data.rewardsRecord or 0)
    LDataPack.flush(pack)
end

local function onRecharge(id, conf)
    return function(actor, val)
        if activitysystem.activityTimeIsEnd(id) then return end

        local var = activitysystem.getSubVar(actor, id)
        var.data.totalRecharge = (var.data.totalRecharge or 0) + val

        local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_UpdateInfo)
        LDataPack.writeInt(pack, id)
        LDataPack.writeShort(pack, subType)
        LDataPack.writeInt(pack, var.data.totalRecharge or 0)
        LDataPack.flush(pack)
    end
end

local function init(id, conf)
    actorevent.reg(aeRecharge, onRecharge(id, conf))
end

subactivities.regConf(subType, ActivityType16Config)
subactivities.regInitFunc(subType, init)
subactivities.regWriteRecordFunc(subType, writeRecord)
subactivities.regGetRewardFunc(subType, getReward)
