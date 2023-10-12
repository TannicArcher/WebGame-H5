--跨服boss(游戏服)
module("crossbosssystem", package.seeall)

--[[全局变量
	[配置id] = {
		flagRefreshTime  flag剩余刷新时间，0表示已刷新
		bossRefreshTime  boss剩余刷新时间，0表示已刷新
		fbHandle     副本句柄
		srvId        服务器id
	}
]]

--[[系统数据
	isCross      是否已开启了跨服
	record = {
		{type,time, actorid, srvid, 玩家名, 场景名, boss名, itemId}
		{type,time, srvid, 帮派名, boss名, 拍卖id}
	}

	greatRecord = {
		{type,time, actorid, srvid, 玩家名, 场景名, boss名, itemId}
		{type,time, srvid, 帮派名, boss名, 拍卖id}
	}

]]

--[[玩家跨服数据
	bossBelongLeftCount 可获得boss归属次数
	flagBelongLeftCount 可获得旗帜归属次数
	resBelongCountTime 最近一次刷新归属者次数时间
	scene_cd				进入cd
	resurgence_cd  	复活cd
	rebornEid 		复活定时器句柄
	bossReward      boss归属奖励
	flagReward      采棋奖励
	id   			当前进入的副本配置id
	needCost        复活需要扣的元宝
]]

CrossDropType = {
	CrossBossType = 1,  --跨服boss掉落
	DevilBossType = 2   --魔界入侵掉落
}

globalCrossBossData = globalCrossBossData or {}

local function getGlobalData()
	return globalCrossBossData
end

function getSystemData()
	local data = System.getStaticVar()
	if not data.crossboss then data.crossboss = {} end

	return data.crossboss
end

local function getCrossStaticData(actor)
    local var = LActor.getCrossVar(actor)
    if nil == var.crossboss then var.crossboss = {} end

    return var.crossboss
end

--判断本服boss是否可以开启
function checkCanOpen()
	return System.getOpenServerDay() + 1 >= (CrossBossBase.openDay or 0)
end

--是否已开启了跨服boss
function isOpenCrossBoss()
	local data = getSystemData()
	return data.isCross
end

--进入cd检测
local function checkIsInEnterCd(actor)
	local data = getCrossStaticData(actor)
	if (data.scene_cd or 0) > System.getNowTime() then return true end

	return false
end

--扣复活元宝
local function reduceRebornCost(actor)
	local data = getCrossStaticData(actor)
	if 0 < (data.needCost or 0) then
		local value = data.needCost
		local yb = LActor.getCurrency(actor, NumericType_YuanBao)
		if data.needCost > yb then value = yb end
		LActor.changeYuanBao(actor, 0 - value, "crossboss buy cd")

		data.needCost = data.needCost - value
	end
end

function resetCount(actor)
	if false == checkCanOpen() then return end
	local data = getCrossStaticData(actor)
	if not data.fix then
		data.bossBelongLeftCount = (data.bossBelongLeftCount or 0) + CrossBossBase.bossBelongCount
		data.flagBelongLeftCount = (data.flagBelongLeftCount or 0) + CrossBossBase.flagBelongCount

		if data.bossBelongLeftCount > CrossBossBase.bossBelongMaxCount then data.bossBelongLeftCount = CrossBossBase.bossBelongMaxCount end
		if data.flagBelongLeftCount > CrossBossBase.flagBelongMaxCount then data.flagBelongLeftCount = CrossBossBase.flagBelongMaxCount end

		data.fix = 1
		sendActorData(actor)
	end
end

--处理掉落记录展示长度
function CheckIsGreatDrop(type, id)
	local isGreat = false
	if CrossDropType.CrossBossType == type then
		if true == table.contains(CrossBossBase.bestDrops or {}, id) then isGreat = true end   --跨服boss掉落
	elseif CrossDropType.DevilBossType == type then
		if true == table.contains(DevilBossBase.bestDrops or {}, id) then isGreat = true end   --恶魔boss掉落
	end

	local var = getSystemData()
	if isGreat then
		if CrossBossBase.showBestSize <= #(var.greatRecord or {}) then table.remove(var.greatRecord, 1) end
	else
		if CrossBossBase.showSize <= #(var.record or {}) then table.remove(var.record, 1) end
	end

	return isGreat
