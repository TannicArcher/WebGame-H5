--恶魔入侵(游戏服)
module("devilbosssystem", package.seeall)

--[[全局变量
	[配置id] = {
		refreshTime boss的刷新时间
		iskill 	    1表示已被击杀, 0还没被击杀
		fbHandle     副本句柄
	}
]]

--[[系统数据
	record = {
		{time, 玩家名字, 场景名, boss名, itemId}
	}
]]

--[[玩家跨服数据
	scene_cd				进入cd
	resurgence_cd  	复活cd
	rebornEid 		复活定时器句柄
	id   			当前进入的副本配置id
	refreshTime		该副本创建的时间
	needCost        复活需要扣的元宝
]]

globalDevilBossData = globalDevilBossData or {}

local function getGlobalData()
	return globalDevilBossData
end

local function getBossData(id)
	if not globalDevilBossData.bossList then globalDevilBossData.bossList = {} end
    return globalDevilBossData.bossList[id]
end

function getSystemData()
	local data = System.getStaticVar()
	if not data.devilboss then data.devilboss = {} end

	return data.devilboss
end

local function getCrossStaticData(actor)
    local var = LActor.getCrossVar(actor)
    if nil == var.devilboss then var.devilboss = {} end

    return var.devilboss
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
		LActor.changeYuanBao(actor, 0 - value, "devilboss buy cd")

		data.needCost = data.needCost - value
	end
end

--增加记录
local function addRecord(guildName, bossName, srvId, id)
	local var = crossbosssystem.getSystemData()
	if nil == var.record then var.record = {} end
	if nil == var.greatRecord then var.greatRecord = {} end

	local isGreat = crossbosssystem.CheckIsGreatDrop(crossbosssystem.CrossDropType.DevilBossType, id)

	local record = var.record
	if isGreat then record = var.greatRecord end

	table.insert(record, {type=crossbosssystem.CrossDropType.DevilBossType, time=System.getNowTime(),
		srvId=srvId, guildName=guildName, bossName=bossName, id=id})
end

--极品奖励公告
local function checkRewardNotice(idList, guildId, index, srvId, guildName)
	local config = DevilBossConfig[index]
	if not config then return end

    for _, id in pairs(idList or {}) do
    	local conf = AuctionItem[id]
    	if conf and conf.notice then
    		local itemName = item.getItemDisplayName(conf.item.id)
    		noticemanager.broadCastNotice(DevilBossBase.noticeId, guildName, srvId, config.bossName, itemName)

    	end

    	addRecord(guildName, config.bossName, srvId, id)
    end
end

--发奖励邮件
function sendRewardMail(reward, aid, isBelong)
	local mailData = nil
	if 1 == isBelong then
		mailData = {head=DevilBossBase.belongTitle, context=DevilBossBase.belongContent, tAwardList=reward}
	else
		mailData = {head=DevilBossBase.joinTitle, context=DevilBossBase.joinContent, tAwardList=reward}
	end

	mailsystem.sendMailById(aid, mailData)
end

--获取随机坐标
function getRandomPoint(conf)
    local index = math.random(1, #conf.enterPos)
    return conf.enterPos[index].posX, conf.enterPos[index].posY
end

--等级检测
local function checkLevel(actor, id)
	local openDay = System.getOpenServerDay() + 1
	if openDay < DevilBossBase.openDay then return false end

	local hefuTime = hefutime.getHeFuDay()
	if DevilBossBase.hefuTimeLimit and hefuTime and DevilBossBase.hefuTimeLimit >= hefuTime then return false end

	local level = LActor.getZhuanShengLevel(actor) * 1000
	level = level + LActor.getLevel(actor)

	if (DevilBossConfig[id].levelLimit or 0) > level then return false end
	return true
end

--重置进入副本
local function resetFbId(actor)
	local var = getCrossStaticData(actor)

	--两个boss的刷新时间不一样则表示之前的boss已被击杀，fbid可以重置
	if var.id then
		local data = getBossData(var.id)
		if data and (var.refreshTime or 0) < data.refreshTime then
			print("devilbosssystem.resetFbId:reset success, id:"..tostring(var.id)..", refreshTime:"..tostring(var.refreshTime))
			var.id = nil
		end
	end
end

--下发个人基本数据
function sendActorData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_DevilBoss, Protocol.sDevilBossCmd_SendActorInfo)
	local var = getCrossStaticData(actor)
	LDataPack.writeShort(npack, var.id or 0)
	LDataPack.writeShort(npack, (var.scene_cd or 0) - System.getNowTime() > 0 and (var.scene_cd or 0) - System.getNowTime() or 0)
	LDataPack.writeInt(npack, var.refreshTime or 0)
	LDataPack.flush(npack)
