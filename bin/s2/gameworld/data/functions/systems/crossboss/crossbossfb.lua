--跨服boss管理模块(跨服服)
module("crossbossfb", package.seeall)

--全局数据
--[[
	bossList = {
		[id] = {
			id
			bossId    bossid
			srvId     服务器id
			fbHandle  副本句柄
			bossBelong  当前boss归属者
			flagBelong  旗帜boss归属者
			monster 怪物
			flagMonster  旗帜怪物
			flagStartTime  采棋开始时间
			flagRefreshTime 旗帜刷新时间
			bossRefreshTime boss刷新剩余时间
			revEid      boss回血定时器
		}
	}
--]]

--[[玩家跨服数据
	bossBelongLeftCount 可获得boss归属次数
	flagBelongLeftCount 可获得旗帜归属次数
	resBelongCountTime 最近一次刷新归属者次数时间
	scene_cd				进入cd
	resurgence_cd  	复活cd
	rebornEid 		复活定时器句柄
	id   			当前进入的副本配置id
	needCost        复活需要扣的元宝
	bless			祝福值
]]

--[[系统跨服数据
	isOpen   1表示已开启活动
	bossList = {
		[id] = {
				deathCount 已击杀次数
			}
	}
]]


globalCrossBossData = globalCrossBossData or {}

local rewardType ={
	flagReward = 1, --旗帜归属奖励
	bossReward = 2, --boss归属奖励
}

function getGlobalData()
	return globalCrossBossData
end

function getBossData(id)
	if not globalCrossBossData.bossList then globalCrossBossData.bossList = {} end
    return globalCrossBossData.bossList[id]
end

local function getCrossStaticData(actor)
    local var = LActor.getCrossVar(actor)
    if nil == var.crossboss then var.crossboss = {} end

    return var.crossboss
end

function getSysData()
	local var = System.getStaticVar()
	if nil == var.crossboss then var.crossboss = {} end
	if nil == var.crossboss.bossList then var.crossboss.bossList = {} end

	return var.crossboss
end

--是否已开启了活动
local function isOpen()
	local data = getSysData()
	return data.isOpen
end

--获取旗帜刷新随机坐标
local function getFlagRefreshPoint(id)
    local index = math.random(1, #(CrossBossConfig[id].flagPos))
	local cfg = CrossBossConfig[id].flagPos[index]

    return cfg.posX, cfg.posY
end

--清除副本
function clearFb()
	local data = getGlobalData()
	for _, info in pairs(data.bossList or {}) do
		local ins = instancesystem.getInsByHdl(info.fbHandle)
		if ins then ins:setEnd() ins:release() print("crossbossfb.clearFb: fbHandle:"..tostring(info.fbHandle)) end
	end

	data.bossList = {}

	print("crossbossfb.clearFb: clearFb success, srvId:"..tostring(System.getServerId()))
end

--发送boss信息到游戏服
local function sendBossInfo(id, sId)
	if not System.isCommSrv() then
		local fbInfo = getBossData(id)
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCCrossBossCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCBossCmd_RefreshBoss)
		LDataPack.writeShort(npack, fbInfo.id)
		LDataPack.writeShort(npack, fbInfo.srvId)
		LDataPack.writeUInt(npack, fbInfo.fbHandle)
		LDataPack.writeInt(npack, fbInfo.bossRefreshTime or 0)
		LDataPack.writeInt(npack, fbInfo.flagRefreshTime or 0)
		System.sendPacketToAllGameClient(npack, sId or 0)
	else
		crossbosssystem.sendBossData(nil)
	end
end

--发送boss/旗帜复活
local function sendMonsterRefresh(type, id)
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, Protocol.CMD_CrossBoss)
	LDataPack.writeByte(npack, Protocol.sCrossBossCmd_BossResurgence)
	LDataPack.writeShort(npack, type)
	LDataPack.writeShort(npack, id)
	System.sendPacketToAllGameClient(npack, 0)
end

--是否可以拿归属
local function canGetBelong(actor, type)
	if not actor then return false end
	local var = getCrossStaticData(actor)
	if rewardType.flagReward == type then
		return (var.flagBelongLeftCount or CrossBossBase.flagBelongCount) > 0
	else
		return (var.bossBelongLeftCount or CrossBossBase.bossBelongCount) > 0
	end
end