end

--增加记录
local function addRecord(actorName, sceneName, bossName, itemId, aid, srvId)
	local var = getSystemData()
	if nil == var.record then var.record = {} end
	if nil == var.greatRecord then var.greatRecord = {} end

	local isGreat = CheckIsGreatDrop(CrossDropType.CrossBossType, itemId)

	local record = var.record
	if isGreat then record = var.greatRecord end

	table.insert(record, {type=CrossDropType.CrossBossType, time=System.getNowTime(), actorId=aid, srvId=srvId, actorName=actorName,
		sceneName=sceneName, bossName=bossName, itemId=itemId})
end

--极品奖励公告
local function checkRewardNotice(reward, aid, actorName, id, actorSrvId, srvId)
	local config = CrossBossConfig[id]
	if not config then return end
	local bossName = MonstersConfig[crossbossfb.getBossId(config)].name or ""

    for _, v in ipairs(reward or {}) do
        if v.type == 1 and ItemConfig[v.id] and ItemConfig[v.id].needNotice == 1 then
        	local itemName = item.getItemDisplayName(v.id)
        	if id ~= #CrossBossConfig then
            	noticemanager.broadCastNotice(CrossBossBase.noticeId, actorName, actorSrvId, srvId, bossName, itemName)
            else
            	noticemanager.broadCastNotice(CrossBossBase.islandNoticeId, actorName, actorSrvId, bossName, itemName)
            end
            addRecord(actorName, config.sceneName, bossName, v.id, aid, actorSrvId)
        end
    end
end

--发奖励邮件
function sendRewardMail(reward, actorId, type, actorName, id, actorSrvId, srvId)
	local mailData = nil
	if 1 == type then
		mailData = {head=CrossBossBase.flagTitle, context=CrossBossBase.flagContent, tAwardList=reward}
	else
		mailData = {head=CrossBossBase.bossTitle, context=CrossBossBase.bossContent, tAwardList=reward}
	end

	if actorSrvId == System.getServerId() then mailsystem.sendMailById(actorId, mailData) end

	checkRewardNotice(reward, actorId, actorName, id, actorSrvId, srvId)
end

--获取随机坐标
function getRandomPoint(conf)
    local index = math.random(1, #conf.enterPos)
    return conf.enterPos[index].posX, conf.enterPos[index].posY
end

--等级检测
local function checkLevel(actor, id)
	local level = LActor.getZhuanShengLevel(actor) * 1000
	local isCan = true

	if CrossBossConfig[id].levelLimit then
		if level < (CrossBossConfig[id].levelLimit[1] or 0) or level > (CrossBossConfig[id].levelLimit[2] or 0) then
			isCan = false
		end
	end

	return isCan
end

--下发个人基本数据
function sendActorData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_CrossBoss, Protocol.sCrossBossCmd_SendActorInfo)
	local var = getCrossStaticData(actor)

	LDataPack.writeShort(npack, var.flagBelongLeftCount or CrossBossBase.flagBelongCount)
	LDataPack.writeShort(npack, var.bossBelongLeftCount or CrossBossBase.bossBelongCount)
	LDataPack.writeShort(npack, (var.scene_cd or 0) - System.getNowTime() > 0 and (var.scene_cd or 0) - System.getNowTime() or 0)
	LDataPack.flush(npack)
end

