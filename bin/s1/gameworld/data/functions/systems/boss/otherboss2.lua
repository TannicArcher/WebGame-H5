--boss 召唤令
module("otherboss2", package.seeall)


--[[
	otherboss2Data = {
		usedCount, --已经胜利的次数
		awardId,   --奖励组
	}
]]--



local function getData(actor)
	local data = LActor.getStaticVar(actor)
	if data == nil then return nil end
	if data.otherboss2Data == nil then
		data.otherboss2Data = {}
	end
	return data.otherboss2Data
end

local function UpdateOtherBossInfo(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Fuben, 
		Protocol.sFubenCmd_OtherBossfb2Count)
	if not npack then return end

	local data = getData(actor)
	LDataPack.writeShort(npack, (data.usedCount or 0))
	LDataPack.flush(npack)
end

local function randomfb(conf)
	if #conf.fbInfo <= 0 then return end

	
	local weight   = 0
	for i = 1, #conf.fbInfo do
		weight = weight + conf.fbInfo[i][4]
	end
	if weight <= 0 then return end
	local rand = System.rand(weight) + 1

	local index = 0	
	weight = 0
	for i = 1, #conf.fbInfo do
		weight = weight + conf.fbInfo[i][4]
		if weight >= rand then
			index = i
			break
		end
	end
	if index <= 0 then return end

	local fbId     = conf.fbInfo[index][1]
	local awardId  = conf.fbInfo[index][2]
	local bossId   = conf.fbInfo[index][3]
	return fbId, awardId, bossId
end

local function onCallBoss(actor, conf)
	local fbId, awardId, bossId = randomfb(conf)
	if not fbId then return end
	local data = getData(actor)
	data.awardId = awardId
	data.bossId  = bossId        --记录bossId，后面播放奖励公告时用到

	local hfuben = Fuben.createFuBen(fbId)
	if hfuben == 0 then
		print("create otherboss2fuben failed. "..conf.id.." fbId:"..fbId)
		return
	end

	local ins = instancesystem.getInsByHdl(hfuben)
	if not ins then return end
	ins.data.did = conf.id

	data.usedCount = (data.usedCount or 0) + 1
	LActor.enterFuBen(actor, hfuben)
end

-- 扫荡（暂时屏蔽）
-- local function onSweep(actor, conf)
-- 	local data = getData(actor)
--     data.usedCount = (data.usedCount or 0) + 1

--     local fbId,awardId,bossId = randomfb(conf)
--     if not awardId or not bossId then return end
--     data.bossId = bossId   --记录bossId，后面播放奖励公告时用到

-- 	local rewards = drop.dropGroup(awardId)
-- 	if not rewards or #rewards == 0 then return end
-- 	LActor.giveAwards(actor, rewards , "otherboss2 sweeping rewards")

-- 	UpdateOtherBossInfo(actor)

-- 	actorevent.onEvent(actor,aeEnterFuben, fbId,false)
-- 	actorevent.onEvent(actor,aeFinishFuben,fbId, InstanceConfig[fbId].type)
-- end

local function onChallenge(actor, packet)
	if LActor.isInFuben(actor) then return end

	local id   = LDataPack.readInt(packet)
	local conf = OtherBoss2Config[id]
	if not conf then  return end

	if LActor.getLevel(actor) < conf.levelLimit then
		return
	end
	
	if conf.zsLevel and conf.zsLevel > LActor.getZhuanShengLevel(actor) then	
		return
	end

	local viplevel = LActor.getVipLevel(actor)
	viplevel = viplevel + 1   --lua的下标从1开始，所以viplevel要做加1处理
	if not conf.challengeTime[viplevel] then 
		return 
	end

	local data = getData(actor) 	
 	if (data.usedCount or 0) >= conf.challengeTime[viplevel] then
 		return
 	end
 	if (LActor.getItemCount(actor,conf.itemId) < 1) then
 		print("is not item")
 		return
 	end
 	
 	LActor.costItem(actor, conf.itemId, 1,  "otherboss2")
 		

 	--[[if (data.usedCount or 0) > 0 then --原有扫荡功能，策划要求先屏蔽
 		onSweep(actor, conf)
 	else]]--
 		onCallBoss(actor, conf)
 	--end
end

local function getBossName(actor)
	local data = getData(actor)
	if not data.bossId then return " " end
	if not MonstersConfig[data.bossId] then return " " end
	return tostring(MonstersConfig[data.bossId].name)
end

local function checkRewardNotice(conf, actor, rewards)
	local monName = getBossName(actor)
	
    if not conf.rewardNotice then return end
    for _, v in ipairs(rewards) do
        if v.type == AwardType_Item and ItemConfig[v.id] and ItemConfig[v.id].needNotice == 1 then
            noticemanager.broadCastNotice(conf.rewardNotice,
            LActor.getActorName(LActor.getActorId(actor)), monName, ItemConfig[v.id].name)
        end
    end
end

local function giveAwards(ins, actor, awardId)
	local rewards = drop.dropGroup(awardId)
	if not rewards then return end

	if ins.data.did == nil then return end
    local conf = OtherBoss2Config[ins.data.did]
    if not conf then return end

	instancesystem.setInsRewards(ins, actor, rewards)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Fuben, Protocol.sFubenCmd_OtherBossfb2Result)
	if npack then
		LDataPack.writeByte(npack, 1)
		LDataPack.writeShort(npack, #rewards)
		for _, v in ipairs(rewards) do
			LDataPack.writeInt(npack, v.type or 0)
			LDataPack.writeInt(npack, v.id or 0)
			LDataPack.writeInt(npack, v.count or 0)
		end
		LDataPack.flush(npack)
	end

	if not LActor.canGiveAwards(actor, rewards) then --发邮件
		local monName  = getBossName(actor)
		local Title    = " "
		if conf.mailTitle then
			Title = string.format(conf.mailTitle, monName)
		end
		local Content  = " "
		if conf.mailContent then 
			Content = string.format(conf.mailContent, monName)   
		end
	
		local mailData = {
			head      = Title, 
			context   = Content, 
			tAwardList= rewards
		}
		mailsystem.sendMailById(LActor.getActorId(actor), mailData)
	else                                             --直接给奖励
		LActor.giveAwards(actor, rewards, "otherboss2 rewards")
    end
    --奖励广播
    checkRewardNotice(conf, actor, rewards)
end

local function onBossWin(ins)
	local actor = ins:getActorList()[1]
	if not actor then return end --胜利的时候不可能找不到吧

    local data = getData(actor)
    
    if not data.awardId then return end

    giveAwards(ins, actor, data.awardId)

	UpdateOtherBossInfo(actor)
end

local function onBossLose(ins)
	local actor = ins:getActorList()[1]
	if not actor then return end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Fuben, Protocol.sFubenCmd_OtherBossfb2Result)
	if not npack then return end
	LDataPack.writeByte(npack, 0)
	LDataPack.writeShort(npack, 0)
	LDataPack.flush(npack)
end

local function onNewDay(actor, login)
	local data = getData(actor)
	data.usedCount = 0

	UpdateOtherBossInfo(actor)
end

local function onLogin(actor)
	UpdateOtherBossInfo(actor)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)

netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_OtherBoss2Challenge, onChallenge)

for _,conf in pairs(OtherBoss2Config) do
	for _,v in pairs(conf.fbInfo) do
		insevent.registerInstanceWin(v[1],  onBossWin)
		insevent.registerInstanceLose(v[1], onBossLose)
	end
end

local gmsystem      = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.clearcallbossfb = function (actor, args)
	local data = getData(actor)
	data.usedCount = 0
end

