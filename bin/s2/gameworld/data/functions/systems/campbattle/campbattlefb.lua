--[[
个人信息
	resurgence_cd  	复活cd
	scene_cd 		进入场景时间
	multi_kill 		连杀数
	cur_camp        当前阵营
	rebornEid 		复活定时器句柄
	addAttributeCount 属性加成次数

camp_battle_fb
	is_open			是否开启中
	rankingData  当前活动积分信息
	integralRank 积分榜
	hfuben 副本句柄
	endTime  活动结束时间
	nextCamp  下个人分配的阵营
	assignTimes 已切换阵营次数
	firstBlood  是否首杀
	beginTime   新一轮战斗开始的时间

	attackerList =
	{
		[actorid,被攻击者] = {
			[actorid,攻击者] = 最新攻击时间,
		}
	}
]]

module("campbattlefb", package.seeall)

local killPlayerIntegral = 1
local assistsIntegral = 2
local beKilledIntegral = 3
local joinIntegral = 4
local killMonsterIntegral = 5

local keyList = {}
for k in pairs(CampBattlePersonalRankAwardConfig or {}) do keyList[#keyList+1] = k end
table.sort(keyList)

local multiKillList = {}
for k in pairs(CampBattleMultiKillConfig or {}) do multiKillList[#multiKillList+1] = k end
table.sort(multiKillList)

camp_battle_fb = camp_battle_fb or {}

local function getData(actor)
	local var = LActor.getStaticVar(actor)
	if nil == var.camp_battle_fb then var.camp_battle_fb = {} end
	return var.camp_battle_fb
end

local function getGlobalData()
	return camp_battle_fb
end

--阵营战是否正在开启
local function isOpen()
	local data = getGlobalData()
	if not data.is_open then return false end
	return true
end

--检测开启等级
function checkOpenLevel(actor)
	local level = LActor.getZhuanShengLevel(actor) * 1000
	level = level + LActor.getLevel(actor)
	if level < CampBattleConfig.openLevel then return false end

	return true
end

--检测活动开启条件
local function checkOpenCondition()
	local openDay = System.getOpenServerDay() + 1
	if openDay < CampBattleConfig.openDay then return false end

	return true
end

--初始化个人信息
local function initActorData(actor)
	local var = getData(actor)
	var.rebornEid = nil
	var.resurgence_cd = nil
	var.multi_kill = nil
	var.addAttributeCount = nil
end

--发送开启信息
local function sendOpen(actor)
	local data = getGlobalData()
	local npack = nil
    if actor then
        npack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_Open)
    else
        npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, Protocol.CMD_CampBattle)
        LDataPack.writeByte(npack, Protocol.sCampBattleCmd_Open)
    end

    local endTime = (data.endTime or 0) - System.getNowTime()

    LDataPack.writeByte(npack, isOpen() and 1 or 0)
    LDataPack.writeInt(npack, (endTime > 0) and endTime or 0)

    if actor then
        LDataPack.flush(npack)
    else
        System.broadcastData(npack)
    end
end

--发送进入cd信息
local function sendEnterCd(actor)
	if not isOpen() then return end
	local var = getData(actor)
	local time = (var.scene_cd or 0) > System.getNowTime() and (var.scene_cd or 0) - System.getNowTime() or 0

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_NotifyCd)
	LDataPack.writeInt(npack, time)
	LDataPack.flush(npack)
end

--通知当前击杀人数变化
local function SendKillCount(actor)
	local var = getData(actor)
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_CampBattle,Protocol.sCampBattleCmd_SendKillCount)
	LDataPack.writeInt(npack, var.multi_kill or 0)
	LDataPack.flush(npack)
end

--排行榜添加个人信息
local function addRankPersonData(actor, addIntegral)
	local actorId = LActor.getActorId(actor)
	local data = getGlobalData()
	if not data.rankingData then data.rankingData = {} end
	local info = data.rankingData[actorId]

	--不存在则添加
	if not info then
		data.rankingData[actorId] = {camp = LActor.getCamp(actor), integral = addIntegral}
	else
		info.integral = info.integral + addIntegral
	end
