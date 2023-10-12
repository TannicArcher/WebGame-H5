module("subactivitytype14", package.seeall)

local subType = 14

local function initRecord(record)
    if not record.data.jifen then
        record.data.jifen = 0
    end

    if not record.data.rewardsRecord then
        record.data.rewardsRecord = 0
    end
end

local function writeRewardRecord(pack, record, idConfig, id, actor)
    if pack == nil then return end
    if record == nil then
        record = activitysystem.getSubVar(actor, id)
    end
    initRecord(record)
   
    LDataPack.writeInt(pack, record.data.rewardsRecord)
    LDataPack.writeInt(pack, record.data.jifen)
end

local function checkReward(actor, record, index, idConfig)
    if idConfig[index] == nil then
        return false
    end

    -- 从1开始, 到31
    if index < 1 or index > 32 then
        print("config is err , index is invalid.."..index)
        return false
    end

    if record.data.rewardsRecord == nil then
        record.data.rewardsRecord = 0
    end

    if System.bitOPMask(record.data.rewardsRecord, index) then
        return false
    end

    if not LActor.canGiveAwards(actor, idConfig[index].rewards) then
        return false
    end

    if record.data.jifen < idConfig[index].jifen then
        return false
    end

    return true
end

local function getReward(id, typeConf, actor, record, packet)
    initRecord(record)
    
    local index = LDataPack.readShort(packet)
    local idConfig = typeConf[id]
    if not checkReward(actor, record, index, idConfig) then
        return false
    end

    record.data.rewardsRecord = System.bitOpSetMask(record.data.rewardsRecord, index, true)
    LActor.giveAwards(actor, idConfig[index].rewards, "activity type14 rewards")

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_GetRewardResult)
    LDataPack.writeByte(pack, 1)
    LDataPack.writeInt(pack, id)
    LDataPack.writeShort(pack, index)
    LDataPack.writeInt(pack, record.data.rewardsRecord)
    LDataPack.flush(pack)
end

function addJiFen(ranks, jifen)
    local activities = activitysystem.getTypeActivities(subType)
    print("subactivitytype14 add jifen " .. jifen)

    for i, v in ipairs(ranks or {}) do
        local actor = LActor.getActorById(v.aid)
        if actor then
            for id, _ in pairs(activities) do
                local record = activitysystem.getSubVar(actor, id)
                initRecord(record)
                record.data.jifen = record.data.jifen + jifen

                local pack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_UpdateInfo)
                if pack then 
                    LDataPack.writeInt(pack, id)
                    LDataPack.writeShort(pack, subType)
                    LDataPack.writeInt(pack, record.data.jifen)
                    LDataPack.flush(pack)
                end
            end
        end
    end
end

subactivities.regConf(subType, ActivityType14Config)
-- subactivities.regInitFunc(subType, initFunc)
subactivities.regWriteRecordFunc(subType, writeRewardRecord)
subactivities.regGetRewardFunc(subType, getReward)
