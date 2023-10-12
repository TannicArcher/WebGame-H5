--恶魔入侵管理模块(跨服服)
module("devilbossfb", package.seeall)

--全局数据
--[[
	bossList = {
		[id] = {
			id
			bossId      bossid
			refreshTime boss的刷新时间
			fbHandle    副本句柄
			bossBelong  当前boss归属者
			monster     怪物
			revEid      boss回血定时器
			iskill 	    1表示已被击杀, 0还没被击杀
		}
	}

	damageRank = {
		[帮派id] = value伤害值
	}
--]]

--[[玩家跨服数据
	scene_cd				进入cd
	resurgence_cd  	复活cd
	rebornEid 		复活定时器句柄
	id   			当前进入的副本配置id
	needCost        复活需要扣的元宝
]]

--[[系统跨服数据
	bossList = {
		[id] = {
				refreshTime boss的刷新时间
				iskill 	    1表示已被击杀, 0还没被击杀
			}
	}
]]


globalDevilBossData = globalDevilBossData or {}

local function getGlobalData()
	return globalDevilBossData
end

local function getBossData(id)
	if not globalDevilBossData.bossList then globalDevilBossData.bossList = {} end
    return globalDevilBossData.bossList[id]
end

local function getCrossStaticData(actor)
    local var = LActor.getCrossVar(actor)
    if nil == var.devilboss then var.devilboss = {} end

    return var.devilboss
end

local function getSysData()
	local var = System.getStaticVar()
	if nil == var.devilboss then var.devilboss = {} end

	return var.devilboss
end

local function setSysData(id, refreshTime, iskill)
	local var = getSysData()
	if not var.bossList then var.bossList = {} end
	if not var.bossList[id] then var.bossList[id] = {} end

	if refreshTime then var.bossList[id].refreshTime = refreshTime end
	var.bossList[id].iskill = iskill
end

--发送boss信息到游戏服
local function sendBossInfo(sId)
	local data = getGlobalData()
	if not data.bossList then data.bossList = {} end

	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCDevilBossCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCDevilBossCmd_RefreshBoss)

	LDataPack.writeShort(npack, table.getnEx(data.bossList))
	for id, info in pairs(data.bossList) do
		LDataPack.writeShort(npack, id)
		LDataPack.writeUInt(npack, info.fbHandle or 0)
		LDataPack.writeShort(npack, info.iskill or 0)
		LDataPack.writeInt(npack, info.refreshTime or 0)
	end

	System.sendPacketToAllGameClient(npack, sId or 0)
end

--根据最大的开服天数获取bossId
function getBossId(conf)
	local keyList = {}
	for k in pairs(conf.openBossList or {}) do keyList[#keyList+1] = k end
	table.sort(keyList)

	local openDay = System.getOpenServerDay() + 1
	for i = #keyList, 1, -1 do
		if openDay >= keyList[i] then return conf.openBossList[keyList[i]] end
	end
end

--通知玩家的复活信息
local function notifyRebornTime(actor, killerHdl)
    local data = getCrossStaticData(actor)
    local rebornCd = (data.resurgence_cd or 0) - System.getNowTime()
    if rebornCd < 0 then rebornCd = 0 end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_DevilBoss, Protocol.sDevilBossCmd_ResurgenceInfo)
    LDataPack.writeInt(npack, rebornCd)
    LDataPack.writeDouble(npack, killerHdl or 0)
    LDataPack.flush(npack)
end

--复活定时器
local function reborn(actor, id)
	if not actor then return end

	notifyRebornTime(actor)

	local x, y = crossbosssystem.getRandomPoint(DevilBossConfig[id])
	LActor.relive(actor, x, y)

	LActor.stopAI(actor)
end

--设置阵营
local function setCamp(actor)
	local guildId = LActor.getGuildId(actor)
	if 0 == guildId then
		LActor.setCamp(actor, LActor.getActorId(actor))
	else
		LActor.setCamp(actor, guildId)
	end

	LActor.stopAI(actor)
end

--排序
local function sortRank(id, winGuildId)
	local data = getBossData(id)

	--获得归属的帮派不参与排序
	local rank = {}
	for id, v in pairs(data.damageRank or {}) do
		if id ~= winGuildId then table.insert(rank, {guildId = id, value = v.value, serverId = v.serverId, name=v.name}) end
	end

	table.sort(rank, function(a, b) return a.value > b.value end)

	data.damageRank = rank

	for i, info in pairs(rank or {}) do
		print("devilbossfb.sortRank: index:"..tostring(i)..", id:"..tostring(info.guildId).."serverId:"..tostring(info.serverId))
	end