end

--对应增加个人积分
local function addAllIntegral(actor, addIntegral, flag, name)
	campbattlepersonaward.addIntegral(actor, addIntegral, flag, name)
	addRankPersonData(actor, addIntegral)
end

--自动增加积分
local function autoAddIntegral()
	if not isOpen() then return end

	local data = getGlobalData()
	local actors = Fuben.getAllActor(data.hfuben)
	if actors then
		for i = 1, #actors do addAllIntegral(actors[i], CampBattleConfig.addIntegral, joinIntegral) end
	end

	LActor.postScriptEventLite(nil, CampBattleConfig.addIntegralSec * 1000, function() autoAddIntegral() end)
end

--积分排序
local function sortIntegral()
	local data = getGlobalData()
	if nil == data.rankingData then return end
	data.integralRank = {}

	for id, v in pairs(data.rankingData or {}) do
        table.insert(data.integralRank, {aid = id, integral = v.integral, camp = v.camp})
    end

	table.sort(data.integralRank, function(a, b) return a.integral > b.integral end)
end

--获取个人排名信息
local function getPersonRank(actor)
	local data = getGlobalData()
	local aid = LActor.getActorId(actor)
	for k, v in pairs(data.integralRank or {}) do
		if aid == v.aid then return k, v.integral or 0 end
	end

	return 0, 0
end

--设置角色主动还是被动寻怪
local function setAIPassivity(actor, ispassive)
	for i = 0, LActor.getRoleCount(actor) - 1 do
		local role = LActor.getRole(actor, i)
		LActor.setAIPassivity(role, ispassive)
	end
end

--生成排行榜信息
local function makeCampRankingTop(actor)
	local data = getGlobalData()
	if nil == data.integralRank then return end

	local npack = nil
	if actor then
		npack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_RankingTopData)
	else
		 npack = LDataPack.allocBroadcastPacket(Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_RankingTopData)
	end


	local size = CampBattleConfig.campIntegralRaningBoardSize or 0
	LDataPack.writeInt(npack, #data.integralRank >= size and size or #data.integralRank)
	for k=1, #data.integralRank do
		local info = data.integralRank[k]

		LDataPack.writeShort(npack, k)
		LDataPack.writeShort(npack, info.camp)
		LDataPack.writeString(npack, LActor.getActorName(info.aid or 0) or "")
		LDataPack.writeString(npack, LGuild.getGuildName(LActor.getGuildPtr(LActor.getActorById(info.aid or 0))) or "")
		LDataPack.writeInt(npack, info.integral or 0)

		size = size - 1
		if 0 >= size then break end
	end

	if actor then
		LDataPack.flush(npack)
	else
		Fuben.sendData(data.hfuben, npack)
	end
end

--发送我的排行信息
local function sendMyRankingData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_MyData)
	local rank, score = getPersonRank(actor)

	LDataPack.writeInt(npack, rank)
	LDataPack.writeInt(npack, score)

	LDataPack.flush(npack)
end

--属性加成
local function addAttribute(actor)
	local data = getData(actor)
	local times = data.addAttributeCount or 0
	if 0 >= times then return end

	local count = LActor.getRoleCount(actor)
	for roleId=0, count-1 do
		local campAttr = LActor.GetCampBattleAttrs(actor, roleId)
		if not campAttr then return end
		campAttr:Reset()

		local basicAttr = LActor.getRoleBasicAttr(actor, roleId)
		if not basicAttr then return end
		for _, v in pairs(CampBattleConfig.addAttribute or {}) do
			local value = basicAttr:Get(v.type)
			campAttr:Add(v.type, math.floor(value * times * v.precent/10000))
		end
	end

	LActor.reCalcBattleAttr(actor)
end

