module("subactivitytype10", package.seeall)
--[[
data define:
    totalVal 累计充值金额
    count    已抽奖次数
    status   1表示有领取领取，nil表示没有奖励领取且下一步是抽奖
    index    最新中奖索引，nil表示没抽过
global define:
    count 记录条数
    name   玩家名字
    times  中奖倍数
    money  中奖金额
}
--]]

local subType = 10

--下发数据
local function writeRecord(npack, record, conf, id, actor)
    if nil == record then record = {} end
    LDataPack.writeInt(npack, record.count or 0)
    LDataPack.writeInt(npack, record.totalVal or 0)
    LDataPack.writeInt(npack, record.index or 0)
    LDataPack.writeByte(npack, record.status or 0)

    local gdata = activitysystem.getGlobalVar(id)
    local count = #(gdata.record or {})

    LDataPack.writeChar(npack, count)
    for _,v in ipairs(gdata.record or {}) do
        LDataPack.writeString(npack, v.name or "")
        LDataPack.writeDouble(npack, v.times or 0)
        LDataPack.writeInt(npack, v.money or 0)
    end
end

local function onReCharge(id, conf)
    return function(actor, val)
        if activitysystem.activityTimeIsEnd(id) then return end

        local var = activitysystem.getSubVar(actor, id)
        var.totalVal = (var.totalVal or 0) + val         --最新的充值金额

        activitysystem.sendActivityData(actor, id)
    end
end

--检测是否需要公告
local function checkNotice(actor, cfg, id, times)
    local money = math.ceil((cfg.yuanBao or 0) * times)
    if cfg.noticeId then --公告和记录日志
        if (cfg.noticeId.multiple or 0) <= times then
            local name = LActor.getName(actor)

            noticemanager.broadCastNotice(cfg.noticeId.id, name, times, money)

            --全局变量
            local gdata = activitysystem.getGlobalVar(id)
            if not gdata.record then gdata.record = {} end
            table.insert(gdata.record, {name=name, times=times, money=money})

            if #gdata.record > 20 then table.remove(gdata.record, 1) end
        else
            LActor.sendTipmsg(actor, string.format(LAN.FUBEN.hdcj1, tostring(money)), ttScreenCenter)
        end
    end
end

--获取中奖索引
local function getRewardIndex(config)
    local pre = math.random(10000)
    local total = 0
    for index, data in ipairs(config.info or {}) do
        total = total + data.value
        if total >= pre then return index end
    end

    return 0
end

local function giveRewards(actor, id, record, conf)
     --获取中奖信息
    local cfg = conf[(record.count or 0) + 1]
    local info = cfg.info[record.index or 0]
    if not info then
        print("subactivitytype10.getReward:info nil, count:"..tostring(record.index)..", actorId:"..tostring(actorId))
        return
    end

    LActor.changeYuanBao(actor, cfg.yuanBao * info.multiple, "type10 "..tostring(record.count or 0))
    record.status = nil
    record.count = (record.count or 0) + 1

    --公告
    checkNotice(actor, cfg, id, info.multiple)

    activitysystem.sendActivityData(actor, id)
end

--请求领取奖励
local function getReward(id, typeconfig, actor, record, packet)
    local actorId = LActor.getActorId(actor)
    local conf = typeconfig[id]
    if nil == conf then
        print("subactivitytype10.getReward:conf is nil, id:"..tostring(id)..", actorId:"..tostring(actorId))
        return
    end

    if 1 == (record.status or 0) then  --领取奖励
        giveRewards(actor, id, record, conf)
    else    --抽奖
        --是否大于最大抽奖次数
        local count = record.count or 0
        if not conf[count+1] then print("subactivitytype10.getReward:count overflow, count:"..tostring(count)..", actorId:"..tostring(actorId)) return end

        --判断金额满足条件
        if conf[count+1].recharge > (record.totalVal or 0) then
            print("subactivitytype10.getReward:money not enough, money:"..tostring(record.totalVal or 0)..", actorId:"..tostring(actorId))
            return
        end

        --扣元宝不算入其它元宝活动
        LActor.changeYuanBao(actor, -conf[count+1].yuanBao, "type10 "..tostring(record.count or 0), true)

        --扣钱
        --LActor.changeCurrency(actor, NumericType_YuanBao, -conf[count+1].yuanBao, "type10cost:"..tostring(count+1))

        --获取中奖索引，用于发放奖励
        record.index = getRewardIndex(conf[count+1])
        if 0 == (record.index or 0) then print("subactivitytype10.getReward:index 0, id:"..tostring(count+1)..", actorId:"..tostring(actorId)) return end

        --保存可以领取奖励的标识
        record.status = 1

        activitysystem.sendActivityData(actor, id)
    end
end

--下线补发奖励
local function onLogout(id, conf)
    return function(actor)
        local record = activitysystem.getSubVar(actor, id)
        if 1 == (record.status or 0) then giveRewards(actor, id, record, conf) end
    end
end

local function initFunc(id, conf)
    actorevent.reg(aeUserLogout, onLogout(id, conf))
    actorevent.reg(aeRecharge, onReCharge(id, conf))
end

subactivities.regConf(subType, ActivityType10Config)
subactivities.regInitFunc(subType, initFunc)
subactivities.regWriteRecordFunc(subType, writeRecord)
subactivities.regGetRewardFunc(subType, getReward)
