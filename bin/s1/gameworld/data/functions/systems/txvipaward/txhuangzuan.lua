-- 黄钻特权
module("txhuangzuan", package.seeall)

local huangzuanNormal = 0  -- 0 普通黄钻
local huangzuanYear = 1    -- 1 年费黄钻

local levelGiftMax = 100   -- 最多100个等级礼包

local newgifttype   = 1  -- 新手礼包
local daygifttype   = 2  -- 每日礼包
local levelgifttype = 3  -- 等级礼包

local systemid = Protocol.CMD_Platform

local function initVar(var)
    var.openId = nil
    var.appId = nil
    var.openKey = nil

    var.isHuangZuan = 0  -- 标志黄钻是否有效
    var.invalidTime = 0
    var.huangzuanLv = 0
    var.huangzuanType = 0

    var.newGift = 0        -- 新手礼包
    
    var.todayGift = 0      -- 普通黄钻每日礼包
    var.todayGiftYear = 0  -- 年费黄钻每日礼包

    var.levelGift = {}     -- 存放已经领取了哪些等级礼包
    var.levelGift.n = 0    -- 数组长度
end

local function getStaticVar(actor, init)
    local actorVar = LActor.getStaticVar(actor)
    if not actorVar then
        return nil
    end

    if init then
        if actorVar.huangzuan == nil then
            actorVar.huangzuan = {}
            initVar(actorVar.huangzuan)
        end
    end
    return actorVar.huangzuan
end

function gethuangzaninfo(actor)
    local var = getStaticVar(actor, false)
    if not var or var.isHuangZuan == 0 then
        return 0, 0
    end

    return var.huangzuanLv, var.huangzuanType
end

-------------------------------- 查询黄钻接口 --------------------------------
-- 解析返回数据
function checkHuangZuanRet(params, retParams)
    local content = retParams[1]
    print("http ret *** ")
    print(content)
    local ret = json:decode(content)
    if not ret.yellow_vip_level then
        return
    end

    local huangzuanLv = ret.yellow_vip_level
    local huangzuanType = huangzuanNormal
    if ret.is_yellow_year_vip and ret.is_yellow_year_vip == 1 then
        huangzuanType = huangzuanYear
    elseif ret.is_yellow_high_vip and ret.is_yellow_high_vip == 1 then
        huangzuanType = huangzuanYear
    end
    print("huangzuanLv:" .. huangzuanLv .. " Type:" .. huangzuanType)
    
    local actorid = params.actorid
    local funcName = params.funcName or ""
    local funcArgs = params.funcArgs or {}

    local actor = LActor.getActorById(actorid)
    if not actor then
        print("checkHuangZuanRet not find actor " .. actorid)
        return
    end

    local var = getStaticVar(actor, true)
   
    if huangzuanLv == nil or huangzuanLv == 0 then
        var.huangzuanLv = 0
        var.isHuangZuan = 0
    else
        var.huangzuanLv = huangzuanLv
        var.isHuangZuan = 1
    end

    if huangzuanType == nil or huangzuanType == 0 then
        var.huangzuanType = huangzuanNormal
    else
        var.huangzuanType = huangzuanYear
    end

    if funcName == "getRewardRet" then
        getRewardRet(actor, funcArgs)
    elseif funcName == "handleGetHuangZuanInfoRet" then
        handleGetHuangZuanInfoRet(actor, funcArgs)
    end
end

local function checkHuangZuan(actor, args)
    local actorid = LActor.getActorId(actor)
    args.actorid = actorid
    -- sendMsgToWeb("/api/getYellowVipInfo?" .. "openId=" .. args.openId .. "&openKey=" .. args.openKey .. "&appId=" .. args.appId,
    --     checkHuangZuanRet, args)

    local var = getStaticVar(actor, true)
    local huangzuanLv = var.huangzuanLv
    local huangzuanType = var.huangzuanType
    local s = json:encode({yellow_vip_level=huangzuanLv, is_yellow_year_vip=huangzuanType})
    LActor.postScriptEventLite(actor, 1 * 1000, function() checkHuangZuanRet(args, {s}) end)