--分配阵营
local function assignCamp()
	local data = getGlobalData()
	local campType = 0
	--两边没人随机分配
	if not data.nextCamp then
		campType = math.random(CampType_CampBattle_Ice, CampType_CampBattle_Fire)
	else
		campType = data.nextCamp
	end

	data.nextCamp = (campType == CampType_CampBattle_Ice) and CampType_CampBattle_Fire or CampType_CampBattle_Ice

	return campType
end

--通知活动结束
local function notifyEnd(actor)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_NotifyEnd)
    LDataPack.flush(npack)
end

--通知倒计时开始
local function notifyCountDown()
	local data = getGlobalData()
	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_NotifyCountDown)
    LDataPack.writeInt(npack, System.getNowTime() + (CampBattleConfig.assignPer - CampBattleConfig.stopAiTimes))
    Fuben.sendData(data.hfuben, npack)
end

--通知新一轮战斗开始
local function notifyBeginNewRound(actor)
	--最后一次不发
	local data = getGlobalData()
	if (data.assignTimes or 0) >= CampBattleConfig.assigncounts then return end

    if actor then
        npack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_NotifyBeginNewRound)
    else
        npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, Protocol.CMD_CampBattle)
        LDataPack.writeByte(npack, Protocol.sCampBattleCmd_NotifyBeginNewRound)
    end

	local data = getGlobalData()
    local endTime = data.beginTime + CampBattleConfig.assignPer
    LDataPack.writeInt(npack, endTime)

    if actor then
        LDataPack.flush(npack)
    else
        Fuben.sendData(data.hfuben, npack)
    end
end

--发送积分榜
local function sendRankingTopData(actor)
	makeCampRankingTop(actor)
	sendMyRankingData(actor)
end

--广播积分榜
local function autoBroadcastRankingTop()
	if not isOpen() then return end
	--积分排序
	sortIntegral()

	makeCampRankingTop()

	local data = getGlobalData()
	local actors = Fuben.getAllActor(data.hfuben)
	if actors then
		for i=1, #actors do	sendMyRankingData(actors[i]) end
	end

	--添加积分排行榜定时器
	LActor.postScriptEventLite(nil, CampBattleConfig.integralRaningBoardInterval * 1000, function() autoBroadcastRankingTop() end)
end

--获取随机坐标
local function getRandomPoint()
    local index = math.random(1, #CampBattleConfig.birthPoint)
	local x = CampBattleConfig.birthPoint[index].x or 0
	local y = CampBattleConfig.birthPoint[index].y or 0

    return x, y
end

--停止副本ai
local function autoStopAi()
	--是否开启
	if false == isOpen() then return end

	--是否超过总切换次数
	local data = getGlobalData()
	if (data.assignTimes or 0) >= CampBattleConfig.assigncounts then return end

	Fuben.setIsNeedAi(data.hfuben, false)

	--通知停止ai
	notifyCountDown()

	print("campbattlefb.autoStopAi: this is count:"..tostring(data.assignTimes or 0))
end

--切换阵营
local function autoAssignCamp()
	--是否开启
	if false == isOpen() then return end

	--是否超过总切换次数
	local data = getGlobalData()
	if (data.assignTimes or 0) >= CampBattleConfig.assigncounts then return end

	data.nextCamp = nil
	data.assignTimes = (data.assignTimes or 0) + 1
	data.beginTime = System.getNowTime()

	local actors = Fuben.getAllActor(data.hfuben)
	if actors then
		for i=1, #actors do
			local data = getData(actors[i])
			data.cur_camp = assignCamp()
			LActor.setCamp(actors[i], data.cur_camp or 0)
			--清除定时器
			if data.rebornEid then LActor.cancelScriptEvent(actors[i], data.rebornEid) end

			--满血复活
			local x, y = getRandomPoint()
			--LActor.reEnterScene(actors[i], x, y)
			LActor.recover(actors[i])
			LActor.instantMove(actors[i], x, y)

			LActor.stopAI(actors[i])
		end
	end

	--通知新的战斗开始
	notifyBeginNewRound()

	--开始ai
	Fuben.setIsNeedAi(data.hfuben, true)

	--添加停止ai定时器
	LActor.postScriptEventLite(nil, CampBattleConfig.stopAiTimes * 1000, function() autoStopAi() end)

	--添加切换阵营定时器
	LActor.postScriptEventLite(nil, CampBattleConfig.assignPer * 1000, function() autoAssignCamp() end)


	print("campbattlefb.autoAssignCamp: this is count:"..tostring(data.assignTimes or 0))
end

--通知玩家的复活信息
local function notifyRebornTime(actor, killerHdl)
    local data = getData(actor)
    local rebornCd = (data.resurgence_cd or 0) - System.getNowTime()
    if rebornCd < 0 then rebornCd = 0 end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_ResurgenceInfo)
    LDataPack.writeInt(npack, rebornCd)
    LDataPack.writeDouble(npack, killerHdl or 0)
    LDataPack.flush(npack)