--减少归属次数
local function reduceBelongCount(actor, type)
	if not actor then return false end
	local var = getCrossStaticData(actor)
	if rewardType.flagReward == type then
		var.flagBelongLeftCount = (var.flagBelongLeftCount or CrossBossBase.flagBelongCount) - 1
		if 0 > var.flagBelongLeftCount then var.flagBelongLeftCount = 0 end
	else
		var.bossBelongLeftCount = (var.bossBelongLeftCount or CrossBossBase.bossBelongCount) - 1
		if 0 > var.bossBelongLeftCount then var.bossBelongLeftCount = 0 end
	end
end

--根据最大的开服天数获取bossId
function getBossId(conf)
	if System.isCommSrv() or not conf.openBossList then return conf.bossId end

	local list = {}
	for _, time in pairs(csbase.getCommonSrvList() or {}) do table.insert(list, time) end

	if 0 == table.getnEx(list) then return conf.bossId end

	table.sort(list)

	local openDay = System.getTimeToNowDay(list[#list])+1

	local keyList = {}
	for k in pairs(conf.openBossList or {}) do keyList[#keyList+1] = k end
	table.sort(keyList)

	for i = #keyList, 1, -1 do
		if openDay >= keyList[i] then return conf.openBossList[keyList[i]] end
	end

	return conf.bossId
end

--通知玩家的复活信息
local function notifyRebornTime(actor, killerHdl)
    local data = getCrossStaticData(actor)
    local rebornCd = (data.resurgence_cd or 0) - System.getNowTime()
    if rebornCd < 0 then rebornCd = 0 end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_CrossBoss, Protocol.sCrossBossCmd_ResurgenceInfo)
    LDataPack.writeInt(npack, rebornCd)
    LDataPack.writeDouble(npack, killerHdl or 0)
    LDataPack.flush(npack)
end

--复活定时器
local function reborn(actor, id)
	if not actor then return end

	notifyRebornTime(actor)

	local x, y = crossbosssystem.getRandomPoint(CrossBossConfig[id])
	LActor.relive(actor, x, y)

	LActor.stopAI(actor)
end

--刷出boss怪物
local function refreshBossTimer(id)
	local conf = CrossBossConfig[id]
	if not conf then print("crossbossfb.refreshBossTimer:conf nil, id:"..tostring(id)) return end

	local fbInfo = getBossData(id)
	if not fbInfo then print("crossbossfb.refreshBossTimer:fbInfo nil, id:"..tostring(id)) return end

	--刷怪
	local ins = instancesystem.getInsByHdl(fbInfo.fbHandle)
	if ins then
		local bossId = getBossId(conf)
		local monster = Fuben.createMonster(ins.scene_list[1], bossId)
		if not monster then print("crossbossfb.refreshBossTimer:monster nil, id:"..tostring(bossId)) return end

		ins.data.bossId = bossId

		fbInfo.monster = monster
		fbInfo.bossRefreshTime = 0

		sendBossInfo(id)
		sendMonsterRefresh(id, rewardType.bossReward)

		if conf.refreshNoticeId then
			noticemanager.broadCastNotice(conf.refreshNoticeId, MonstersConfig[bossId].name or "", fbInfo.srvId)
		end

		print("crossbossfb.refreshBossTimer: refresh monster success, id:"..tostring(id))
	end
end

--刷出旗帜
local function refreshFlagTimer(id)
	local fbInfo = getBossData(id)
	if not fbInfo then print("crossbossfb.refreshFlagTimer:fbInfo nil, id:"..tostring(id)) return end

	local ins = instancesystem.getInsByHdl(fbInfo.fbHandle)
	if ins and CrossBossConfig[id] and CrossBossConfig[id].flagPos then
		--旗帜坐标
		local x, y = getFlagRefreshPoint(id)

		local monster = Fuben.createMonster(ins.scene_list[1], CrossBossBase.flagId, x, y)
		if not monster then print("crossbossfb.refreshFlagTimer:monster nil") return end

		fbInfo.flagMonster = monster
		fbInfo.flagRefreshTime = 0

		sendFlagRefreshInfo(id, nil)

		sendBossInfo(id)
		sendMonsterRefresh(id, rewardType.flagReward)

		print("crossbossfb.refreshFlagTimer: refresh flag success, id:"..tostring(id))
	end
end

--改变祝福值
local function changeBless(actor, val)
	local data = getCrossStaticData(actor)
	print("crossboss.changeBless:change before, score:"..tostring(data.bless or 0))
	data.bless = (data.bless or 0) + val
	print("crossboss.changeBless:change after, score:"..tostring(data.bless or 0))
end

--检测附加祝福值奖励
local function appendBlessReward(actor, reward, id)
	if not actor then return end
	local cfg = CrossBossBless[LActor.getZhuanShengLevel(actor)]
	if not cfg then return end

	local data = getCrossStaticData(actor)
	if cfg.needBless <= (data.bless or 0) then
		for _, cid in ipairs(cfg.boss or {}) do
			if cid == id then
				local bossCfg = CrossBossConfig[id]
				if bossCfg then
					local breward = drop.dropGroup(bossCfg.blessReward)
					for _, v in ipairs(breward or {}) do table.insert(reward, v) end

					changeBless(actor, 0-(bossCfg.blessCost or 0))
					print(LActor.getActorId(actor).." crossboss.appendBlessReward,have reward id:"..id)
				else
					print(LActor.getActorId(actor).." crossboss.appendBlessReward,not bossCfg id:"..id)
				end
				break
			end
		end
	end
end

--下发个人基本数据
local function sendActorData(actor)
	crossbosssystem.sendActorData(actor)
end

--弹框和发奖励
local function sendBelongReward(actor, reward, rewardType, srvId, id)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_CrossBoss, Protocol.sCrossBossCmd_SendRewardInfo)

	LDataPack.writeShort(npack, rewardType)
	LDataPack.writeShort(npack, #reward)
	for k, v in pairs(reward or {}) do
		LDataPack.writeInt(npack, v.type)
		LDataPack.writeInt(npack, v.count)
		LDataPack.writeInt(npack, v.id)
	end

	LDataPack.flush(npack)

	if not System.isCommSrv() then
		npack = nil
		npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCCrossBossCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCBossCmd_sendReward)

		LDataPack.writeShort(npack, rewardType)
		LDataPack.writeShort(npack, #reward)
		for k, v in pairs(reward or {}) do
			LDataPack.writeInt(npack, v.type)
			LDataPack.writeInt(npack, v.id)
			LDataPack.writeInt(npack, v.count)
		end

		LDataPack.writeInt(npack, LActor.getActorId(actor))
		LDataPack.writeString(npack, LActor.getName(actor))
		LDataPack.writeShort(npack, id)
		LDataPack.writeInt(npack, LActor.getServerId(actor))
		LDataPack.writeInt(npack, srvId)

		System.sendPacketToAllGameClient(npack, 0)
	else
		crossbosssystem.sendRewardMail(reward, LActor.getActorId(actor), rewardType, LActor.getName(actor), id, LActor.getServerId(actor), srvId)
	end

	print("crossbossfb.sendBelongReward:send success, srvId"..tostring(srvId)..", actorId:"..tostring(LActor.getActorId(actor))
		..", rewardType:"..tostring(rewardType)..", actorSrvId:"..tostring(LActor.getServerId(actor)))
end

--发送旗帜归属者信息
local function sendFlagBelongInfo(id, actor)
	local npack = nil
    if actor then
        npack = LDataPack.allocPacket(actor, Protocol.CMD_CrossBoss, Protocol.sCrossBossCmd_UpdateFlagInfo)
    else
        npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, Protocol.CMD_CrossBoss)
        LDataPack.writeByte(npack, Protocol.sCrossBossCmd_UpdateFlagInfo)
    end

    --剩余时间
    local data = getBossData(id)
    local leftTime = 0
    if data.flagBelong then leftTime = data.flagStartTime + CrossBossBase.needTime - System.getNowTime() end
    if 0 > leftTime then leftTime = 0 end

    LDataPack.writeDouble(npack, data.flagBelong and LActor.getHandle(data.flagBelong) or 0)
    LDataPack.writeInt(npack, leftTime)

    if actor then
        LDataPack.flush(npack)
    else
        Fuben.sendData(data.fbHandle, npack)
    end
end

--发送旗帜刷新信息
function sendFlagRefreshInfo(id, actor)
	local npack = nil
    if actor then
        npack = LDataPack.allocPacket(actor, Protocol.CMD_CrossBoss, Protocol.sCrossBossCmd_FlagRefresh)
    else
        npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, Protocol.CMD_CrossBoss)
        LDataPack.writeByte(npack, Protocol.sCrossBossCmd_FlagRefresh)
    end

    local data = getBossData(id)
    local time = (data.flagRefreshTime or 0) - System.getNowTime() > 0 and (data.flagRefreshTime or 0) - System.getNowTime() or 0

    LDataPack.writeDouble(npack, data.flagMonster and LActor.getHandle(data.flagMonster) or 0)
    LDataPack.writeInt(npack, time)

    if actor then
        LDataPack.flush(npack)
    else
        Fuben.sendData(data.fbHandle, npack)
    end
