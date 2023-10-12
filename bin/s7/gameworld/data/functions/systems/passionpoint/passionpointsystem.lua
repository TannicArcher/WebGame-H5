--[[
个人信息
	scene_cd   进入场景时间
	resurgence_cd  	复活cd
	rebornEid 		复活定时器句柄

全局信息passion_point_fb
	isOpen  活动是否开启
	hfuben 副本句柄
	endTime  活动结束时间

	belongInfo
	{
		[belongid]=id  所有的归属者玩家，对应的区域
	}

	rankingData 积分榜(针对玉佩碎片的获得)
]]


module("passionpointsystem", package.seeall)

passion_point_fb = passion_point_fb or {}

local function getData(actor)
	local var = LActor.getStaticVar(actor)
	if nil == var.passionPoint then var.passionPoint = {} end

	return var.passionPoint
end

local function getGlobalData()
	if not passion_point_fb.belongInfo then passion_point_fb.belongInfo = {} end
	if not passion_point_fb.rankingData then passion_point_fb.rankingData = {} end
	if not passion_point_fb.integralRank then passion_point_fb.integralRank = {} end
	return passion_point_fb
end

--活动是否正在开启
function isOpen()
	local data = getGlobalData()
	if not data.is_open then return false end
	return true
end

--发送开启信息
function sendOpen(actor)
	local data = getGlobalData()
	local npack = nil
    if actor then
        npack = LDataPack.allocPacket(actor, Protocol.CMD_PassionPoint, Protocol.sPassionPointCMD_Open)
    else
        npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, Protocol.CMD_PassionPoint)
        LDataPack.writeByte(npack, Protocol.sPassionPointCMD_Open)
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

--进入cd检测
local function checkIsInEnterCd(actor)
	local data = getData(actor)
	if (data.scene_cd or 0) > System.getNowTime() then return true end

	return false
end

--发送归属信息
local function sendBelongInfo(actor)
	if not isOpen() then return end
	local data = getGlobalData()
	local npack = nil

	if actor then
		npack = LDataPack.allocPacket(actor, Protocol.CMD_PassionPoint, Protocol.sPassionPointCMD_BelongInfo)
	else
		 npack = LDataPack.allocBroadcastPacket(Protocol.CMD_PassionPoint, Protocol.sPassionPointCMD_BelongInfo)
	end

	LDataPack.writeInt(npack, table.getnEx(data.belongInfo))
	for actorId, id in pairs(data.belongInfo or {}) do
		LDataPack.writeShort(npack, id)
		LDataPack.writeDouble(npack, LActor.getHandle(LActor.getActorById(actorId)))
	end

	if actor then
		LDataPack.flush(npack)
	else
		Fuben.sendData(data.hfuben, npack)
	end
end

--排行榜添加个人信息
local function addRankPersonData(actor, levelExp, exp)
	local actorId = LActor.getActorId(actor)
	local data = getGlobalData()
	local info = data.rankingData[actorId]

	--不存在则添加
	if not info then
		data.rankingData[actorId] = {exp = levelExp, prestigeExp = exp}
	else
		info.exp = info.exp + levelExp
		info.prestigeExp = info.prestigeExp + exp
	end
end

--积分排序
local function sortIntegral()
	local data = getGlobalData()
	if 0 == table.getnEx(data.rankingData) then return end

	for id, v in pairs(data.rankingData or {}) do
        table.insert(data.integralRank, {aid = id, exp = v.exp, prestigeExp = v.prestigeExp})
    end

	table.sort(data.integralRank, function(a, b) return a.exp + a.prestigeExp > b.exp + b.prestigeExp end)
end