end

--进入cd检测
local function checkIsInEnterCd(actor)
	local data = getData(actor)
	if (data.scene_cd or 0) > System.getNowTime() then return true end

	return false
end

--添加攻击者
local function addAttackInfo(actor, tActor)
	local data = getGlobalData()
	if not data.attackerList then data.attackerList = {} end
	local actorId = LActor.getActorId(actor)
	local tActorId = LActor.getActorId(tActor)

	local info = data.attackerList[actorId]
	if not info then
		data.attackerList[actorId] = {[tActorId]=System.getNowTime()}
	else
		info[tActorId] = System.getNowTime()
	end
end

--根据排名获取邮件配置
local function getMailConfig(index)
	for i = #keyList, 1, -1 do
		if index >= keyList[i] then return CampBattlePersonalRankAwardConfig[keyList[i]] end
	end

	return nil
end

--根据杀人数量获取配置
local function getKillConfig(number)
	for i = #multiKillList, 1, -1 do
		if number >= multiKillList[i] then return CampBattleMultiKillConfig[multiKillList[i]] end
	end

	return nil
end

--筛选助攻者加积分
local function addAssistsIntegral(beKillActor, killerActor, assistsScore)
	local data = getGlobalData()
	if not data.attackerList then data.attackerList = {} end
	local actorId = LActor.getActorId(beKillActor)
	local killerActorId = LActor.getActorId(killerActor)

	local info = data.attackerList[actorId]
	if not info then return end
	local nowTime = System.getNowTime()

	for aid, time in pairs(info or {}) do
		if nowTime - time <= CampBattleConfig.assistsTIme and killerActorId ~= aid then
			local actor = LActor.getActorById(aid)
			if actor then
				addAllIntegral(actor, CampBattleConfig.assistsIntegral + assistsScore, assistsIntegral, LActor.getName(beKillActor))
			end
		end
	end

	--删除数据
	table.remove(data.attackerList, actorId)
end

--复活定时器
local function reborn(actor)
	--是否开启
	if false == isOpen() then print("campbattlefb.reborn: not open") return false end

	notifyRebornTime(actor)

	local x, y = getRandomPoint()
	LActor.relive(actor, x, y)

	addAttribute(actor)

	LActor.stopAI(actor)
end

--买活
local function buyRebornCd(actor)
	--是否开启
	if false == isOpen() then print("campbattlefb.buyRebornCd: not open") return end

	local var = getData(actor)

	--没有死光不能复活
	if false == LActor.isDeath(actor) then
		print("campbattlefb.buyRebornCd: not all die,  actorId:"..LActor.getActorId(actor))
    	return
	end

	--复活时间已到
    if (var.resurgence_cd or 0) < System.getNowTime() then
    	print("campbattlefb.buyRebornCd: reborn not in cd,  actorId:"..LActor.getActorId(actor))
    	return
    end

    --扣钱
    local yb = LActor.getCurrency(actor, NumericType_YuanBao)
    if CampBattleConfig.buyRebornCdCost > yb then
    	print("campbattlefb.buyRebornCd: money not enough, actorId:"..LActor.getActorId(actor))
    	return
    end

	LActor.changeYuanBao(actor, 0 - CampBattleConfig.buyRebornCdCost, "campbattlefb buy cd")

	--重置复活cd和定时器
	if var.rebornEid then LActor.cancelScriptEvent(actor, var.rebornEid) end
	var.rebornEid = nil
	var.resurgence_cd = nil

	--原地复活
	local x, y = LActor.getPosition(actor)
	LActor.relive(actor, x, y)
	addAttribute(actor)

	LActor.stopAI(actor)

    notifyRebornTime(actor)
