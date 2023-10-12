module("subactivitytype15", package.seeall)

local subType = 15
local curid = nil

local function initFunc(id, idConf)
    local isEnd = activitysystem.activityTimeIsEnd(id)
    if not isEnd then
        assert(curid==nil, "only one can be open activity" .. subType)
        curid = id
    end
end

local function getReward(id, typeConf, actor, record, packet)
end

local function onReqInfo(id, typeConf, actor, record, packet)
end

-- 战灵暴击倍率
function getZhanLingN()
    if not curid then
        return
    end

    if activitysystem.activityTimeIsEnd(curid) then
        curid = nil
        return 
    end

    if curid and ActivityType15Config[curid] then 
        return ActivityType15Config[curid].n
    end
end

-- 注册一类活动配置
subactivities.regConf(subType, ActivityType15Config)
subactivities.regInitFunc(subType, initFunc)
-- subactivities.regGetRewardFunc(subType, getReward)
-- subactivities.regReqInfoFunc(subType, onReqInfo)