--生成排行榜信息
local function makeRankingTop()
	if not isOpen() then return end
	local data = getGlobalData()

	--排个序
	sortIntegral()

	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_PassionPoint, Protocol.sPassionPointCMD_Settlement)

	local size = PassionPointConfig.rankingBoardSize or 0
	LDataPack.writeInt(npack, #data.integralRank >= size and size or #data.integralRank)
	for k=1, #data.integralRank do
		local info = data.integralRank[k]
		LDataPack.writeShort(npack, k)
		LDataPack.writeString(npack, LActor.getActorName(info.aid or 0) or "")
		LDataPack.writeString(npack, LGuild.getGuildName(LActor.getGuildPtr(LActor.getActorById(info.aid or 0))) or "")
		LDataPack.writeInt(npack, info.exp or 0)
		LDataPack.writeInt(npack, info.prestigeExp or 0)

		size = size - 1
		if 0 >= size then break end
	end

	Fuben.sendData(data.hfuben, npack)
end

--获取个人排名信息
local function getPersonRank(actor)
	local data = getGlobalData()
	for id, data in pairs(data.rankingData or {}) do
		if id == LActor.getActorId(actor) then return data.exp or 0, data.prestigeExp or 0 end
	end

	return 0, 0
end

--设置归属者信息
local function setBelong(actorId, areaId)
	local data = getGlobalData()
	data.belongInfo[actorId] = areaId
end

--清除归属者信息
local function clearBelongInfo(id)
	local data = getGlobalData()
	table.removeItem(data.belongInfo or {}, id)
end

--获取归属区域id，nil表示不是归属
local function getBelongId(actor)
	local data = getGlobalData()
	return data.belongInfo[LActor.getActorId(actor)]
end

--获取该区域的归属者，nil表示木有
local function getAreaBelong(id)
	local data = getGlobalData()
	for actorId, areaId in pairs(data.belongInfo or {}) do
		if areaId == id then return actorId end
	end

	return nil
end

--更新自己的区域id
local function updateMyselfArea(actor)
	local areaId = nil
	if LActor.InSafeArea(actor) then
		areaId = PassionPointConfig.saveAreaId
	else
		areaId = getBelongId(actor)
		if not areaId then areaId = PassionPointConfig.doubleAreaId end
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_PassionPoint, Protocol.sPassionPointCMD_UpdateArea)
	LDataPack.writeInt(npack, areaId or 0)
	LDataPack.flush(npack)
end

--获取区域的玩家列表
local function getAreaActorList(id)
	local data = getGlobalData()
	local list = {}
	local actors = Fuben.getAllActor(data.hfuben)
	if actors then
		for i=1, #actors do
			if not LActor.isDeath(actors[i]) then
				local areaId = LActor.getSceneAreaIParm(actors[i], aaPassPoint)
				if areaId and id == areaId then table.insert(list, LActor.getActorId(actors[i])) end
			end
		end
	end

	return list
end

--随机选出归属者
local function randomBelong(id)
	--先获取处于该区域id的玩家列表
	local list = getAreaActorList(id)

	--该区域没其他人
	if 0 == table.getnEx(list) then return end

	local index = math.random(1, #list)

	--新的归属者
	setBelong(list[index], id)

	updateMyselfArea(LActor.getActorById(list[index]))

	print("passionpointsystem.randomBelong:randomBelong, actorId:"..list[index]..", id:"..id)
end

--自动发奖励
local function autoSendReward()
	if not isOpen() then return end

	local data = getGlobalData()

	local actors = Fuben.getAllActor(data.hfuben)
	if actors then
		for i=1, #actors do
			--先判断是否归属
			local areaId = getBelongId(actors[i])
			if not areaId then   --二倍区和安全区的人都有奖励
				areaId = LActor.InSafeArea(actors[i]) and PassionPointConfig.saveAreaId or PassionPointConfig.doubleAreaId
			end

			local conf = PassionPointAwardConfig[areaId]
			if conf then
				LActor.giveAwards(actors[i], conf.reward, "passionIntervalReward")

				--local exp, count = LActor.getCountByType(conf.reward, PassionPointConfig.sortType)
				addRankPersonData(actors[i], conf.exp, conf.prestigeExp)

				LActor.sendTipmsg(actors[i], string.format(conf.hint, conf.exp, conf.prestigeExp), ttScreenCenter)
			end
		end
	end

	LActor.postScriptEventLite(nil, PassionPointConfig.sendAwardSec * 1000, function() autoSendReward() end)
end

--返回自己的信息
local function onReqMyselfInfo(actor, packet)
	local exp, prestigeExp = getPersonRank(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_PassionPoint, Protocol.sPassionPointCMD_ReqMyselfInfo)
    LDataPack.writeInt(npack, exp)
    LDataPack.writeInt(npack, prestigeExp)
    LDataPack.flush(npack)
end

--结束定时器
local function endTimer()
	--发送排行榜
	makeRankingTop()

	--发送个人数据
	local data = getGlobalData()
	local actors = Fuben.getAllActor(data.hfuben)
	if actors then
		for i=1, #actors do	onReqMyselfInfo(actors[i]) end
	end

	passion_point_fb = {}
	sendOpen(nil)
	print("passionpoint ends")
end

--发送进入cd信息
local function sendEnterCd(actor)
	if not isOpen() then return end
	local var = getData(actor)
	local time = (var.scene_cd or 0) > System.getNowTime() and (var.scene_cd or 0) - System.getNowTime() or 0

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_PassionPoint, Protocol.sPassionPointCMD_NotifyCd)
	LDataPack.writeInt(npack, time)
	LDataPack.flush(npack)