end

function testQueryHuangZuan(actor)
    local args = {}
    args.openId = "75w3530543b4256w274y20zba8127993"
    args.openKey = "49f12e0cde053ba5b7e4e47c3475de29"
    args.appId = "2000035"
    args.actorid = LActor.getActorId(actor)
    checkHuangZuan(actor, args)
end
-------------------------------- 查询黄钻接口 --------------------------------

local function getNewGift(actor, var)
    if var.newGift == 1 then
        print("huangzuan getNewGift already get")
        return
    end

    local rewards = HuangZuanConfig.huangzhuangift
    if not LActor.canGiveAwards(actor, rewards) then
        print("huangzuan getNewGift bag not enough")
        return
    end

    var.newGift = 1
    LActor.giveAwards(actor, rewards, "huangzuan getNewGift")

    local pack = LDataPack.allocPacket(actor, systemid, Protocol.sPlatformCmd_GetGift)
    if not pack then return end
    LDataPack.writeByte(pack, newgifttype)
    LDataPack.flush(pack)
end

local function getDayGift(actor, var, rewardType)
    local rewards = nil
    if rewardType == huangzuanNormal then
        if var.todayGift == 1 then
            print("huangzuan getDayGift already get todayGift")
            return
        end
        rewards = HuangZuanDayGiftConfig[huangzuanNormal][var.huangzuanLv].reward
    elseif rewardType == huangzuanYear then
        if var.huangzuanType ~= huangzuanYear then
            print("huangzuan getDayGift not huangzuanYear vip")
            return
        elseif var.todayGiftYear == 1 then
            print("huangzuan getDayGift already get todayGiftYear")
            return
        end
        rewards = HuangZuanDayGiftConfig[huangzuanYear][var.huangzuanLv].reward
    else
        print("huangzuan getDayGift error type" .. rewardType)
        return
    end

    if not LActor.canGiveAwards(actor, rewards) then
        print("huangzuan getDayGift bag not enough")
        return
    end

    if rewardType == huangzuanNormal then
        var.todayGift = 1
    else
        var.todayGiftYear = 1
    end
    LActor.giveAwards(actor, rewards, "huangzuan getDayGift" .. rewardType)

    local pack = LDataPack.allocPacket(actor, systemid, Protocol.sPlatformCmd_GetGift)
    if not pack then return end
    LDataPack.writeByte(pack, daygifttype)
    LDataPack.writeByte(pack, rewardType)
    LDataPack.flush(pack)
end

local function getLevelGift(actor, var, level)
    local n = var.levelGift.n
    for i=1, n do
        if var.levelGift[i] == level then
            print("huangzuan getLevelGift already get" .. level)
            return
        end
    end

    local rewards = HuangZuanLevelGiftConfig[level].reward
    if not LActor.canGiveAwards(actor, rewards) then
        print("huangzuan getLevelGift bag not enough")
        return
    end

    var.levelGift.n = n + 1
    var.levelGift[n + 1] = level
    LActor.giveAwards(actor, rewards, "huangzuan getLevelGift" .. level)

    local pack = LDataPack.allocPacket(actor, systemid, Protocol.sPlatformCmd_GetGift)
    if not pack then return end
    LDataPack.writeByte(pack, levelgifttype)
    LDataPack.writeInt(pack, level)
    LDataPack.flush(pack)
end