end

--发送boss归属者信息
function sendBossBelongInfo(id, actor, oldBelong)
	local npack = nil
    if actor then
        npack = LDataPack.allocPacket(actor, Protocol.CMD_CrossBoss, Protocol.sCrossBossCmd_belongUpdate)
    else
        npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, Protocol.CMD_CrossBoss)
        LDataPack.writeByte(npack, Protocol.sCrossBossCmd_belongUpdate)
    end

     local data = getBossData(id)

   	LDataPack.writeDouble(npack, oldBelong and LActor.getHandle(oldBelong) or 0)
    LDataPack.writeDouble(npack, data.bossBelong and LActor.getHandle(data.bossBelong) or 0)

    if actor then
        LDataPack.flush(npack)
    else
        Fuben.sendData(data.fbHandle, npack)
    end
end

--清空boss归属者
local function clearBossBelongInfo(id, actor)
    local bossData = getBossData(id)
    if nil == bossData then print("crossbossfb.clearBossBelongInfo:bossData is null, id:"..id) return end

    if actor == bossData.bossBelong then
        bossData.bossBelong = nil
		sendBossBelongInfo(id, nil, actor)

		--无归属回血
		if CrossBossBase.revivalTime and not bossData.revEid then
			bossData.revEid = LActor.postScriptEventLite(nil, CrossBossBase.revivalTime * 1000, function(_, bid)
				local data = getBossData(bid)
				data.revEid = nil
				if data.monster then
					LActor.changeHp(data.monster, LActor.getHpMax(data.monster))
				end
			end, id)
		end
    end