end

--清空阵营属性
local function clearCampBattleAttr(actor)
	local data = getData(actor)
	data.addAttributeCount = 0

	local count = LActor.getRoleCount(actor)
	for roleId=0, count-1 do
		local campAttr = LActor.GetCampBattleAttrs(actor, roleId)
		if campAttr then campAttr:Reset() end
	end

	LActor.reCalcAttr(actor)
end

--首杀公告
local function firstBloodNotice(actor)
	local data = getGlobalData()
	if not data.firstBlood then
		noticemanager.broadCastNotice(CampBattleConfig.firstBloodNotice, LActor.getName(actor) or "")
		data.firstBlood = true
	end
end

--个人排名奖励邮件
local function sendPersonalRankAward()
	local data = getGlobalData()

	if not data.integralRank then print("campbattlefb.sendPersonalRankAward: integralRank is null") return end

	for k=#data.integralRank, 1, -1 do
		local info = data.integralRank[k]
		local conf = getMailConfig(k)
		if conf then
			local mail_data = {}
			mail_data.head = CampBattleConfig.personalRankAwardHead
			mail_data.context = string.format(CampBattleConfig.personalRankAwardContext, k)
			mail_data.tAwardList = conf.award
			mailsystem.sendMailById(info.aid, mail_data)
		end

		--给玩家弹框
		local actor = LActor.getActorById(info.aid)
		if actor then
			local ins = instancesystem.getInsByHdl(data.hfuben)
			if ins and LActor.getFubenHandle(actor) == ins.handle then notifyEnd(actor) end

			actorevent.onEvent(actor, aeCampBattleFb)
		end
	end
end

--结束定时器
local function endTimer()
	sendPersonalRankAward()
	camp_battle_fb = {}
	sendOpen(nil)

	print("campBattle ends")
end

local function onEnter(actor, packet)
	--是否开启
	if false == isOpen() then print("campbattlefb.onEnter: not open") return end

	--检测等级
	if false == checkOpenLevel(actor) then
		print("campbattlefb.onEnter: level limit, actorId:"..LActor.getActorId(actor))
		return
	end

	--是否在副本
	if LActor.isInFuben(actor) then
		print("campbattlefb.onEnter:actor is in fuben. actorId:".. LActor.getActorId(actor))
		return
	end

	--cd检测
	if true == checkIsInEnterCd(actor) then
		print("campbattlefb.onEnter:in enter cd. actorId:".. LActor.getActorId(actor))
		return
	end

	local var = getData(actor)

	--没有阵营就分配阵营
	if not var.cur_camp then var.cur_camp = assignCamp() end

	LActor.setCamp(actor, var.cur_camp or 0)

	--设置为false表示进入场景不会改变阵营
	LActor.setCanChangeCamp(actor, false)

	local data = getGlobalData()

	--随机点进入
	local x, y = getRandomPoint()
	LActor.enterFuBen(actor, data.hfuben, 0, x, y)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_Enter)
	LDataPack.writeShort(npack, var.cur_camp or 0)

	--发送活动剩余时间
	LDataPack.writeInt(npack, data.endTime or 0)

	LDataPack.flush(npack)
end

local function onOffline(ins, actor)
	LActor.exitFuben(actor)
end