--下发boss数据
function sendBossData(actor)
	local npack = nil
	if actor then
		npack = LDataPack.allocPacket(actor, Protocol.CMD_CrossBoss, Protocol.sCrossBossCmd_SendBossInfo)
	else
		npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, Protocol.CMD_CrossBoss)
		LDataPack.writeByte(npack, Protocol.sCrossBossCmd_SendBossInfo)
	end

	--本服boss还是跨服boss
	local data = nil
	if isOpenCrossBoss() then
		data = getGlobalData()
	else
		data = crossbossfb.getGlobalData()
	end

	if not data.bossList then data.bossList = {} end

	LDataPack.writeShort(npack, table.getnEx(data.bossList))

	for id, info in pairs(data.bossList or {}) do
		LDataPack.writeShort(npack, id)
		LDataPack.writeShort(npack, info.srvId)
		LDataPack.writeInt(npack, (info.bossRefreshTime or 0) - System.getNowTime() > 0 and (info.bossRefreshTime or 0) - System.getNowTime() or 0)
		LDataPack.writeInt(npack, (info.flagRefreshTime or 0) - System.getNowTime() > 0 and (info.flagRefreshTime or 0) - System.getNowTime() or 0)
	end

	if actor then
		LDataPack.flush(npack)
	else
		System.broadcastData(npack)
	end
end

--写跨服boss掉落数据
local function writeCrossBossDrop(record, npack)
	LDataPack.writeInt(npack, record.time)
	LDataPack.writeInt(npack, record.actorId)
	LDataPack.writeInt(npack, record.srvId)
    LDataPack.writeString(npack, record.actorName or "")
    LDataPack.writeString(npack, record.sceneName or "")
    LDataPack.writeString(npack, record.bossName or "")
    LDataPack.writeInt(npack, record.itemId)
end

--写恶魔入侵掉落数据
local function writeDevilBossDrop(record, npack)
	LDataPack.writeInt(npack, record.time)
	LDataPack.writeInt(npack, record.srvId or 0)
    LDataPack.writeString(npack, record.guildName or "")
    LDataPack.writeString(npack, record.bossName or "")
    LDataPack.writeInt(npack, record.id)
end

--新的一天到来
local function onNewDay(actor, islogin)
	if false == checkCanOpen() then return end
	--补历史天数的次数
	local data = getCrossStaticData(actor)
	local diff_day = 0
	if data.resBelongCountTime then
		diff_day = math.floor((System.getToday() - data.resBelongCountTime)/(3600*24))--获得间隔几天
	end

	local data = getCrossStaticData(actor)

	--补充
	if diff_day > 0 then
		data.bossBelongLeftCount = (data.bossBelongLeftCount or 0) + CrossBossBase.bossBelongCount * diff_day
		if data.bossBelongLeftCount > CrossBossBase.bossBelongMaxCount then data.bossBelongLeftCount = CrossBossBase.bossBelongMaxCount end

		data.flagBelongLeftCount = (data.flagBelongLeftCount or 0) + CrossBossBase.flagBelongCount * diff_day
		if data.flagBelongLeftCount > CrossBossBase.flagBelongMaxCount then data.flagBelongLeftCount = CrossBossBase.flagBelongMaxCount end
	end

	data.resBelongCountTime = System.getToday()

	sendActorData(actor)
	print(LActor.getActorId(actor).." crossboss resetCounts diff_day:"..diff_day)
end

local function onLogin(actor)
	sendActorData(actor)
	sendBossData(actor)
	reduceRebornCost(actor)
end

--请求boss信息
local function onReqBossInfo(actor, packet)
	sendBossData(actor)
end

--请求进入副本
local function onReqEnterFuBen(actor, packet)
	local aid = LActor.getActorId(actor)
	local id = LDataPack.readShort(packet)
	local actorId =LActor.getActorId(actor)

	local conf = CrossBossConfig[id]
	if not conf then print("crossbosssystem.onReqEnterFuBen:conf nil, id:"..tostring(id)..", actorId:"..tostring(actorId)) return end

	--是否开启了活动
	if false == checkCanOpen() then print("crossbosssystem.onReqEnterFuBen:not open, id:"..tostring(id)..", actorId:"..tostring(actorId)) return end

	--等级检测
	if false == checkLevel(actor, id) then
		print("crossbosssystem.onReqEnterFuBen:checkLevel nil, id:"..tostring(id)..", actorId:"..tostring(actorId))
		return
	end

	--cd检测
	if true == checkIsInEnterCd(actor) then
		print("crossbosssystem.onReqEnterFuBen:in enter cd. actorId:"..tostring(actorId))
		return
	end

	local x, y = getRandomPoint(conf)

	local data = nil
	if not isOpenCrossBoss() then
		data = crossbossfb.getBossData(id)
		if not data then print("crossbosssystem.onReqEnterFuBen:server data nil, id:"..tostring(id)..", actorId:"..tostring(actorId)) return end
		LActor.enterFuBen(actor, data.fbHandle, 0, x, y)
	else
		data = getGlobalData()
		if not data.bossList[id] then
			print("crossbosssystem.onReqEnterFuBen:data nil, id:"..tostring(id)..", actorId:"..tostring(actorId))
			return
		end

		LActor.loginOtherSrv(actor, csbase.GetBattleSvrId(bsBattleSrv), data.bossList[id].fbHandle, 0, x, y)
	end