end

--清空旗帜归属者
local function clearFlagBelongInfo(id, actor)
    local bossData = getBossData(id)
    if nil == bossData then print("crossbossfb.clearFlagBelongInfo:bossData is null, id:"..id) return end

    if actor == bossData.flagBelong then
        bossData.flagBelong = nil
        bossData.flagStartTime = nil
		sendFlagBelongInfo(id, nil)
    end
end

--进入公告
local function sendEnterNoticeId(actor, id)
	if System.isCommSrv() then
		noticemanager.broadCastNotice(CrossBossBase.myServerEnterId, LActor.getServerId(actor), LActor.getName(actor), LActor.getServerId(actor))
	else
		local data = getBossData(id)

		--玩家进入本服boss公告都一个样
		if LActor.getServerId(actor) == data.srvId then
			noticemanager.broadCastNotice(CrossBossBase.otherServerEnterId, LActor.getName(actor), LActor.getServerId(actor), LActor.getServerId(actor))
			return
		end

		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCCrossBossCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCBossCmd_enterFb)
		LDataPack.writeString(npack, LActor.getName(actor))
		LDataPack.writeShort(npack, LActor.getServerId(actor))
		LDataPack.writeShort(npack, data.srvId)
		System.sendPacketToAllGameClient(npack, 0)
	end
end

--进入副本的时候
local function onEnterFb(ins, actor)
	LActor.setCamp(actor, LActor.getActorId(actor))
	LActor.stopAI(actor)

	sendActorData(actor)

	--初始化boss归属者
	sendBossBelongInfo(ins.data.id, actor, oldBelong)

	--初始化旗帜归属者
	sendFlagBelongInfo(ins.data.id, actor)

	sendFlagRefreshInfo(ins.data.id, actor)

	--保持副本id
	local var = getCrossStaticData(actor)
	var.id = ins.data.id

	if System.isCommSrv() then
		noticemanager.broadCastNotice(CrossBossBase.otherServerEnterId, LActor.getName(actor), LActor.getServerId(actor), LActor.getServerId(actor))
	else
		sendEnterNoticeId(actor, ins.data.id)
	end
end

--boss收到伤害的时候
local function onBossDamage(ins, monster, value, attacker, res)
	local data = getBossData(ins.data.id)
	if monster ~= data.monster then return end

	--第一下攻击者为boss归属者
    if nil == data.bossBelong and data.fbHandle == LActor.getFubenHandle(attacker) then
        local actor = LActor.getActor(attacker)
        if actor and false == LActor.isDeath(actor) and canGetBelong(actor, rewardType.bossReward) then
        	--改变归属者
        	data.bossBelong = actor
			sendBossBelongInfo(ins.data.id, nil, nil)

			--怪物攻击新的归属者
            if data.monster then LActor.setAITarget(data.monster, LActor.getLiveByJob(actor)) end

			--有新归属的时候清定时器
			if data.revEid then
				LActor.cancelScriptEvent(nil, data.revEid)
				data.revEid = nil
			end
		end
    end
end