local function onExitFb(ins, actor)
	setAIPassivity(actor, false)

	--设置为true表示进入场景会改变阵营,还原之前的改动
	LActor.setCanChangeCamp(actor, true)

	local var = getData(actor)

	--重置复活cd和定时器
	if var.rebornEid then LActor.cancelScriptEvent(actor, var.rebornEid) end
	initActorData(actor)

	--记录cd
	var.scene_cd = System.getNowTime() + CampBattleConfig.exitAndOfflineSwitchSceneCd
	sendEnterCd(actor)

	--清空阵营属性
	clearCampBattleAttr(actor)
end

local function onMonsterDie(ins, mon, killer_hdl)
	local et = LActor.getEntity(killer_hdl)
	local killer_actor = LActor.getActor(et)
	if killer_actor then
		addAllIntegral(killer_actor, CampBattleConfig.killMonsterIntegral, killMonsterIntegral)
		LActor.stopAI(killer_actor)
	end
end

local function onFbEnter(ins, actor)
	-- 设置主动
	LActor.stopAI(actor)

	--排行榜数据
	sendRankingTopData(actor)

	--发送积分奖励数据
	campbattlepersonaward.sendPersonalAwardData(actor)

	notifyBeginNewRound(actor)
end

--攻击列表
local function onRoleDamage(ins, actor, role, value, attacker, res)
	if not attacker or not actor then return end

	local tActor = LActor.getActor(attacker)
	if tActor then addAttackInfo(actor, tActor) end
end

local function onActorDie(ins, actor, killerHdl)
	if not actor then return end
	local var = getData(actor)

	--杀人的人停止AI
	local et = LActor.getEntity(killerHdl)
	if et then
		local killer_actor = LActor.getActor(et)
		if killer_actor then
			local TargetActor = LActor.getActorByEt(LActor.getAITarget(et))
			if TargetActor and TargetActor == actor then LActor.stopAI(killer_actor) end

			--杀人者减少属性加成次数
			local killVar = getData(killer_actor)
			killVar.addAttributeCount = (killVar.addAttributeCount or 0) - 1
			if (killVar.addAttributeCount or 0) < 0 then killVar.addAttributeCount = 0 end
			addAttribute(killer_actor)

			--杀人数累加
			killVar.multi_kill = (killVar.multi_kill or 0) + 1
			SendKillCount(killer_actor)

			--首杀公告
			firstBloodNotice(killer_actor)

			--加积分
			local score = 0
			local assistsScore = 0
			local conf = getKillConfig(var.multi_kill or 0)
			if conf then
				score = conf.killScore
				assistsScore = conf.assistsScore
			end

			addAllIntegral(killer_actor, CampBattleConfig.killPlayerIntegral + score, killPlayerIntegral, LActor.getName(actor))

			--连杀公告
			conf = nil
			conf = getKillConfig(killVar.multi_kill or 0)
			if conf then noticemanager.broadCastNotice(conf.id, LActor.getName(killer_actor)) end

			--被杀死也有积分拿
			addAllIntegral(actor, CampBattleConfig.beKilledIntegral, beKilledIntegral, LActor.getName(killer_actor))

			--助攻积分
			addAssistsIntegral(actor, killer_actor, assistsScore)
		end
	end

	--复活定时器
	var.resurgence_cd = System.getNowTime() + CampBattleConfig.rebornCd
	var.rebornEid = LActor.postScriptEventLite(actor, CampBattleConfig.rebornCd * 1000, reborn)

	notifyRebornTime(actor, killerHdl)

	--重置连杀次数
	var.multi_kill = 0
	SendKillCount(actor)

	--被杀死的人增加属性加成次数
	var.addAttributeCount = (var.addAttributeCount or 0) + 1

	LActor.sendTipmsg(actor, string.format(LAN.FUBEN.qmbs20, var.addAttributeCount*30), ttScreenCenter)
end

local function onReqBuyCd(actor, packet)
	buyRebornCd(actor)
end

