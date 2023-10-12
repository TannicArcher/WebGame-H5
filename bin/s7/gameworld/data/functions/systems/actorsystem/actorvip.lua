module("vip", package.seeall)


--所需数据一部分在ActorBasicData中
-- vip level
-- dailyMaxRecharge 历史最高单日充值
-- 增加一个vip奖励领取记录
-- lastWeek  上次领取周礼包时间

-- giftex: {[1]=xx,...}

local function getStaticData(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then return nil end

    if var.vipData == nil then
        var.vipData = {}
    end

    return var.vipData
end

-- 获取扩展VIP礼包标志
local function getExtMask( data, id )
    if not data then return false end
    -- 0-31
    if id < 32 then return System.bitOPMask(data.gift or 0, id) end
    -- 32-...
    if not data.giftex then return false end
    local index = math.floor(id / 32)
    local pos = id % 32
    return System.bitOPMask(data.giftex[index] or 0, pos)
end

-- 设置扩展VIP礼包标志
local function setExtMask( data, id )
    if not data then
        print("actorvip.setExtMask data is nil id:"..tostring(id))
        return 
    end
    -- 0-31
    if id < 32 then
        data.gift = System.bitOpSetMask(data.gift or 0, id, true)
        return
    end
    -- 32-...
    -- 初始化
    if not data.giftex then data.giftex = {} end
    local index = math.floor(id / 32)
    local pos = id % 32
    for i=1,index do
        if not data.giftex[i] then data.giftex[i] = 0 end
    end
    -- 设置标志位
    data.giftex[index] = System.bitOpSetMask(data.giftex[index] or 0, pos, true)
end

local function onReqRewards(actor, packet)
    local level = LDataPack.readShort(packet)
    if level < 1 then return end
    if VipConfig[level] == nil then return end

    local data = getStaticData(actor)
    local record = data.record or 0
    if System.bitOPMask(record, level-1) then
        return
    end

    if LActor.getVipLevel(actor) < level then
        return
    end

    local rewards = VipConfig[level].awards
    if not LActor.canGiveAwards(actor, rewards) then
        return
    end

    data.record = System.bitOpSetMask(record, level -1 , true)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_UpdateRecord)
    if npack == nil then return end

    print("on ReqVipRewards. record:"..data.record)
    LDataPack.writeInt(npack, data.record)
    LDataPack.flush(npack)

    LActor.giveAwards(actor, rewards, "vip rewards")
end

local function GetWeekReward(actor)
    if 0 == LActor.getVipLevel(actor) then 
        print("actorvip.GetWeekReward: viplevel is 0:"..tostring(LActor.getActorId(actor)))
        return false
    end

    --同一周领过就不能领了
    if not checkWeekRewardStatus(actor) then 
        print("actorvip.GetWeekReward: already get weedReward:"..tostring(LActor.getActorId(actor)))
        return false
    end

    local data = getStaticData(actor)
    local level = LActor.getVipLevel(actor)
    if not VipConfig[level] or not VipConfig[level].weekReward then
        print("actorvip.checkLevel.GetWeekReward: conf is null:"..tostring(level))
        return false
    end

    if not LActor.canGiveAwards(actor, VipConfig[level].weekReward) then LActor.sendTipmsg(actor, "背包容量不足") return false end

    LActor.giveAwards(actor, VipConfig[level].weekReward, "vip weekrewards")

    data.lastWeek = System.getNowTime()

    return true
end

local function onGetWeekReward(actor)
    local ret = GetWeekReward(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_GetWeekReward)
    LDataPack.writeByte(npack, ret and 1 or 0)
    LDataPack.flush(npack)
end