--退出的处理
local function onExitFb(ins, actor)
	local data = getBossData(ins.data.id)

	--boss归属者退出副本
	clearBossBelongInfo(ins.data.id, actor)

	--旗帜归属者退出副本
	clearFlagBelongInfo(ins.data.id, actor)

	--记录cd
	local var = getCrossStaticData(actor)
	var.scene_cd = System.getNowTime() + CrossBossBase.cdTime
	var.id = nil

	--删除复活定时器
	if var.rebornEid then LActor.cancelScriptEvent(actor, var.rebornEid) var.rebornEid = nil end

	--退出把AI恢复
	local role_count = LActor.getRoleCount(actor)
	for i = 0,role_count - 1 do
		local role = LActor.getRole(actor,i)
		LActor.setAIPassivity(role, false)
	end

	if System.isCommSrv() then sendActorData(actor) end
end

local function onOffline(ins, actor)
	LActor.exitFuben(actor)
end

local function onActorDie(ins, actor, killerHdl)
	if not actor then return end
	local et = LActor.getEntity(killerHdl)
    if not et then print("crossbossfb.onActorDie:et is null") return end

    local bossData = getBossData(ins.data.id)
    if nil == bossData then print("crossbossfb.onActorDie:bossData is null, id:"..ins.data.id) return end

    local killer_actor = LActor.getActor(et)

    --boss归属处理
    if actor == bossData.bossBelong then
		--归属者被玩家打死，该玩家是新归属者
        if killer_actor and LActor.getFubenHandle(killer_actor) == ins.handle and canGetBelong(killer_actor, rewardType.bossReward) then
            bossData.bossBelong = killer_actor
			--有新归属的时候清定时器
			if bossData.revEid then
				LActor.cancelScriptEvent(nil, bossData.revEid)
				bossData.revEid = nil
			end
            --怪物攻击新的归属者
            --if bossData.monster then LActor.setAITarget(bossData.monster, et) end
        else
            --bossData.bossBelong = nil
            clearBossBelongInfo(ins.data.id, actor)
        end

        --广播归属者信息
		sendBossBelongInfo(ins.data.id, nil, actor)
    end

    --flag归属处理
    clearFlagBelongInfo(ins.data.id, actor)

    --目标是玩家才停止ai
    if LActor.getActor(LActor.getAITarget(LActor.getLiveByJob(killer_actor))) and
    	LActor.getActor(LActor.getAITarget(LActor.getLiveByJob(killer_actor))) == actor then
    	LActor.stopAI(killer_actor)
    end

    --复活定时器
    local var = getCrossStaticData(actor)
	var.resurgence_cd = System.getNowTime() + CrossBossBase.rebornCd
	var.rebornEid = LActor.postScriptEventLite(actor, CrossBossBase.rebornCd * 1000, reborn, ins.data.id)

    notifyRebornTime(actor, killerHdl)
end