end

--下发boss数据
function sendBossData(actor)
	local npack = nil
	if actor then
		npack = LDataPack.allocPacket(actor, Protocol.CMD_DevilBoss, Protocol.sDevilBossCmd_SendBossInfo)
	else
		npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, Protocol.CMD_DevilBoss)
		LDataPack.writeByte(npack, Protocol.sDevilBossCmd_SendBossInfo)
	end

	local data = getGlobalData()
	if not data.bossList then data.bossList = {} end

	LDataPack.writeShort(npack, table.getnEx(data.bossList))
	for id, info in pairs(data.bossList or {}) do
		LDataPack.writeShort(npack, id)
		LDataPack.writeInt(npack, info.refreshTime or 0)
		LDataPack.writeByte(npack, info.iskill or 0)
	end

	if actor then
		LDataPack.flush(npack)
	else
		System.broadcastData(npack)
	end
end

local function onLogin(actor)
	resetFbId(actor)
	sendActorData(actor)
	sendBossData(actor)
	reduceRebornCost(actor)
end

--请求进入副本
local function onReqEnterFuBen(actor, packet)
	local aid = LActor.getActorId(actor)
	local id = LDataPack.readShort(packet)
	local actorId =LActor.getActorId(actor)

	local conf = DevilBossConfig[id]
	if not conf then print("devilbosssystem.onReqEnterFuBen:conf nil, id:"..tostring(id)..", actorId:"..tostring(actorId)) return end

	--等级检测
	if false == checkLevel(actor, id) then
		print("devilbosssystem.onReqEnterFuBen:checkLevel false, id:"..tostring(id)..", actorId:"..tostring(actorId))
		return
	end

	local data = getBossData(id)
	if not data then print("devilbosssystem.onReqEnterFuBen:data nil, id:"..tostring(id)..", actorId:"..tostring(actorId)) return end

	--是否被击杀了
	if 1 == data.iskill then print("devilbosssystem.onReqEnterFuBen:be kill, id:"..tostring(id)..", actorId:"..tostring(actorId)) return end

	--cd检测
	if true == checkIsInEnterCd(actor) then
		print("devilbosssystem.onReqEnterFuBen:in enter cd. actorId:"..tostring(actorId))
		return
	end

	resetFbId(actor)

	local var = getCrossStaticData(actor)
	if var.id and var.id ~= id then print("devilbosssystem.onReqEnterFuBen:id not same, id:"..tostring(id)..", actorId:"..tostring(actorId)) return end

	--记录进入的副本id和该boss的刷新时间
	var.id = id
	var.refreshTime = data.refreshTime

	local x, y = getRandomPoint(conf)

	LActor.loginOtherSrv(actor, csbase.GetBattleSvrId(bsBattleSrv), data.fbHandle, 0, x, y)
end