local function onLogin(actor)
	sendOpen(actor)
	sendEnterCd(actor)
end

local function onNewDay(actor)
	local var = getData(actor)
	var.cur_camp = nil
	initActorData(actor)
end

--开启预告
local function advanceNotice()
	if false == checkOpenCondition() then return end

	noticemanager.broadCastNotice(CampBattleConfig.advanceNotice)

	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_Open)
	LDataPack.writeByte(npack, isOpen() and 1 or 0)
    LDataPack.writeInt(npack, CampBattleConfig.countTimes)

    System.broadcastData(npack)
end
_G.CampBattleAdvance = advanceNotice

--开启
local function campBattleOpen()
	if false == checkOpenCondition() then return end

	local hfuben = Fuben.createFuBen(CampBattleConfig.fbId)
	if 0 == hfuben then print("campbattle.campBattleOpen:createFuBen false") return end

	--保存开启时间
	prestigesystem.saveActivityOpenDay(prestigesystem.ActivityEvent.campbattle)

	camp_battle_fb = {}
	camp_battle_fb.hfuben = hfuben
	camp_battle_fb.endTime = System.getNowTime() + CampBattleConfig.lastTimes
	camp_battle_fb.is_open = true
	camp_battle_fb.beginTime = System.getNowTime()

	--添加自动增加积分定时器
	LActor.postScriptEventLite(nil, CampBattleConfig.addIntegralSec * 1000, function() autoAddIntegral() end)

	--添加积分排行榜定时器
	LActor.postScriptEventLite(nil, CampBattleConfig.integralRaningBoardInterval * 1000, function() autoBroadcastRankingTop() end)

	--添加停止ai定时器
	LActor.postScriptEventLite(nil, CampBattleConfig.stopAiTimes * 1000, function() autoStopAi() end)

	--添加切换阵营定时器
	LActor.postScriptEventLite(nil, CampBattleConfig.assignPer * 1000, function() autoAssignCamp() end)

	--添加活动结束定时器
	LActor.postScriptEventLite(nil, CampBattleConfig.lastTimes * 1000, function() endTimer() end)


	--开启活动
	noticemanager.broadCastNotice(CampBattleConfig.openNotice)

	sendOpen(nil)

	print("campBattle start open")
end
_G.CampBattleOpen = campBattleOpen


--初始化副本
local function initFunc()
    insevent.registerInstanceOffline(CampBattleConfig.fbId, onOffline)
    insevent.registerInstanceExit(CampBattleConfig.fbId, onExitFb)
    insevent.registerInstanceActorDie(CampBattleConfig.fbId, onActorDie)
    insevent.registerInstanceMonsterDie(CampBattleConfig.fbId, onMonsterDie)
    insevent.registerInstanceEnter(CampBattleConfig.fbId, onFbEnter)
    insevent.registerInstanceActorDamage(CampBattleConfig.fbId, onRoleDamage)


	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeNewDayArrive, onNewDay)

    netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_Enter, onEnter)
	netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_BuyCd, onReqBuyCd)
end
table.insert(InitFnTable, initFunc)

--这是一条很长的分割线
-------------------------------------------------------
function campbattleopen(actor, args)
	if 1 == tonumber(args[1]) then
		campBattleOpen()
	elseif 2 == tonumber(args[1]) then
		local var = getData(actor)
		var.cur_camp = nil
		initActorData(actor)
	elseif 3 == tonumber(args[1]) then
		local temp = tonumber(args[2]) == 1 and true or false
		Fuben.setIsNeedAi(camp_battle_fb.hfuben, temp)
	elseif 4 == tonumber(args[1]) then
		local x, y = getRandomPoint()
		LActor.reEnterScene(actor, x, y)
	elseif 5 == tonumber(args[1]) then
		endTimer()
	elseif 6 == tonumber(args[1]) then
		advanceNotice()
	end
end

function campbattlersf(actor)
	local var = System.getStaticVar()
	var.camp_battle = nil
end

function campbattleinit(actor)
end