end

--获取随机坐标
local function getRandomPoint()
    local index = math.random(1, #PassionPointConfig.birthPoint)
	local x = PassionPointConfig.birthPoint[index].x or 0
	local y = PassionPointConfig.birthPoint[index].y or 0

    return x, y
end

--检测开启条件
local function checkOpenCondition(actor)
	local actorId = LActor.getActorId(actor)
	local level = LActor.getZhuanShengLevel(actor) * 1000
	level = level + LActor.getLevel(actor)
	if level < PassionPointConfig.openLv then return false end

	local openDay = System.getOpenServerDay() + 1
	if openDay < PassionPointConfig.openDay then return false end

	return true
end

--通知玩家的复活信息
local function notifyRebornTime(actor, killerHdl)
    local data = getData(actor)
    local rebornCd = (data.resurgence_cd or 0) - System.getNowTime()
    if rebornCd < 0 then rebornCd = 0 end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_PassionPoint, Protocol.sPassionPointCMD_ResurgenceInfo)
    LDataPack.writeInt(npack, rebornCd)
    LDataPack.writeDouble(npack, killerHdl or 0)
    LDataPack.flush(npack)
end

--复活定时器
local function reborn(actor)
	if not actor then return end
	--是否开启
	if false == isOpen() then print("passionpointsystem.reborn: not open") return end

	notifyRebornTime(actor)

	local x, y = getRandomPoint()
	LActor.relive(actor, x, y)
	LActor.setCamp(actor, LActor.getActorId(actor))

	LActor.stopAI(actor)

	LActor.addEffect(actor, PassionPointConfig.buffId)

	--等待复活都在安全区
	updateMyselfArea(actor)
end

--买活
local function buyRebornCd(actor)
	--是否开启
	if false == isOpen() then print("passionpointsystem.buyRebornCd: not open") return end

	local var = getData(actor)

	--没有死光不能复活
	if false == LActor.isDeath(actor) then
		print("passionpointsystem.buyRebornCd: not all die,  actorId:"..LActor.getActorId(actor))
    	return
	end

	--复活时间已到
    if (var.resurgence_cd or 0) < System.getNowTime() then
    	print("passionpointsystem.buyRebornCd: reborn not in cd,  actorId:"..LActor.getActorId(actor))
    	return
    end

    --扣钱
    local yb = LActor.getCurrency(actor, NumericType_YuanBao)
    if PassionPointConfig.buyRebornCdCost > yb then
    	print("passionpointsystem.buyRebornCd: money not enough, actorId:"..LActor.getActorId(actor))
    	return
    end

	LActor.changeYuanBao(actor, 0 - PassionPointConfig.buyRebornCdCost, "passionpoint buy cd")

	--重置复活cd和定时器
	if var.rebornEid then LActor.cancelScriptEvent(actor, var.rebornEid) end
	var.rebornEid = nil
	var.resurgence_cd = nil

	--原地复活
	local x, y = LActor.getPosition(actor)
	LActor.relive(actor, x, y)

	LActor.setCamp(actor, LActor.getActorId(actor))
	LActor.stopAI(actor)

	LActor.addEffect(actor, PassionPointConfig.buffId)

	--获取当前所在区域id,此区域没归属，则成为归属
	local areaId = LActor.getSceneAreaIParm(actor, aaPassPoint)
	if areaId and not getAreaBelong(areaId) then
		setBelong(LActor.getActorId(actor), areaId) sendBelongInfo(nil)
	end

	updateMyselfArea(actor)

    notifyRebornTime(actor)
end