local function handleGetGift(actor, packet)
    local giftType = LDataPack.readByte(packet)
    local args = { funcArgs = { giftType }, }
    if giftType == newgifttype then
        -- getNewGift(actor, var)
    elseif giftType == daygifttype then
        local rewardType = LDataPack.readByte(packet)
        -- getDayGift(actor, var, rewardType)
        table.insert(args.funcArgs, rewardType)
    elseif giftType == levelgifttype then
        local level = LDataPack.readInt(packet)
        -- getLevelGift(actor, var, level)
        table.insert(args.funcArgs, level)
    else
        print("huangzuan handleGetGift error giftType" .. giftType)
        return
    end
    
    local openId = LDataPack.readString(packet)
    local appId = LDataPack.readString(packet)
    local openKey = LDataPack.readString(packet)
    args.openId = openId
    args.appId = appId
    args.openKey = openKey
    args.funcName = "getRewardRet"
    checkHuangZuan(actor, args)
end

function getRewardRet(actor, args)
    local var = getStaticVar(actor, false)
    if not var or var.isHuangZuan == 0 then
        print("huangzuan handleGetGift not huangzuan")
        return
    end

    local giftType = args[1]
    if giftType == newgifttype then
        getNewGift(actor, var)
    elseif giftType == daygifttype then
        local rewardType = args[2]
        getDayGift(actor, var, rewardType)
    elseif giftType == levelgifttype then
        local level = args[2]
        getLevelGift(actor, var, level)
    else
        print("huangzuan handleGetGift error giftType" .. giftType)
        return
    end
end

local function handleGetHuangZuanInfo(actor, packet)
    local openId = LDataPack.readString(packet)
    local appId = LDataPack.readString(packet)
    local openKey = LDataPack.readString(packet)
    local huangzuanLv = LDataPack.readInt(packet)
    local huangzuanType = LDataPack.readInt(packet)
    local var = getStaticVar(actor, true)

    var.openId = openId
    var.appId = appId
    var.openKey = openKey
    var.huangzuanLv = huangzuanLv
    var.huangzuanType = huangzuanType
    if var.huangzuanLv > 0 then
        var.isHuangZuan = 1
    end

    -- checkHuangZuan(actor, { funcName="handleGetHuangZuanInfoRet", funcArgs={}, openId=openId, openKey=openKey, appId=appId })
    handleGetHuangZuanInfoRet(actor)
end

function handleGetHuangZuanInfoRet(actor)
    local pack = LDataPack.allocPacket(actor, systemid, Protocol.sPlatformCmd_QueryInfo)
    if not pack then return end

    local var = getStaticVar(actor, false)
    if not var or var.isHuangZuan == 0 then
        LDataPack.writeByte(pack, 0)
        LDataPack.flush(pack)
        return
    end

    LDataPack.writeByte(pack, 1)
    LDataPack.writeByte(pack, var.huangzuanLv)
    LDataPack.writeByte(pack, var.huangzuanType)
    LDataPack.writeInt(pack, var.invalidTime)
    LDataPack.writeByte(pack, var.newGift)
    LDataPack.writeByte(pack, var.todayGift)
    LDataPack.writeByte(pack, var.todayGiftYear)
    LDataPack.writeShort(pack, var.levelGift.n)
    for i = 1, var.levelGift.n do
        LDataPack.writeInt(pack, var.levelGift[i])
    end
    LDataPack.flush(pack)
end

local function onNewDay(actor)
    local var = getStaticVar(actor, false)
    if not var then
        return
    end
    var.todayGift = 0
    var.todayGiftYear = 0
end

function printVar(actor)
    local var = getStaticVar(actor, false)
    if not var then
        return
    end

    print(var.isHuangZuan)
    print(var.huangzuanLv)
    print(var.huangzuanType)
    print(var.newGift)
    print(var.todayGift)
    print(var.todayGiftYear)
    for i = 1, var.levelGift.n do
        print("level:" .. var.levelGift[i])
    end
end

netmsgdispatcher.reg(systemid, Protocol.cPlatformCmd_QueryInfo, handleGetHuangZuanInfo)
netmsgdispatcher.reg(systemid, Protocol.cPlatformCmd_GetGift, handleGetGift)

actorevent.reg(aeNewDayArrive, onNewDay)
