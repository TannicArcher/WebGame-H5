module("subactivitytype4", package.seeall)

require("systems.actorsystem.dabiao")
require("systems.activity.consumeybrank")

local subType = 4

open_list = {}
type4GlobalData = type4GlobalData or {}
local function getGlobalVar( id )
    if not type4GlobalData[id] then type4GlobalData[id] = {} end
    return type4GlobalData[id]
end

local function getIdConfig(id)
    local conf = ActivityType4Config[id]
    if conf == nil then 
        print("dabiaoactivity not has conf " .. id)
        return false
    end

    if not conf[0] then
        print("dabiaoactivity not has conf 0 " .. id)
        return false
    end

    return conf
end

function endTimer(conf, id)
    if not conf or not id then return end
    print("dabiao close id " .. id)
    
    if open_list[id] == nil then 
        return
    end
    
    local conf = getIdConfig(id)
    if conf then
        local rankType = conf[0].rankType
        sendReward(id, rankType, conf)
    end
    open_list[id] = nil
end

function openTimer(conf, id)
    if not conf or not id then return end
    print("dabiao open id:"..id)
    open_list[id] = true
end

local function init(id, conf)
    local gdata = getGlobalVar(id)
    local begintime = activitysystem.getBeginTime(id)
    local endtime = activitysystem.getEndTime(id)
    local now = System.getNowTime()
    if now >= endtime then  -- 结束了
        return
    elseif now <= begintime then  -- 还未开始
		print("dabiao need open id:"..id..",left_sec:"..(begintime-now))
		print("dabiao need close id:"..id..",left_sec:"..(endtime-now))

        if gdata.openEid then LActor.cancelScriptEvent(nil, gdata.openEid) end
        gdata.openEid = LActor.postScriptEventLite(nil, (begintime-now) * 1000, function() openTimer(conf, id) end)

        if gdata.endEid then LActor.cancelScriptEvent(nil, gdata.endEid) end
        gdata.endEid = LActor.postScriptEventLite(nil, (endtime-now) * 1000, function() endTimer(conf, id) end)
    else  -- 已经开始了,但还未结束
        open_list[id] = true
        print("dabiao open id:"..id)
		print("dabiao need close id:"..id..",left_sec:"..(endtime-now))

        if gdata.endEid then LActor.cancelScriptEvent(nil, gdata.endEid) end
        gdata.endEid = LActor.postScriptEventLite(nil, (endtime-now) * 1000, function() endTimer(conf, id) end)
        -- LActor.postScriptEventLite(nil, 3 * 1000, function() endTimer(conf, id) end)
    end
	--初始化消费排行榜
	consumeybrank.init(id, conf)
end

local function getData(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then 
        return nil
    end
    if var.dabiao == nil then 
        var.dabiao = {}
    end
    return var.dabiao
end

local function initData(actor, id)
    local var = getData(actor) 
    if var[id] == nil then 
        var[id] = 1
    end
end

local function getIndex(actor, id)
    initData(actor, id)
    local var = getData(actor)
    return var[id]
end

local function getRaward(actor, id, rankType, conf, index)
    local var = getData(actor)
    if not isDaBiao(actor, id, rankType, conf, index) then
        print(LActor.getActorId(actor) .. " 没有达标 " .. index)
        return false
    end

    LActor.giveAwards(actor, conf[0].value[index].rewards, "dabiao rewards")
    var[id] = var[id] + 1
    return true
end

local function onDaBiaoData(actor, pack)
    local id = LDataPack.readInt(pack)
    sendDaBiaoData(actor, id)
end

local function onGetRaward(actor, pack)
    local id = LDataPack.readInt(pack)
  
    if open_list[id] == nil then return false end

    local conf = getIdConfig(id)
    if not conf then return end
    local rankType = conf[0].rankType

    local index = getIndex(actor, id)
    local ret = getRaward(actor, id, rankType, conf, index)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_DaBiaoReward)
    if npack == nil then return end 
    LDataPack.writeByte(npack, ret and 1 or 0)
    LDataPack.writeInt(npack, getIndex(actor,id))
    LDataPack.flush(npack)
end

function isDaBiao(actor, id, rankType, conf, index)
    return dabiao.isDaBiao(actor, id, rankType, conf, index)
end

function sendDaBiaoData(actor, id)
    if open_list[id] == nil then return false end

    local conf = getIdConfig(id)
    if not conf then return end
    local rankType = conf[0].rankType
    local index = getIndex(actor, id)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_SendDaBiaoData)
    if npack == nil then return end

    local canget = isDaBiao(actor, id, rankType, conf, index) and 1 or 0
    LDataPack.writeByte(npack, canget)
    LDataPack.writeInt(npack, index)
    LDataPack.writeShort(npack, rankType)

    if rankType == RankingType_ConsumeYB then
       consumeybrank.sendDaBiaoData(npack, actor, id, rankType, conf, index)
    else
        dabiao.sendDaBiaoData(npack, actor, id, rankType, conf, index)
    end

    LDataPack.flush(npack)
end

function sendReward(id, rankType, conf)
    if rankType == RankingType_ConsumeYB then
       consumeybrank.sendRankingReward(id, rankType, conf)
    else
        dabiao.sendRankingReward(id, rankType, conf)
    end
end


local function onLogin(actor)
    for id, v in pairs(open_list) do
        sendDaBiaoData(actor, id)
    end
end

subactivities.regInitFunc(subType, init)

subactivities.regConf(subType, ActivityType4Config)
netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_SendDaBiaoData, onDaBiaoData)
netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_DaBiaoReward, onGetRaward)