local function onEnter(actor, packet)
	--是否开启
	if false == isOpen() then print("passionpointsystem.onEnter: not open") return end

	--检测进入条件
	if false == checkOpenCondition(actor) then
		print("passionpointsystem.onEnter: condition false, id:"..tostring(LActor.getActorId(actor)))
		return
	end

	--是否在副本
	if LActor.isInFuben(actor) then
		print("passionpointsystem.onEnter:actor is in fuben. actorId:".. LActor.getActorId(actor))
		return
	end

	--cd检测
	if true == checkIsInEnterCd(actor) then
		print("passionpointsystem.onEnter:in enter cd. actorId:".. LActor.getActorId(actor))
		return
	end

	--随机点进入
	local data = getGlobalData()
	local x, y = getRandomPoint()
	LActor.enterFuBen(actor, data.hfuben, 0, x, y)

	--发送活动剩余时间
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_PassionPoint, Protocol.sPassionPointCMD_EnterFb)
	LDataPack.writeInt(npack, data.endTime or 0)
	LDataPack.flush(npack)
end

local function onReqBuyCd(actor, packet)
	buyRebornCd(actor)
end

local function onFbEnter(ins, actor)
	-- 设置主动
	LActor.setCamp(actor, LActor.getActorId(actor))
	LActor.stopAI(actor)

	--开场自带霸体光环
	LActor.postScriptEventLite(actor, 10, function(actor, PassionPointConfig)
		 LActor.addEffect(actor, PassionPointConfig.buffId)
	end, PassionPointConfig)

	sendOpen(actor)
	sendBelongInfo(actor)

	--进来都在安全区
	updateMyselfArea(actor)
end

local function onExitFb(ins, actor)
	local var = getData(actor)
	--记录cd
	var.scene_cd = System.getNowTime() + PassionPointConfig.sceneCd
	sendEnterCd(actor)
	sendOpen(actor)

	--重置复活cd和定时器
	if var.rebornEid then LActor.cancelScriptEvent(actor, var.rebornEid) end
	var.rebornEid = nil
	var.resurgence_cd = nil

	--这里加个定时器是因为退出副本的回调函数执行时玩家还没有退出副本，所以需要延后执行相关逻辑
	local id = getBelongId(actor)
	if id then
		LActor.postScriptEventLite(nil, 100, function() clearBelongInfo(id) randomBelong(id) sendBelongInfo(nil) end)
	end
	--if id then LActor.postScriptEventLite(nil, 10, function(_, id) clearBelongInfo(id) randomBelong(id) sendBelongInfo(nil) end, id) end

	--退出把AI恢复
	for i = 0, LActor.getRoleCount(actor) - 1 do
		local role = LActor.getRole(actor, i)
		if role then LActor.setAIPassivity(role, false) end
	end
end

local function onOffline(ins, actor)
	LActor.exitFuben(actor)
end

local function onActorDie(ins, actor, killerHdl)
	if not actor then return end
	--杀人的人停止AI
	local et = LActor.getEntity(killerHdl)
	if et then
		local killer_actor = LActor.getActor(et)
		if killer_actor then
			local TargetActor = LActor.getActorByEt(LActor.getAITarget(et))
			if TargetActor and TargetActor == actor then LActor.stopAI(killer_actor) end
		end

		--被杀死的人是归属，杀他的人如果在同一区域则成为新的归属，否则随机归属
		local id = getBelongId(actor)
		if id then
			clearBelongInfo(id)

			local areaId = LActor.getSceneAreaIParm(killer_actor, aaPassPoint)
			if areaId and id == areaId and not LActor.isDeath(killer_actor) then
				setBelong(LActor.getActorId(killer_actor), id)
				updateMyselfArea(killer_actor)
			else
				randomBelong(id)
			end

			updateMyselfArea(actor)
			sendBelongInfo(nil)
		end
	end

	--复活定时器
	local var = getData(actor)
	var.resurgence_cd = System.getNowTime() + PassionPointConfig.rebornCd
	var.rebornEid = LActor.postScriptEventLite(actor, PassionPointConfig.rebornCd * 1000, reborn)

	notifyRebornTime(actor, killerHdl)
end

local function onActorLeapArea(ins, actor)
	--获得玩家最新的区域id，返回nil表示在二倍区
	local areaId = nil
	if LActor.InSafeArea(actor) then
		areaId = PassionPointConfig.saveAreaId
	else
		areaId = LActor.getSceneAreaIParm(actor, aaPassPoint)
		if not areaId then areaId = PassionPointConfig.doubleAreaId end
	end

	local needUpdate = false

	--先判断是否归属,如果是归属则在原区域的玩家中随机选出新的归属者
	local id = getBelongId(actor)
	if id then
		clearBelongInfo(id)
		randomBelong(id)
		needUpdate = true
	end

	--安全区和二倍区没归属,其它区域如果没归属者则成为新的归属者
	if PassionPointConfig.saveAreaId ~= areaId and PassionPointConfig.doubleAreaId ~= areaId then
		if not getAreaBelong(areaId) then
			setBelong(LActor.getActorId(actor), areaId)
			needUpdate = true
		end
	end

	if needUpdate then sendBelongInfo(nil) end

	updateMyselfArea(actor)