--BOSS死亡时候的处理
local function onMonsterDie(ins, mon, killerHdl)
    local bossId = ins.data.bossId
    local monId = Fuben.getMonsterId(mon)
    if monId ~= bossId then
		print("crossbossfb.onMonsterDie:monid("..tostring(monId)..") ~= bossId("..tostring(bossId).."), id:"..ins.data.id)
		return
	end

	local conf = CrossBossConfig[ins.data.id]

	local data = getBossData(ins.data.id)
	if data.bossBelong then
		local dropId = conf.belongReward
		local gData = getSysData()

		if gData.isOpen then
			if not gData.bossList[ins.data.id] then gData.bossList[ins.data.id] = {} end
			gData.bossList[ins.data.id].deathCount = (gData.bossList[ins.data.id].deathCount or 0) + 1

			if conf.extraDropId then
				if (gData.bossList[ins.data.id].deathCount or 0) >= conf.extraDropId.count then
					dropId = conf.extraDropId.dropId
					gData.bossList[ins.data.id].deathCount = nil
				end
			end
		end

		--增加祝福值
		if conf.belongBless then changeBless(data.bossBelong, conf.belongBless)	end

		local rewards = drop.dropGroup(dropId)

		--检测祝福值
		if not conf.blessRate or conf.blessRate >= math.random(10000) then appendBlessReward(data.bossBelong, rewards, ins.data.id) end

		--奖励弹框
		sendBelongReward(data.bossBelong, rewards, rewardType.bossReward, data.srvId, ins.data.id)

		--副本广播奖励
		local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_CrossBoss, Protocol.sCrossBossCmd_SendWinInfo)
		LDataPack.writeInt(npack, LActor.getServerId(data.bossBelong))
		LDataPack.writeString(npack, LActor.getName(data.bossBelong))
		LDataPack.writeDouble(npack, LActor.getHandle(LActor.getLiveByJob(data.bossBelong)))
		LDataPack.writeShort(npack, #(rewards or {}))
		for k, v in pairs(rewards or {}) do
			LDataPack.writeInt(npack, v.type)
			LDataPack.writeInt(npack, v.id)
			LDataPack.writeInt(npack, v.count)
		end

		Fuben.sendData(data.fbHandle, npack)

		local actorId = LActor.getActorId(data.bossBelong)

		print("crossbossfb.onMonsterDie, belong reward, belongId:"..tostring(actorId)..", actorFbh:"..tostring(LActor.getFubenHandle(data.bossBelong))..
		", fbH:"..tostring(ins.handle).."id:"..tostring(ins.data.id))

		--减小归属次数
		reduceBelongCount(data.bossBelong, rewardType.bossReward)
		sendActorData(data.bossBelong)
		clearBossBelongInfo(ins.data.id, data.bossBelong)
	end

	local actors = Fuben.getAllActor(data.fbHandle)
	if actors and data.monster then
		for i=1, #actors do
			local target = LActor.getAITarget(LActor.getLiveByJob(actors[i]))
			if target == data.monster then LActor.stopAI(actors[i]) end
		end
	end

	--添加刷新定时器
	LActor.postScriptEventLite(nil, conf.refreshTime * 1000, function() refreshBossTimer(ins.data.id) end)
	data.bossRefreshTime = System.getNowTime() + conf.refreshTime

	sendBossInfo(ins.data.id)
	data.monster = nil
end

--开始采集
local function onGatherStart(ins, gather, actor)
	if not actor then return false end
	local data = getBossData(ins.data.id)
	local actorId = LActor.getActorId(actor)

	if not data.flagMonster or data.flagMonster ~= gather then
		print("crossbossfb.onGatherStart:flagMonster not same, id:"..tostring(ins.data.id)..", actorId:"..tostring(actorId))
		return false
	end

	--是否被采中
	if data.flagBelong then
		print("crossbossfb.onGatherStart:flagBelong exist, id:"..tostring(ins.data.id)..", actorId:"..tostring(actorId))
		return false
	end

	--还有没有采棋次数
	if false == canGetBelong(actor, rewardType.flagReward) then
		print("crossbossfb.onGatherStart:count not enough, id:"..tostring(ins.data.id)..", actorId:"..tostring(actorId))
		return false
	end

	local bossData = getBossData(ins.data.id)
	bossData.flagBelong = actor
	bossData.flagStartTime = System.getNowTime()

	sendFlagBelongInfo(ins.data.id, nil)

	LActor.stopAI(actor)
	print("crossbossfb.onGatherStart:start to gather, actorId:"..tostring(actorId))

	return true
end

--采集结束
local function onGatherFinished(ins, gather, actor, success)
	if not actor then return end
	local data = getBossData(ins.data.id)
	local actorId = LActor.getActorId(actor)

	if not data.flagMonster or data.flagMonster ~= gather then
		print("crossbossfb.onGatherFinished:flagMonster not same, id:"..tostring(ins.data.id)..", actorId:"..tostring(actorId))
		return
	end

	if not data.flagBelong or data.flagBelong ~= actor then
		print("crossbossfb.onGatherFinished:flagBelong not exist, id:"..tostring(ins.data.id)..", actorId:"..tostring(actorId))
		return
	end

	if success then
		--删除旗帜
		LActor.DestroyEntity(data.flagMonster, true)
		data.flagMonster = nil

		--添加刷新定时器
		LActor.postScriptEventLite(nil, CrossBossBase.flagRefreshTime * 1000, function() refreshFlagTimer(ins.data.id) end)
		data.flagRefreshTime = System.getNowTime() + CrossBossBase.flagRefreshTime
		sendFlagRefreshInfo(ins.data.id, nil)
		sendBossInfo(ins.data.id)

		--奖励弹框
		local conf = CrossBossConfig[ins.data.id]
		local rewards = drop.dropGroup(conf.flagReward)
		sendBelongReward(actor, rewards, rewardType.flagReward, data.srvId, ins.data.id)

		--减小归属次数
		reduceBelongCount(actor, rewardType.flagReward)
		sendActorData(actor)
	end

	LActor.stopAI(actor)

	clearFlagBelongInfo(ins.data.id, actor)

	print("crossbossfb.onGatherStart:gather end, actorId:"..tostring(actorId)..", issuccess:"..tostring(success))
end

local function onReqBuyCd(actor, packet)
    local data = getCrossStaticData(actor)

    --没有死光不能复活
	if false == LActor.isDeath(actor) then
		print("crossbossfb.onReqBuyCd: not all die,  actorId:"..LActor.getActorId(actor))
    	return
	end

	--复活时间已到
    if (data.resurgence_cd or 0) < System.getNowTime() then
    	print("crossbossfb.onReqBuyCd: reborn not in cd,  actorId:"..LActor.getActorId(actor))
    	return
    end

    --是否在副本
    if not data.id then print("crossbossfb.onReqBuyCd: reborn not in fb,  actorId:"..LActor.getActorId(actor)) return end

	--扣钱
    local yb = LActor.getCurrency(actor, NumericType_YuanBao)
    if CrossBossBase.rebornCost + (data.needCost or 0) > yb then
    	print("crossbossfb.onReqBuyCd: money not enough, actorId:"..LActor.getActorId(actor))
    	return
    end

    --跨服不扣元宝，回本服再扣
    if System.isCommSrv() then
		LActor.changeYuanBao(actor, 0 - CrossBossBase.rebornCost, "servercrossboss buy cd")
	else
		data.needCost = (data.needCost or 0) + CrossBossBase.rebornCost
	end

    --重置复活cd和定时器
	if data.rebornEid then LActor.cancelScriptEvent(actor, data.rebornEid) end
	data.rebornEid = nil
	data.resurgence_cd = nil

	notifyRebornTime(actor)

	--原地复活
	local x, y = LActor.getPosition(actor)
	LActor.relive(actor, x, y)

	LActor.setCamp(actor, LActor.getActorId(actor))
	LActor.stopAI(actor)
end

--取消归属者
local function onCancelBelong(actor, packet)
    --是否在跨服boss副本里
	local var = getCrossStaticData(actor)
	if not var.id then print("crossbossfb.onCancelBelong: not in fuben, actorId:"..LActor.getActorId(actor)) return end

	local bossData = getBossData(var.id)
	if nil == bossData then print("crossbossfb.onCancelBelong:bossData is null, id:"..tostring(var.id)) return end

	--是否是归属者
	if not bossData.bossBelong or bossData.bossBelong ~= actor then
		print("crossbossfb.onCancelBelong: not belong, actorId:"..LActor.getActorId(actor))
		return
	end

	clearBossBelongInfo(var.id, actor)
	LActor.stopAI(actor)
end

--采棋
local function onCollect(actor, packet)
	local actorId = LActor.getActorId(actor)
	--是否在跨服boss副本里
	local var = getCrossStaticData(actor)
	if not var.id then print("crossbossfb.onCollect: not in fuben, actorId:"..tostring(actorId)) return end

	local bossData = getBossData(var.id)
	if nil == bossData then print("crossbossfb.onCollect:bossData is nil, id:"..tostring(var.id)) return end

	--是否在cd
	if (bossData.flagRefreshTime or 0) > System.getNowTime() then
		print("crossbossfb.onCollect:collect in cd, id:"..tostring(var.id)..", actorId:"..tostring(actorId))
		return
	end

	--是否存在旗帜
	if not bossData.flagMonster then
		print("crossbossfb.onCollect:flagMonster is nil, id:"..tostring(var.id)..", actorId:"..tostring(actorId))
		return
	end

	--不能重复采棋
	if bossData.flagBelong and bossData.flagBelong == actor then
		print("crossbossfb.onCollect:collect repeat, id:"..tostring(var.id)..", actorId:"..tostring(actorId))
		return
	end

	--有归属就打归属，没归属就采棋
	if bossData.flagBelong then
		if LActor.getFubenHandle(bossData.flagBelong) == LActor.getFubenHandle(actor) then
			LActor.setAITarget(actor, LActor.getLiveByJob(bossData.flagBelong))
		else
			print("crossbossfb.onCollect:FubenHandle not same, id:"..tostring(var.id)..", actorId:"..tostring(actorId))
		end
	else
		LActor.setAITarget(actor, bossData.flagMonster)
	end
end

--创建副本
local function createBossFb(conf, srvId)
	local data = getGlobalData()
	if not data.bossList then data.bossList = {} end

	if not data.bossList[conf.id] then
		local fbHandle = Fuben.createFuBen(conf.fbid)
		local ins = instancesystem.getInsByHdl(fbHandle)
		if ins then
			ins.data.id = conf.id
		else
			print("crossbossfb.createBossFb:ins nil,id:"..conf.id)
			return
		end

		data.bossList[conf.id] = {}
		data.bossList[conf.id].id = conf.id
		data.bossList[conf.id].srvId = srvId
		data.bossList[conf.id].fbHandle = fbHandle

		refreshBossTimer(conf.id)
		refreshFlagTimer(conf.id)

		print("createBossFb success, id:"..tostring(conf.id))
	end
end

--初始化副本
local function initBossDataFb(list)
	--有N个游戏服连接就开N+1个副本
	local size = #(list or {})
	for i=1, #CrossBossConfig do
		if 0 < size then createBossFb(CrossBossConfig[i], list[i]) size = size - 1 end
	end

	createBossFb(CrossBossConfig[#CrossBossConfig], 0)
end

--是否开本服boss
local function openServerBoss()
	if not System.isCommSrv() then return end
	if false == crossbosssystem.checkCanOpen() then return end
	if crossbosssystem.isOpenCrossBoss() then return end

	if CrossBossBase.serverBossId and CrossBossConfig[CrossBossBase.serverBossId] then
		createBossFb(CrossBossConfig[CrossBossBase.serverBossId], System.getServerId())

		print("crossbossfb.openServerBoss:server fb create success:"..tostring(System.getServerId()))
	end
end

--活动开始
function crossBossOpen(curTime, flag)
	print("start to crossBossOpen")

	--开启本服boss
	openServerBoss()

	if System.isCommSrv() then return end

	local data = getSysData()

	--是否已开启了
	if not flag and data.isOpen then print("crossbossfb.crossBossOpen:already open") return end

	--检测开服时间是否满足了条件
	local srvInfo = csbase.getCommonSrvList()
	for _, time in pairs(srvInfo or {}) do
		if (CrossBossBase.openDay or 0) > System.getTimeToNowDay(time)+1 then
			print("crossbossfb.crossBossOpen:time not enough")
			return
		end
	end

	if not flag then data.isOpen = 1 end

	--关掉游戏服的副本
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCCrossBossCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCBossCmd_closeFb)
	System.sendPacketToAllGameClient(npack, 0)

	--初始副本
	initBossDataFb(csbase.getCommonSrvIdList())
	print("end to crossBossOpen")
end
_G.CrossBossOpen = crossBossOpen

--服务器连接上来的时候
local function OnServerConn(sId, sType)
	local data = getGlobalData()
	for id, info in pairs(data.bossList or {}) do
		sendBossInfo(id, sId)
		print("crossbossfb.OnServerConn:sendBossInfo scccess, srvId:"..tostring(sId))
	end
end

local function OnAllServerConn(sevList)
	crossBossOpen(nil, true)
	local data = getGlobalData()
	for id, info in pairs(data.bossList or {}) do
		sendBossInfo(id)
		print("crossbossfb.OnAllServerConn:sendBossInfo scccess, id:"..tostring(id))
	end
end

--启动初始化
local function initGlobalData()
	--注册副本事件
	 for _, conf in pairs(CrossBossConfig) do
		insevent.registerInstanceEnter(conf.fbid, onEnterFb)
		insevent.registerInstanceMonsterDamage(conf.fbid, onBossDamage)
		insevent.registerInstanceExit(conf.fbid, onExitFb)
		insevent.registerInstanceOffline(conf.fbid, onOffline)
		insevent.registerInstanceActorDie(conf.fbid, onActorDie)
		insevent.registerInstanceMonsterDie(conf.fbid, onMonsterDie)
		insevent.registerInstanceGatherStart(conf.fbid, onGatherStart) --玩家开始采集时
		insevent.registerInstanceGatherFinish(conf.fbid, onGatherFinished) --玩家采集完成时
    end

    netmsgdispatcher.reg(Protocol.CMD_CrossBoss, Protocol.cCrossBossCmd_BuyCd, onReqBuyCd)
	netmsgdispatcher.reg(Protocol.CMD_CrossBoss, Protocol.cCrossBossCmd_CancelBelong, onCancelBelong)
	netmsgdispatcher.reg(Protocol.CMD_CrossBoss, Protocol.cCrossBossCmd_RequestCollect, onCollect)

	openServerBoss()

	scripttimer.reg({hour= 0, minute = 0, func = "CrossBossOpen", params = {false}})

	--游戏服连接的时候
	if not System.isCommSrv() then
		csbase.RegAllConnected(OnAllServerConn)
		csbase.RegConnected(OnServerConn)
	end
end

--清除系统数据
function clearSystemData()
	local data = getSysData()
	data.isOpen = nil
end

table.insert(InitFnTable, initGlobalData)