local function onLogin(actor)
    local data = getStaticData(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_InitData)
    if npack == nil then return end

    print("actor vip:"..LActor.getVipLevel(actor) .. " actorid:" .. LActor.getActorId(actor))
    LDataPack.writeShort(npack, LActor.getVipLevel(actor))
    LDataPack.writeInt(npack, LActor.getRecharge(actor))
    LDataPack.writeInt(npack, data.record or 0)

    local ret = checkWeekRewardStatus(actor)
    LDataPack.writeShort(npack, ret and 1 or 0)
    -- LDataPack.writeUInt(npack, data.gift or 0)

    -- 扩展礼包ID
    LDataPack.writeShort(npack, #(VipGiftConfig or {}))
	for id,_ in ipairs(VipGiftConfig or {}) do
        LDataPack.writeUInt(npack, id)
        LDataPack.writeChar(npack, getExtMask(data, id) and 1 or 0)
    end

    LDataPack.flush(npack)
end

local function onCharge(actor, val)
    local level = LActor.getVipLevel(actor)
    local preLevel = level
    local totalCharge = LActor.getRecharge(actor)
    local update = false
    local data = getStaticData(actor)

    while true do
        local conf = VipConfig[level+1]
        if conf == nil then break end
        if totalCharge < conf.needYb then break end
        level = level + 1
        update = true
    end
    if update then
        --公告
        if 0 == preLevel then 
            local actorId = LActor.getActorId(actor)
            noticemanager.broadCastNotice(ChongZhiBaseConfig.vipNotice, LActor.getActorName(actorId) or "")
        end

        --actorevent.onEvent(actor, aeUpdateVipInfo, level)
        LActor.setVipLevel(actor, level)
        updateVipAttr(actor)

        --没领取过可以领取周礼包
        if nil == data.lastWeek then data.lastWeek = 0 end
    end

    print("oncharge actorid:" .. LActor.getActorId(actor) .. " vip:" .. level)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_UpdateExp)
    if npack == nil then return end

    LDataPack.writeShort(npack, level)
    LDataPack.writeInt(npack, totalCharge)

     local ret = checkWeekRewardStatus(actor)
    LDataPack.writeShort(npack, ret and 1 or 0)
    LDataPack.flush(npack)

    print("setviplevel actorid:" .. LActor.getActorId(actor) .. " vip:" .. level)
end

-- 获取vip对特定系统属性加成的百分比
function getAttrAdditionPercentBySysId(actor,sysId)
    local level = LActor.getVipLevel(actor)
    local percent = 0

    --[[
    for i,v in ipairs(VipConfig) do
        if level >= i then
            if v.attrAddition and v.attrAddition.sysId and v.attrAddition.percent
            and v.attrAddition.sysId == sysId then
                percent = percent + v.attrAddition.percent
            end
        end
    end
    ]]  
    return percent/100
end

--更新vip属性
function updateVipAttr(actor)
    local level = LActor.getVipLevel(actor)
    if 0 == level then return end

    local conf = VipConfig[level]
    if not conf then return end

    local attr = LActor.getVipAttr(actor)
    attr:Reset()

    local tAttrList = {}
    local attrConfig = conf.attrAddition

    for _, tAttr in pairs(attrConfig or {}) do
        tAttrList[tAttr.type] = (tAttrList[tAttr.type] or 0) + tAttr.value
    end 

    for type, value in pairs(tAttrList) do
        attr:Set(type, value)
    end

    LActor.reCalcAttr(actor)
end

--是否可以领取周礼包
function checkWeekRewardStatus(actor)
    if 0 == LActor.getVipLevel(actor) then return false end

    local data = getStaticData(actor)
    if System.isSameWeek(System.getNowTime(), data.lastWeek or 0) then return false end

    return true
end