end

--获取帮派服务器id和名字
local function getGuildServerInfo(id, guildId)
	local data = getBossData(id)
	for _, info in pairs(data.damageRank or {}) do
		if info.guildId == guildId then return info.serverId, info.name end
	end

	return 0, ""
end

--获取帮派排名
local function getRank(rank, guild)
	for i=1, #(rank or {}) do
		if rank[i].guildId == guild then return i end
	end

	return 0
end

--根据帮派人数获取拍卖id集合
local function getAuctionList(isBelong, guildId, conf, number)
	local idList = {}

	if isBelong or conf then
		for _, info in ipairs(conf or {}) do
			if info.num[1] <= number and info.num[2] >= number then
				local count = math.random(info.count[1], info.count[2])
				for i=1, count do
					local list = auctiondrop.dropGroup(info.dropId)
					for _, id in pairs(list or {}) do table.insert(idList, id) end
				end

				break
			end
		end
	end

	return idList
end

--发送帮派拍卖品到游戏服
local function sendGuildReward(id, guildId, idList, actors, isBelong, winSrvId, winSrvName)
	if not System.isCommSrv() then
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCDevilBossCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCDevilBossCmd_sendGuildAuction)

		LDataPack.writeInt(npack, guildId)
		LDataPack.writeInt(npack, id)

		local srvId, name = getGuildServerInfo(id, guildId)
		LDataPack.writeInt(npack, isBelong and winSrvId or srvId)
		LDataPack.writeString(npack, isBelong and winSrvName or name)
		LDataPack.writeShort(npack, #(idList or {}))
		for _, id in pairs(idList or {}) do LDataPack.writeInt(npack, id) end

		LDataPack.writeShort(npack, #(actors or {}))
		for i=1, #(actors or {}) do LDataPack.writeInt(npack, LActor.getActorId(actors[i])) end

		System.sendPacketToAllGameClient(npack, 0)

		print("devilbossfb.sendGuildReward: send success, guildId:"..tostring(guildId)..", id:"..tostring(id))
	end
end

--发送个人奖励到游戏服
local function sendPersonReward(actor, isBelong, reward)
	if not System.isCommSrv() then
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCDevilBossCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCDevilBossCmd_sendPersonReward)

		LDataPack.writeInt(npack, LActor.getActorId(actor))
		LDataPack.writeByte(npack, isBelong and 1 or 0)
		LDataPack.writeShort(npack, #(reward or {}))
		for k, v in pairs(reward or {}) do
			LDataPack.writeInt(npack, v.type)
			LDataPack.writeInt(npack, v.id)
			LDataPack.writeInt(npack, v.count)
		end

		System.sendPacketToAllGameClient(npack, LActor.getServerId(actor))
	end
end

local function sendRewardNotice(id, actor, isBelong, reward, auctionList)
	local data = getBossData(id)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_DevilBoss, Protocol.sDevilBossCmd_SendRewardInfo)

	LDataPack.writeString(npack, LActor.getName(data.bossBelong))
	LDataPack.writeDouble(npack, LActor.getHandle(LActor.getLiveByJob(data.bossBelong)))
	LDataPack.writeByte(npack, isBelong and 1 or 0)

	LDataPack.writeShort(npack, #(reward or {}))
	for k, v in pairs(reward or {}) do
		LDataPack.writeInt(npack, v.type)
		LDataPack.writeInt(npack, v.id)
		LDataPack.writeInt(npack, v.count)
	end

	LDataPack.writeShort(npack, #(auctionList or {}))
	for _, id in pairs(auctionList or {}) do LDataPack.writeInt(npack, id) end

	LDataPack.flush(npack)
	sendPersonReward(actor, isBelong, reward)

	print("devilbossfb.sendRewardNotice: send success, actorid:"..LActor.getActorId(actor)..", id:"..tostring(id)..
		", isBelong:"..tostring(isBelong))
end

--弹框和发奖励,actor为击杀者
local function sendReward(id, actor)
	local haveGuildList = {}  --有帮派集合 {[guildId]={actor1, actor2},[guildId]={actor1, actor2}}
	local noGuildList = {}    --无帮派集合 {actor1, actor2, actor3}

	local data = getBossData(id)
	local actors = Fuben.getAllActor(data.fbHandle)
	if actors then
		for i = 1, #actors do
			local id = LActor.getGuildId(actors[i])
			if 0 ~= id then
				if not haveGuildList[id] then haveGuildList[id] = {} end
				table.insert(haveGuildList[id], actors[i])
			else
				table.insert(noGuildList, actors[i])
			end
		end
	end

	local winGuildId = LActor.getGuildId(actor)
	local winSrvId = LActor.getServerId(actor)
	local winSrvName = LActor.getGuildName(actor)

	local conf = DevilBossConfig[id]
	local belongReward = drop.dropGroup(conf.belongReward)
	local joinReward = drop.dropGroup(conf.joinReward)

	--伤害排序
	sortRank(id, winGuildId)

	--帮派成员弹框通告
	for guildId, actors in pairs(haveGuildList or {}) do
		local isBelong = guildId == winGuildId

		local cfg = nil
		if not isBelong then cfg = conf.joinAuctionList[getRank(data.damageRank, guildId)] end
		local idList = getAuctionList(isBelong, guildId, isBelong and conf.belongAuctionList or cfg, #(actors or {}))
		if 0 < #idList then sendGuildReward(id, guildId, idList, actors, isBelong, winSrvId, winSrvName) end

		for _, tar in pairs(actors) do
			if tar then sendRewardNotice(id, tar, isBelong, isBelong and belongReward or joinReward, idList) end
		end
	end

	print("devilbossfb.sendReward: winGuildId:"..tostring(winGuildId)..", id:"..tostring(id))

	--无帮派成员弹框通告
	for _, tar in pairs(noGuildList or {}) do
		if tar then
			local isBelong = tar == actor
			sendRewardNotice(id, tar, isBelong, isBelong and belongReward or joinReward)
		end
	end

	--清空
	data.damageRank = nil
end

--发送boss归属者信息
function sendBossBelongInfo(id, actor, oldBelong)
	local npack = nil
    if actor then
        npack = LDataPack.allocPacket(actor, Protocol.CMD_DevilBoss, Protocol.sDevilBossCmd_belongUpdate)
    else
        npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, Protocol.CMD_DevilBoss)
        LDataPack.writeByte(npack, Protocol.sDevilBossCmd_belongUpdate)
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

--归属者改变
local function onBelongChange(id, oldBelong, newBelong)
	local bossData = getBossData(id)
    bossData.bossBelong = newBelong

    print("devilbossfb.onBelongChange: oldBelong:"..tostring(LActor.getHandle(oldBelong))..", newBelong:"..tostring(LActor.getHandle(newBelong))
    ..", id:"..tostring(id))

	--广播归属者信息
	sendBossBelongInfo(id, nil, oldBelong)

	--无归属回血
	if DevilBossBase.revivalTime then
		if not newBelong and not bossData.revEid then
			bossData.revEid = LActor.postScriptEventLite(nil, DevilBossBase.revivalTime * 1000, function(_, boss)
				boss.revEid = nil
				if boss.monster then
					LActor.changeHp(boss.monster, LActor.getHpMax(boss.monster))
				end
			end, bossData)
		end
	end

	--有新归属的时候清定时器
	if bossData.revEid and newBelong then
		LActor.cancelScriptEvent(nil, bossData.revEid)
		bossData.revEid = nil
	end
end

--进入副本的时候
local function onEnterFb(ins, actor)
	setCamp(actor)

	--初始化boss归属者
	sendBossBelongInfo(ins.data.id, actor)
end

--boss收到伤害的时候
local function onBossDamage(ins, monster, value, attacker, res)
	local data = getBossData(ins.data.id)
	if monster ~= data.monster then return end

	local actor = LActor.getActor(attacker)
	if actor then
		--第一下攻击者为boss归属者
		if nil == data.bossBelong and data.fbHandle == LActor.getFubenHandle(attacker) and false == LActor.isDeath(actor) then
        	--改变归属者
        	onBelongChange(ins.data.id, nil, actor)

			--怪物攻击新的归属者
            if data.monster then LActor.setAITarget(data.monster, LActor.getLiveByJob(actor)) end
	    end

	    --更新帮派伤害排行榜
	    if not data.damageRank then data.damageRank = {} end
	    local guildId = LActor.getGuildId(actor)
    	if 0 ~= guildId then
    		if not data.damageRank[guildId] then data.damageRank[guildId] = {} end
    		data.damageRank[guildId].value = (data.damageRank[guildId].value or 0) + value
    		if not data.damageRank[guildId].serverId then data.damageRank[guildId].serverId = LActor.getServerId(actor) end
    		if not data.damageRank[guildId].name then data.damageRank[guildId].name = LActor.getGuildName(actor) or "" end
    	end
	end
end

--退出的处理
local function onExitFb(ins, actor)
	local data = getBossData(ins.data.id)

	--boss归属者退出副本
	if data.bossBelong and actor == data.bossBelong then onBelongChange(ins.data.id, actor, nil) end

	--记录cd
	local var = getCrossStaticData(actor)
	var.scene_cd = System.getNowTime() + DevilBossBase.cdTime

	--删除复活定时器
	if var.rebornEid then LActor.cancelScriptEvent(actor, var.rebornEid) var.rebornEid = nil end

	--退出把AI恢复
	local role_count = LActor.getRoleCount(actor)
	for i = 0,role_count - 1 do
		local role = LActor.getRole(actor,i)
		LActor.setAIPassivity(role, false)
	end
end

local function onOffline(ins, actor)
	LActor.exitFuben(actor)
end

local function onActorDie(ins, actor, killerHdl)
	if not actor then return end
	local et = LActor.getEntity(killerHdl)
    if not et then print("devilbossfb.onActorDie:et is null") return end

    local bossData = getBossData(ins.data.id)
    if nil == bossData then print("devilbossfb.onActorDie:bossData is null, id:"..ins.data.id) return end

    local killer_actor = LActor.getActor(et)

    --变更boss归属
    if actor == bossData.bossBelong then
    	if killer_actor and LActor.getFubenHandle(killer_actor) == ins.handle then
    		onBelongChange(ins.data.id, actor, killer_actor)
    	else
    		onBelongChange(ins.data.id, actor, nil)
    	end
    end

    if killer_actor then LActor.stopAI(killer_actor) end

    --复活定时器
    local var = getCrossStaticData(actor)
	var.resurgence_cd = System.getNowTime() + DevilBossBase.rebornCd
	var.rebornEid = LActor.postScriptEventLite(actor, DevilBossBase.rebornCd * 1000, reborn, ins.data.id)

    notifyRebornTime(actor, killerHdl)
end

--BOSS死亡时候的处理
local function onMonsterDie(ins, mon, killerHdl)
    local bossId = ins.data.bossId
    local monId = Fuben.getMonsterId(mon)
    if monId ~= bossId then
		print("devilbossfb.onMonsterDie:monid("..tostring(monId)..") ~= bossId("..tostring(bossId).."), id:"..ins.data.id)
		return
	end

	local conf = DevilBossConfig[ins.data.id]

	local data = getBossData(ins.data.id)
	if data.bossBelong then
		local actorId = LActor.getActorId(data.bossBelong)

		--奖励弹框
		sendReward(ins.data.id, data.bossBelong)

		LActor.stopAI(data.bossBelong)
		onBelongChange(ins.data.id, data.bossBelong, nil)

		print("devilbossfb.onMonsterDie, belong reward, belongId:"..tostring(actorId)..", actorFbh:"..tostring(LActor.getFubenHandle(data.bossBelong))..
		", fbH:"..tostring(ins.handle).."id:"..tostring(ins.data.id))
	end

	--保存boss击杀
	setSysData(ins.data.id, nil, 1)

	local et = LActor.getEntity(killerHdl)
	if et then
		local killer_actor = LActor.getActor(et)
		if killer_actor then LActor.stopAI(killer_actor) end

		print("devilbossfb.onMonsterDie, die success, monId:"..tostring(monId)..", actorFbh:"..tostring(LActor.getFubenHandle(killer_actor))..
		", fbH:"..tostring(ins.handle).."id:"..tostring(ins.data.id).."actorid:"..tostring(LActor.getActorId(killer_actor)))
	end

	data.monster = nil
	data.iskill = 1
	sendBossInfo()

	ins:win()
end

local function onReqBuyCd(actor, packet)
    local data = getCrossStaticData(actor)

    --没有死光不能复活
	if false == LActor.isDeath(actor) then
		print("devilbossfb.onReqBuyCd: not all die,  actorId:"..LActor.getActorId(actor))
    	return
	end

	--复活时间已到
    if (data.resurgence_cd or 0) < System.getNowTime() then
    	print("devilbossfb.onReqBuyCd: reborn not in cd,  actorId:"..LActor.getActorId(actor))
    	return
    end

	--扣钱
    local yb = LActor.getCurrency(actor, NumericType_YuanBao)
    if DevilBossBase.rebornCost + (data.needCost or 0) > yb then
    	print("devilbossfb.onReqBuyCd: money not enough, actorId:"..LActor.getActorId(actor))
    	return
    end

    --跨服不扣元宝，回本服再扣
    if System.isCommSrv() then
		LActor.changeYuanBao(actor, 0 - DevilBossBase.rebornCost, "servercrossboss buy cd")
	else
		data.needCost = (data.needCost or 0) + DevilBossBase.rebornCost
	end

    --重置复活cd和定时器
	if data.rebornEid then LActor.cancelScriptEvent(actor, data.rebornEid) end
	data.rebornEid = nil
	data.resurgence_cd = nil

	notifyRebornTime(actor)

	--原地复活
	local x, y = LActor.getPosition(actor)
	LActor.relive(actor, x, y)

	setCamp(actor)
end

--取消归属者
local function onCancelBelong(actor, packet)
	local data = getGlobalData()
	for id, info in pairs(data.bossList or {}) do
		if info.bossBelong and info.bossBelong == actor then
			onBelongChange(id, actor, nil)
			LActor.stopAI(actor)

			print("devilbossfb.onCancelBelong: cancel belong success, actorId:"..tostring(LActor.getActorId(actor)))
		end
	end
end

--开始活动
local function createFb(id, curTime, isInit)
	local data = getGlobalData()
	if not data.bossList then data.bossList = {} end

	if not data.bossList[id] or data.bossList[id].iskill then
		local conf = DevilBossConfig[id]
		local fbHandle = Fuben.createFuBen(conf.fbid)
		local ins = instancesystem.getInsByHdl(fbHandle)
		local bossId = getBossId(conf)
		if ins then
			ins.data.id = id
			ins.data.bossId = bossId
		else
			print("devilbossfb.createFb:ins nil, id:"..tostring(id))
			return
		end

		local monster = Fuben.createMonster(ins.scene_list[1], bossId)
		if not monster then print("devilbossfb.createFb:monster nil, id:"..tostring(bossId)) return end

		data.bossList[id] = {}
		data.bossList[id].id = id
		data.bossList[id].fbHandle = fbHandle
		data.bossList[id].monster = monster
		data.bossList[id].refreshTime = curTime
		data.bossList[id].iskill = nil

		if not isInit then setSysData(id, curTime) end

		if conf.refreshNoticeId then
			noticemanager.broadCastNotice(conf.refreshNoticeId, MonstersConfig[bossId].name or "")
		end

		print("devilbossfb.createFb success, id:"..tostring(id)..", time:"..tostring(curTime))
	end
end

--活动开始
function devilBossOpen()
	print("start to devilBossOpen")

	--创建副本
	if not System.isCommSrv() then
		local curTime = System.getNowTime()
		for id, info in ipairs(DevilBossConfig or {}) do createFb(id, curTime, false) end

		sendBossInfo()
	end
	print("end to devilBossOpen")
end
_G.DevilBossOpen = devilBossOpen

--服务器连接上来的时候
local function OnServerConn(sId, sType)
	sendBossInfo(sId)
	print("devilbossfb.OnServerConn:sendBossInfo scccess, srvId:"..tostring(sId))
end

--起服的时候根据记录创建副本
local function InitFubenHandle()
	local data = getGlobalData()
	if not data.bossList then data.bossList = {} end

	local gVar = getSysData()
	for id, info in pairs(gVar.bossList or {}) do
		if info.iskill then
			if not data.bossList[id] then data.bossList[id] = {} end
			data.bossList[id].id = id
			data.bossList[id].iskill = info.iskill
		else
			createFb(id, info.refreshTime, true)
		end
	end

	sendBossInfo()
end

--启动初始化
local function initGlobalData()
	--注册副本事件
	if not System.isCommSrv() then
		for _, conf in pairs(DevilBossConfig) do
			insevent.registerInstanceEnter(conf.fbid, onEnterFb)
			insevent.registerInstanceMonsterDamage(conf.fbid, onBossDamage)
			insevent.registerInstanceExit(conf.fbid, onExitFb)
			insevent.registerInstanceOffline(conf.fbid, onOffline)
			insevent.registerInstanceActorDie(conf.fbid, onActorDie)
			insevent.registerInstanceMonsterDie(conf.fbid, onMonsterDie)
	    end

		netmsgdispatcher.reg(Protocol.CMD_DevilBoss, Protocol.cDevilBossCmd_CancelBelong, onCancelBelong)
	    netmsgdispatcher.reg(Protocol.CMD_DevilBoss, Protocol.cDevilBossCmd_BuyCd, onReqBuyCd)

		--游戏服连接的时候
		csbase.RegConnected(OnServerConn)
	end
end

table.insert(InitFnTable, initGlobalData)

engineevent.regGameStartEvent(InitFubenHandle)



local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.devilboss1 = function(actor, args)
	devilBossOpen()
end