--请求获取奖励展示
local function onReqShowInfo(actor, packet)
	local var = getSystemData()
	if nil == var.record then var.record = {} end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_DevilBoss, Protocol.cDevilBossCmd_ReqShowInfo)
    LDataPack.writeShort(npack, #var.record)
    for _, v in ipairs(var.record) do
    	LDataPack.writeInt(npack, v.time)
    	LDataPack.writeInt(npack, v.srvId)
        LDataPack.writeString(npack, v.guildName)
        LDataPack.writeString(npack, v.bossName)
        LDataPack.writeInt(npack, v.id)
    end
    LDataPack.flush(npack)
end

--boss刷新(来自跨服)
local function onRefreshBoss(sId, sType, dp)
	local data = getGlobalData()
	if not data.bossList then data.bossList = {} end

	--游戏服也保存一份跨服boss的刷新信息
	local count = LDataPack.readShort(dp)
	for i=1, count do
		local id = LDataPack.readShort(dp)
		local handle = LDataPack.readUInt(dp)
		local iskill = LDataPack.readShort(dp)
		local refreshTime = LDataPack.readInt(dp)

		if not data.bossList[id] then data.bossList[id] = {} end
		data.bossList[id].fbHandle = handle
		data.bossList[id].refreshTime = refreshTime
		data.bossList[id].iskill = iskill

		print("devilbosssystem.onRefreshBoss:receive boss info success. id:"..tostring(id)..", handle:"..tostring(handle)..", iskill:"..tostring(iskill))
	end



	sendBossData(nil)
end

--发奖励邮件(来自跨服)
local function onSendPersonReward(sId, sType, dp)
	local aid = LDataPack.readInt(dp)
	local isBelong = LDataPack.readByte(dp)
	local count = LDataPack.readShort(dp)
	local reward = {}
	for i=1, count do
		local rew = {}
		rew.type = LDataPack.readInt(dp)
		rew.id = LDataPack.readInt(dp)
		rew.count = LDataPack.readInt(dp)
		table.insert(reward, rew)
	end

	sendRewardMail(reward, aid, isBelong)

	print("devilbosssystem.onSendPersonReward:receive reward success. isBelong:"..tostring(isBelong)..", actorid:"..tostring(aid))
end

--发帮派拍卖品(来自跨服)
local function onSendGuildAuction(sId, sType, dp)
	local guildId = LDataPack.readInt(dp)
	local index = LDataPack.readInt(dp)
	local srvId = LDataPack.readInt(dp)
	local guildName = LDataPack.readString(dp)
	local count = LDataPack.readShort(dp)
	local idList = {}

	--拍卖id
	for i=1, count do local id = LDataPack.readInt(dp) table.insert(idList, id) end

	local num = LDataPack.readShort(dp)
	local actorList = {}

	--actorId
	for i=1, num do local id = LDataPack.readInt(dp) table.insert(actorList, id) end

	if LGuild.getGuildById(guildId) then
		for _, id in pairs(idList) do auctionsystem.addGoods(actorList, guildId, id) end

		print("devilbosssystem.onSendGuildAuction:receive auction success. guildId:"..tostring(guildId)..", srvId:"..tostring(srvId)
			..", guildname:"..tostring(guildName))
	end

	checkRewardNotice(idList, guildId, index, srvId, guildName)
end

--启动初始化
local function initGlobalData()
	if not System.isCommSrv() then return end
	--玩家事件处理
    actorevent.reg(aeUserLogin, onLogin)

    --本服消息处理
    netmsgdispatcher.reg(Protocol.CMD_DevilBoss, Protocol.cDevilBossCmd_RequestEnter, onReqEnterFuBen)
    --netmsgdispatcher.reg(Protocol.CMD_DevilBoss, Protocol.cDevilBossCmd_ReqShowInfo, onReqShowInfo)

    --跨服消息处理(跨服服来的消息)
    csmsgdispatcher.Reg(CrossSrvCmd.SCDevilBossCmd, CrossSrvSubCmd.SCDevilBossCmd_RefreshBoss, onRefreshBoss)
    csmsgdispatcher.Reg(CrossSrvCmd.SCDevilBossCmd, CrossSrvSubCmd.SCDevilBossCmd_sendPersonReward, onSendPersonReward)
    csmsgdispatcher.Reg(CrossSrvCmd.SCDevilBossCmd, CrossSrvSubCmd.SCDevilBossCmd_sendGuildAuction, onSendGuildAuction)
end

table.insert(InitFnTable, initGlobalData)

local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.devilboss = function(actor, args)
	local var = getCrossStaticData(actor)
	var.id = nil
	var.scene_cd = nil
	sendActorData(actor)
end