end

--请求获取奖励展示
local function onReqShowInfo(actor, packet)
	local var = getSystemData()
	if nil == var.record then var.record = {} end
	if nil == var.greatRecord then var.greatRecord = {} end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_CrossBoss, Protocol.sCrossBossCmd_ReqShowInfo)
    LDataPack.writeShort(npack, #var.record)
    for i=#var.record, 1, -1 do
    	local type = var.record[i].type or CrossDropType.CrossBossType
    	LDataPack.writeShort(npack, type)
    	if CrossDropType.CrossBossType == type then
	    	writeCrossBossDrop(var.record[i], npack)
	    elseif CrossDropType.DevilBossType == type then
	    	writeDevilBossDrop(var.record[i], npack)
	    else
	    	print("crossbosssystem.onReqShowInfo:var.record error")
	    end
    end

    LDataPack.writeShort(npack, #var.greatRecord)
    for i=#var.greatRecord, 1, -1 do
    	LDataPack.writeShort(npack, var.greatRecord[i].type)
    	if CrossDropType.CrossBossType == var.greatRecord[i].type then
	    	writeCrossBossDrop(var.greatRecord[i], npack)
	    elseif CrossDropType.DevilBossType == var.greatRecord[i].type then
	    	writeDevilBossDrop(var.greatRecord[i], npack)
	    else
	    	print("crossbosssystem.onReqShowInfo:var.greatRecord error")
	    end
    end

    LDataPack.flush(npack)
end

--boss刷新(来自跨服)
local function onRefreshBoss(sId, sType, dp)
	local id = LDataPack.readShort(dp)
	local srvId = LDataPack.readShort(dp)
	local handle = LDataPack.readUInt(dp)
	local bossRefreshTime = LDataPack.readInt(dp)
	local flagRefreshTime = LDataPack.readInt(dp)

	local data = getGlobalData()
	if not data.bossList then data.bossList = {} end

	--游戏服也保存一份跨服boss的刷新信息
	data.bossList[id] = {}
	data.bossList[id].srvId = srvId
	data.bossList[id].bossRefreshTime = bossRefreshTime
	data.bossList[id].flagRefreshTime = flagRefreshTime
	data.bossList[id].fbHandle = handle

	print("crossbosssystem.onRefreshBoss:receive boss info success. id:"..tostring(id)..", srvId:"..tostring(srvId))
end

--发奖励邮件(来自跨服)
local function onSendReward(sId, sType, dp)
	local type = LDataPack.readShort(dp)
	local count = LDataPack.readShort(dp)
	local reward = {}
	for i=1, count do
		local rew = {}
		rew.type = LDataPack.readInt(dp)
		rew.id = LDataPack.readInt(dp)
		rew.count = LDataPack.readInt(dp)
		table.insert(reward, rew)
	end

	local actorId = LDataPack.readInt(dp)
	local actorName = LDataPack.readString(dp)
	local id = LDataPack.readShort(dp)
	local actorSrvId = LDataPack.readInt(dp)
	local srvId = LDataPack.readInt(dp)

	sendRewardMail(reward, actorId, type, actorName, id, actorSrvId, srvId)

	print("crossbosssystem.onSendReward:receive reward success. id:"..tostring(id)..", actorid:"..tostring(actorId)..", srvId:"..tostring(srvId))
end

--进入公告
local function onEnterFb(sId, sType, dp)
	local actorName = LDataPack.readString(dp)
	local actorSrvId = LDataPack.readShort(dp)
	local fbSrvId = LDataPack.readShort(dp)

	if 0 == fbSrvId then
		if CrossBossBase.islandEnterId then noticemanager.broadCastNotice(CrossBossBase.islandEnterId, actorName, actorSrvId) end
	else
		if fbSrvId == System.getServerId() then
			if CrossBossBase.myServerEnterId then noticemanager.broadCastNotice(CrossBossBase.myServerEnterId, actorSrvId, actorName, actorSrvId) end
		else
			if CrossBossBase.otherServerEnterId then
				noticemanager.broadCastNotice(CrossBossBase.otherServerEnterId, actorName, actorSrvId, System.getServerId())
			end
		end
	end
end

--关掉本服副本
local function onCloseFb(sId, sType, dp)
	crossbossfb.clearFb()

	local var = getSystemData()
	var.isCross = 1

	print("crossbosssystem.onCloseFb:success")
end

--启动初始化
local function initGlobalData()
	if not System.isCommSrv() then return end
	--玩家事件处理
	actorevent.reg(aeNewDayArrive, onNewDay)
    actorevent.reg(aeUserLogin, onLogin)

    --本服消息处理
    netmsgdispatcher.reg(Protocol.CMD_CrossBoss, Protocol.cCrossBossCmd_ReqBossInfo, onReqBossInfo)
    netmsgdispatcher.reg(Protocol.CMD_CrossBoss, Protocol.cCrossBossCmd_RequestEnter, onReqEnterFuBen)
    netmsgdispatcher.reg(Protocol.CMD_CrossBoss, Protocol.cCrossBossCmd_ReqShowInfo, onReqShowInfo)

    --跨服消息处理(跨服服来的消息)
    csmsgdispatcher.Reg(CrossSrvCmd.SCCrossBossCmd, CrossSrvSubCmd.SCBossCmd_RefreshBoss, onRefreshBoss)
    csmsgdispatcher.Reg(CrossSrvCmd.SCCrossBossCmd, CrossSrvSubCmd.SCBossCmd_sendReward, onSendReward)
    csmsgdispatcher.Reg(CrossSrvCmd.SCCrossBossCmd, CrossSrvSubCmd.SCBossCmd_enterFb, onEnterFb)
    csmsgdispatcher.Reg(CrossSrvCmd.SCCrossBossCmd, CrossSrvSubCmd.SCBossCmd_closeFb, onCloseFb)
end

table.insert(InitFnTable, initGlobalData)

local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.crossboss1 = function(actor, args)
	if 1 == tonumber(args[1]) then
		local id = tonumber(args[2])
		local conf = CrossBossConfig[id]
		if not conf then print("crossbosssystem.onReqEnterFuBen:conf nil, id:"..tostring(id)..", actorId:"..LActor.getActorId(actor)) return end

		local data = getGlobalData()
		if not data.bossList[id] then
			print("crossbosssystem.onReqEnterFuBen:data nil, id:"..tostring(id)..", actorId:"..LActor.getActorId(actor)) return end

		--等级检测
		if false == checkLevel(actor, id) then
			print("crossbosssystem.onReqEnterFuBen:checkLevel nil, id:"..tostring(id)..", actorId:"..LActor.getActorId(actor))
			return
		end

		--cd检测
		if true == checkIsInEnterCd(actor) then
			print("crossbosssystem.onReqEnterFuBen:in enter cd. actorId:".. LActor.getActorId(actor))
			return
		end

		local x, y = getRandomPoint(conf)

		--把玩家传到副本里面
		if data.bossList[id].fbHandle then
			LActor.loginOtherSrv(actor, csbase.GetBattleSvrId(bsBattleSrv), data.bossList[id].fbHandle, 0, x, y)
		end
	elseif 2 == tonumber(args[1]) then
		local var = getCrossStaticData(actor)
		var.flagBelongLeftCount = tonumber(args[2])
		var.bossBelongLeftCount = tonumber(args[2])
		sendActorData(actor)
	elseif 3 == tonumber(args[1]) then
		crossbossfb.crossBossOpen(false)
	end
end