end

local function onLogin(actor)
	sendOpen(actor)
	sendEnterCd(actor)
end

local function onCreateRole(actor, roleId)
	local data = getGlobalData()
	if data.hfuben == LActor.getFubenHandle(actor) then
		--设置阵营
		LActor.setCamp(actor, LActor.getActorId(actor))
		local role = LActor.getRole(actor, 0)--获得第一个角色
		local newRole = LActor.getRole(actor, roleId)--获得新角色
		if role and newRole then
			LActor.setAIPassivity(newRole, LActor.getAIPassivity(role))
		end
	end
end

--开启预告
local function advanceNotice()
	local openDay = System.getOpenServerDay() + 1
	if openDay < PassionPointConfig.openDay then return end

	noticemanager.broadCastNotice(PassionPointConfig.advanceNotice)

	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_PassionPoint, Protocol.sPassionPointCMD_Open)
	LDataPack.writeByte(npack, isOpen() and 1 or 0)
    LDataPack.writeInt(npack, PassionPointConfig.countTimes)

    System.broadcastData(npack)
end
_G.PassionPointAdvance = advanceNotice

--打印归属信息
local function printInfo()
	local data = getGlobalData()
	print(utils.t2s(data.belongInfo))
end

--开启
local function passionPointOpen()
	local openDay = System.getOpenServerDay() + 1
	if openDay < PassionPointConfig.openDay then return end

	local hfuben = Fuben.createFuBen(PassionPointConfig.fbId)
	if 0 == hfuben then print("passionpoint.PassionPointOpen:createFuBen false") return end

	--保存开启时间
	prestigesystem.saveActivityOpenDay(prestigesystem.ActivityEvent.passionpint)

	passion_point_fb = {}
	passion_point_fb.hfuben = hfuben
	passion_point_fb.endTime = System.getNowTime() + PassionPointConfig.lastTimes
	passion_point_fb.is_open = true

	--添加自动奖励定时器
	LActor.postScriptEventLite(nil, PassionPointConfig.sendAwardSec * 1000, function() autoSendReward() end)

	--添加活动结束定时器
	LActor.postScriptEventLite(nil, PassionPointConfig.lastTimes * 1000, function() endTimer() end)

	--打印信息计时器，用于解决bug
	LActor.postScriptEventLite(nil, 10 * 1000, function() printInfo() end)

	--开启活动
	noticemanager.broadCastNotice(PassionPointConfig.openNotice)

	sendOpen(nil)

	print("passionpoint start open")
end
_G.PassionPointOpen = passionPointOpen

--初始化副本
local function initFunc()
    insevent.registerInstanceOffline(PassionPointConfig.fbId, onOffline)
    insevent.registerInstanceExit(PassionPointConfig.fbId, onExitFb)
    insevent.registerInstanceActorDie(PassionPointConfig.fbId, onActorDie)
    insevent.registerInstanceEnter(PassionPointConfig.fbId, onFbEnter)
    insevent.registerInstanceActorLeapArea(PassionPointConfig.fbId, onActorLeapArea)

	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeCreateRole, onCreateRole)

    netmsgdispatcher.reg(Protocol.CMD_PassionPoint, Protocol.cPassionPointCMD_EnterFb, onEnter)
    netmsgdispatcher.reg(Protocol.CMD_PassionPoint, Protocol.cPassionPointCMD_BuyCd, onReqBuyCd)
    netmsgdispatcher.reg(Protocol.CMD_PassionPoint, Protocol.cPassionPointCMD_ReqMyselfInfo, onReqMyselfInfo)
end
table.insert(InitFnTable, initFunc)

local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.passionpoint = function(actor, args)
	if 1 == tonumber(args[1]) then
		passionPointOpen()
	elseif 2 == tonumber(args[1]) then
		advanceNotice()
	elseif 3 == tonumber(args[1]) then
		endTimer()
	end
end