--请求购买VIP礼包
local function onBuyGift(actor, packet)
	local id = LDataPack.readByte(packet)
	--获取配置
	local cfg = VipGiftConfig[id]
	if not cfg then
		print(LActor.getActorId(actor).." vip.onBuyGift not cfg id:"..id)
		return
	end
	local data = getStaticData(actor)
    if not data then
        print(LActor.getActorId(actor).." actorvip.onBuyGift data is nil id:"..tostring(id))
        return 
    end
	--判断是否已经购买
	-- if System.bitOPMask(data.gift or 0, id) then
    if getExtMask(data, id) then
		print(LActor.getActorId(actor).." vip.onBuyGift gift is buy id:"..id)
		return
	end
	--判断VIP等级
	if cfg.vipLv > LActor.getVipLevel(actor) then
		print(LActor.getActorId(actor).." vip.onBuyGift vip lv limit id:"..id..",needLv:"..cfg.vipLv..",curLv:"..LActor.getVipLevel(actor))
		return
	end
	--判断钱是否足够
	local yb = LActor.getCurrency(actor, NumericType_YuanBao)
	if cfg.needYb > yb then 
		print(LActor.getActorId(actor).." vip.onBuyGift yuanbao not enough id:"..id)
		return 
	end
	--判断前置的条件是否都已经购买
	if cfg.cond then
		for _,nid in ipairs(cfg.cond) do
			-- if not System.bitOPMask(data.gift or 0, nid) then
            if not getExtMask(data, nid) then
				print(LActor.getActorId(actor).." vip.onBuyGift cond not enough id:"..id..",nid:"..nid)
				return
			end
		end
	end
    -- 判断合服次数
    if cfg.hfTimes and cfg.hfTimes > hefutime.getHeFuCount() then
        print(LActor.getActorId(actor).." vip.onBuyGift hfTimes fail id:"..id..",cfg.hfTimes:"..cfg.hfTimes..",hefutime:"..hefutime.getHeFuCount())
        return
    end
	--判断背包是否能放得下
	if not LActor.canGiveAwards(actor, cfg.awards) then
		print(LActor.getActorId(actor).." vip.onBuyGift not canGiveAwards id:"..id)
		return
	end
	--扣钱
	LActor.changeYuanBao(actor, 0 - cfg.needYb, "buy vip gift"..tostring(cfg.needYb))
	--发礼包奖励
	LActor.giveAwards(actor, cfg.awards, "buy vip gift")
	--设置已经购买
	-- data.gift = System.bitOpSetMask(data.gift or 0, id, true)
    setExtMask(data, id)
	--返回消息给客户端
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_GiftInfo)
    if npack == nil then return end
    -- LDataPack.writeUInt(npack, data.gift or 0)

    -- 扩展VIP礼包ID
    LDataPack.writeShort(npack, 1)
    LDataPack.writeUInt(npack, id)
    LDataPack.writeChar(npack, getExtMask(data, id) and 1 or 0)
    LDataPack.flush(npack)
end

local function onReqSuperVipInfo(actor, packet)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_ReqSuperVipInfo)
    local data = getStaticData(actor)

    --保存历史单天最高充值
    local dr = dailyrecharge.getPayCount(actor)
    if dr > (data.dailyMaxRecharge or 0) then data.dailyMaxRecharge = dr end

    LDataPack.writeInt(npack, data.dailyMaxRecharge or 0)
    LDataPack.writeInt(npack, LActor.getRecharge(actor))
    LDataPack.flush(npack)
end

local function onNewDayArrive(actor)
    onLogin(actor)
end

local function onBeforeLogin(actor)
    updateVipAttr(actor)
end

actorevent.reg(aeRecharge, onCharge)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDayArrive)
actorevent.reg(aeInit, onBeforeLogin)

netmsgdispatcher.reg(Protocol.CMD_Vip, Protocol.cVipCmd_ReqReward, onReqRewards)
--netmsgdispatcher.reg(Protocol.CMD_Vip, Protocol.cVipCmd_GetWeekReward, onGetWeekReward)
netmsgdispatcher.reg(Protocol.CMD_Vip, Protocol.cVipCmd_BuyGift, onBuyGift)
netmsgdispatcher.reg(Protocol.CMD_Vip, Protocol.cVipCmd_ReqSuperVipInfo, onReqSuperVipInfo)


--测试充值命令
function gmTestRecharge(actor, yb)
    LActor.addRecharge(actor, yb)
end



function attrAssert(actor,sysId,orin,percent,change)
    -- local level = LActor.getVipLevel(actor)
    -- print(string.format("%d %d %d %.2f %d",level,sysId,orin,percent,change))
    -- if sysId == 1 and level >= 11 then assert(percent == 0.2 and math.floor(orin * 1.2) == change ) end
    -- if sysId == 2 and level >= 12 then assert(percent == 0.2 and math.floor(orin * 1.2) == change ) end
    -- if sysId == 3 and level >= 13 then assert(percent == 0.2 and math.floor(orin * 1.2) == change ) end
    -- if sysId == 4 and level >= 14 then assert(percent == 0.2 and math.floor(orin * 1.2) == change ) end
    -- if sysId == 5 and level >= 15 then assert(percent == 0.2 and math.floor(orin * 1.2) == change ) end
end

