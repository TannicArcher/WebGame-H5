--跨服3v3战斗副本(跨服服)
module("crossarenafb", package.seeall)

--[[ins.data 结构
	ins.data = {
		actorInfo={
			[actorId] = {
				aid 玩家ID
				srvId 服务器ID
				name  玩家名字
				tianTiScore  天梯积分
				camp  阵营
				multiWin   连胜场数
				killNum 杀人数
				assistNum 助攻数
				flagNum 采旗数
				isInFight 是否在战斗区
				resurgence_cd  	复活cd
				rebornEid 		复活定时器句柄
				multiKill   连杀数
				integral   积分
				integralTime 加积分时间
				winScore     该局赢的天梯积分
				isEscape     是否逃跑
				peakCount    巅峰令数量
				reward       奖励
			}
		}

	startTime    副本开始时间
	flagMonster  旗帜怪物
	flagStartTime  采棋开始时间
	flagRefreshTime 旗帜刷新时间
	flagBelong  旗帜boss归属者
	flagEid 		旗帜复活定时器句柄
	startEid     战斗开始定时器
	endEid       战斗结束定时器
	campScoreA   A阵营积分
	campScoreB   B阵营积分
	winCamp      赢的阵营
	campABornIndex   A阵营倒计时出生点
	campBornIndex   B阵营倒计时出生点
	firstKill   首杀
	firstGather   首采
	mvpList  = {
		[actorId] = 1
	}

	attackerList =
	{
		[被攻击者actorid] = {
			[攻击者actorid] = 最新攻击时间,
		}
	}
	}

]]

CrossArenaCamp = {
	ACamp = 1,  --A阵营
	BCamp = 2,  --B阵营
}

local CrossArenaNotice = {
	FirstGather = 1,  --首采公告
	FirstKill = 2,    --首杀公告
	MultiKill = 3,    --连杀公告
}

local CrossArenaResult = {
	ACampWin = 1,  --A阵营赢
	BCampWin = 2,    --B阵营赢
	Draw = 3,    --平局
}

local multiKillList = {}
for k in pairs(CrossArenaMultiKill or {}) do multiKillList[#multiKillList+1] = k end
table.sort(multiKillList)

local function getFubenData(ins)
	return ins.data
end

--获取玩家信息
local function getActorFubenData(ins, actor)
	local data = getFubenData(ins)
	if not data.actorInfo then data.actorInfo = {} end
	return data.actorInfo[LActor.getActorId(actor)]
end

--发送旗帜刷新信息
function sendFlagRefreshInfo(ins, actor)
	local npack = nil
    if actor then
        npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_FlagRefresh)
    else
        npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, Protocol.CMD_Cross3Vs3)
        LDataPack.writeByte(npack, Protocol.sCross3Vs3_FlagRefresh)
    end

    local data = getFubenData(ins)
    local time = (data.flagRefreshTime or 0) - System.getNowTime() > 0 and (data.flagRefreshTime or 0) - System.getNowTime() or 0

    LDataPack.writeDouble(npack, data.flagMonster and LActor.getHandle(data.flagMonster) or 0)
    LDataPack.writeInt(npack, time)

    if actor then
        LDataPack.flush(npack)
    else
        Fuben.sendData(ins.handle, npack)
    end
end

--下发副本信息
local function sendFubenInfo(ins, actor)
	local data = getFubenData(ins)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_SendFbInfo)
    LDataPack.writeInt(npack, data.startTime or 0)
	LDataPack.writeByte(npack, data.actorInfo[LActor.getActorId(actor)].camp)
	LDataPack.writeInt(npack, data.campScoreA or 0)
	LDataPack.writeInt(npack, data.campScoreB or 0)
	LDataPack.flush(npack)
end

--通知玩家的复活信息
local function notifyRebornTime(data, actor, killerHdl)
    local rebornCd = (data.resurgence_cd or 0) - System.getNowTime()
    if rebornCd < 0 then rebornCd = 0 end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_ResurgenceInfo)
    LDataPack.writeInt(npack, rebornCd)
    LDataPack.writeDouble(npack, killerHdl or 0)
    LDataPack.flush(npack)
end

--复活定时器
local function reborn(actor, ins)
	if not actor then return end

	local var = getActorFubenData(ins, actor)
	notifyRebornTime(var, actor)

	local x, y = getCountTimePos(ins, var.camp)
	LActor.relive(actor, x, y)

	LActor.stopAI(actor)

	var.rebornEid = nil
end

--检测玩家是否在参赛名单
local function checkActorIllegal(actor)
	local ins = instancesystem.getInsByHdl(LActor.getFubenHandle(actor))
	if not ins then return false end
	if ins.id ~= CrossArenaBase.fbId then return false end

	return true
end

--积分排序
local function sortIntegral(ins)
	local data = getFubenData(ins)

	data.integralRank = {}
	for id, v in pairs(data.actorInfo or {}) do
        table.insert(data.integralRank, {aid = id, integral = v.integral or 0})
    end

	table.sort(data.integralRank, function(a, b) return a.integral > b.integral end)
end

--增加阵营积分
local function addCampIntegral(ins, camp, score)
	local data = getFubenData(ins)
	if camp == CrossArenaCamp.ACamp then
		data.campScoreA = (data.campScoreA or 0) + score
	else
		data.campScoreB = (data.campScoreB or 0) + score
	end
end

--广播积分
local function boardIntegral(ins, var)
	local data = getFubenData(ins)
	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_UpdateIntegral)
    LDataPack.writeInt(npack, data.campScoreA or 0)
    LDataPack.writeInt(npack, data.campScoreB or 0)
    Fuben.sendData(ins.handle, npack)
end

--检测是否胜利
local function checkWin(ins, actor, isTimeOut)
	local data = getFubenData(ins)
	local winCamp = nil

	if actor then
		local var = getActorFubenData(ins, actor)
		var.isEscape = true

		--阵营是否所有人都退出了
		local isAllEacape = true
		for id, info in pairs(data.actorInfo or {}) do
			if info.camp == var.camp and not info.isEscape then isAllEacape = false break end
		end

		if isAllEacape then winCamp = var.camp == CrossArenaCamp.ACamp and CrossArenaResult.BCampWin or CrossArenaResult.ACampWin end
	else
		--时间到判断哪个阵营胜出或者平局
		if isTimeOut then
			if (data.campScoreA or 0) ~= (data.campScoreB or 0) then
				winCamp = (data.campScoreA or 0) > (data.campScoreB or 0) and CrossArenaResult.ACampWin or CrossArenaResult.BCampWin
			else
				winCamp = CrossArenaResult.Draw
			end
		else
			--哪个阵营先达到胜利积分
			if (data.campScoreA or 0) >= CrossArenaBase.winScore or (data.campScoreB or 0) >= CrossArenaBase.winScore then
				winCamp = (data.campScoreA or 0) > (data.campScoreB or 0) and CrossArenaResult.ACampWin or CrossArenaResult.BCampWin
			end
		end
	end

	--结算
	if winCamp then
		data.winCamp = winCamp
		ins:win()

		print("crossarenafb.checkWin:wincamp is:"..tostring(winCamp)..", handle:"..tostring(ins.handle))
	end
end

--增加积分
local function addIntegral(ins, data, score)
	data.integral = (data.integral or 0) + score
	data.integralTime = System.getNowTime()
	addCampIntegral(ins, data.camp, score)
	sortIntegral(ins)
	boardIntegral(ins, data)

	--下发自己的信息
	local rank = nil
	for idx, info in ipairs(data.integralRank or {}) do
		if info.aid == var.aid then rank = idx return end
	end

	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_SendMySelfInfo)
    LDataPack.writeShort(npack, data.integral or 0)
    LDataPack.writeShort(npack, rank or 0)
    LDataPack.flush(npack)

	checkWin(ins, nil, false)
end

--注销定时器
local function cancelEid(ins)
	local data = getFubenData(ins)
	if data.flagEid then LActor.cancelScriptEvent(nil, data.flagEid) data.flagEid = nil end
	if data.startEid then LActor.cancelScriptEvent(nil, data.startEid) data.startEid = nil end
	if data.endEid then LActor.cancelScriptEvent(nil, data.endEid) data.endEid = nil end

	for id, info in pairs(data.actorInfo or {}) do
		if info.rebornEid then LActor.cancelScriptEvent(nil, info.rebornEid) info.rebornEid = nil end
	end
end

--刷出旗帜
local function refreshFlagTimer(ins)
	if not ins then print("crossarenafb.refreshFlagTimer:ins nil") return end

	if CrossArenaBase.flagPos and CrossArenaBase.flagBossId then
		local monster = Fuben.createMonster(ins.scene_list[1], CrossArenaBase.flagBossId, CrossArenaBase.flagPos.posX, CrossArenaBase.flagPos.posY)
		if not monster then print("crossarenafb.refreshFlagTimer:monster nil") return end

		local data = getFubenData(ins)
		data.flagMonster = monster

		sendFlagRefreshInfo(ins, nil)

		print("crossarenafb.refreshFlagTimer: refresh flag success")
	end
end

--发送旗帜归属者信息
local function sendFlagBelongInfo(ins, actor)
	local npack = nil
    if actor then
        npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_UpdateFlagInfo)
    else
        npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, Protocol.CMD_Cross3Vs3)
        LDataPack.writeByte(npack, Protocol.sCross3Vs3_UpdateFlagInfo)
    end

    --剩余时间
    local data = getFubenData(ins)
    local leftTime = 0
    if data.flagBelong then leftTime = data.flagStartTime + CrossArenaBase.needGatherTime - System.getNowTime() end
    if 0 > leftTime then leftTime = 0 end

    LDataPack.writeDouble(npack, data.flagBelong and LActor.getHandle(data.flagBelong) or 0)
    LDataPack.writeInt(npack, leftTime)

    if actor then
        LDataPack.flush(npack)
    else
        Fuben.sendData(ins.handle, npack)
    end
end

--设置旗帜归属信息
local function onFlagBelongChange(ins, belong, startTime)
	local data = getFubenData(ins)
    data.flagBelong = belong
    data.flagStartTime = startTime
	sendFlagBelongInfo(ins, nil)
end

--根据杀人数量获取配置
local function getKillConfig(number)
	for i = #multiKillList, 1, -1 do
		if number >= multiKillList[i] then return CrossArenaMultiKill[multiKillList[i]] end
	end

	return nil
end

--添加攻击者
local function addAttackInfo(ins, actor, tActor)
	local data = getFubenData(ins)
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

--筛选助攻者加助攻次数
local function addAssistsCount(ins, beKillActor, killerActor)
	local data = getFubenData(ins)
	if not data.attackerList then data.attackerList = {} end
	local actorId = LActor.getActorId(beKillActor)
	local killerActorId = LActor.getActorId(killerActor)

	local info = data.attackerList[actorId]
	if not info then return end
	local nowTime = System.getNowTime()

	for aid, time in pairs(info or {}) do
		if nowTime - time <= CrossArenaBase.assistsTime and killerActorId ~= aid then
			local actor = LActor.getActorById(aid)
			if actor then
				local var = getActorFubenData(ins, actor)
				var.assistNum = (var.assistNum or 0) + 1
			end
		end
	end

	--删除数据
	table.remove(data.attackerList, actorId)
end

--改变连杀数
local function changeMultiKill(handle, data, num, actor)
	data.multiKill = num
	if data.multiKill then
		--连杀公告
		local conf = getKillConfig(data.multiKill)
		if conf then
			local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_UpdateNotice)
			LDataPack.writeShort(npack, CrossArenaNotice.MultiKill)
		    LDataPack.writeInt(npack, LActor.getServerId(actor))
		    LDataPack.writeString(npack, LActor.getName(actor))
		    LDataPack.writeShort(npack, conf.id)
		    Fuben.sendData(ins.handle, npack)
		end
	end
end

--获取倒计时出生点
function getCountTimePos(ins, camp)
	local data = getFubenData(ins)
	local index = CrossArenaCamp.ACamp == camp and data.campABornIndex or data.campBBornIndex
	return CrossArenaBase.readyPos[index].posX, CrossArenaBase.readyPos[index].posY
end

--获取随机坐标
local function getRandomPoint()
    local index = math.random(1, #CrossArenaBase.randomPos)
    return CrossArenaBase.randomPos[index].posX, CrossArenaBase.randomPos[index].posY
end

--计算mvp
local function calcMvp(ins)
	local data = getFubenData(ins)
	local campA = {}
	local campB = {}

	--分阵营计算
	for id, info in pairs(data.actorInfo or {}) do
		if CrossArenaCamp.ACamp == info.camp then
			table.insert(campA, {aid=id, integral=info.integral, integralTime=info.integralTime})
		else
			table.insert(campB, {aid=id, integral=info.integral, integralTime=info.integralTime})
		end
	end

	local function rank(a, b)
		if (a.integral or 0) ~= (b.integral or 0) then return (a.integral or 0) > (b.integral or 0) end
		return (a.integralTime or 0) < (b.integralTime or 0)
	end

	--获取最高积分并且最先到达
	table.sort(campA, rank)
	table.sort(campB, rank)

	if not data.mvpList then data.mvpList = {} end
	if campA[1] then data.mvpList[campA[1].aid] = 1 end
	if campB[1] then data.mvpList[campB[1].aid] = 1 end
end

--计算得到的天梯积分和奖励
local function calcScore(fdata, info)
	local conf = nil
	for _, cfg in ipairs(CrossArenaScore or {}) do
		if (info.tianTiScore or 0) >= cfg.minScore and (info.tianTiScore or 0) <= cfg.MaxScore then conf = cfg break end
	end

	local score = 0
	if conf then
		local winCamp = fdata.winCamp

		--奖励和积分
		if winCamp ~= CrossArenaResult.Draw then
			score = info.camp == winCamp and conf.winScore or conf.loseScore
			local dropId = info.camp == winCamp and CrossArenaBase.DropIdInfo.winDropId or CrossArenaBase.DropIdInfo.loseDropId
			info.reward = drop.dropGroup(dropId)
			if CrossArenaBase.peakCountInfo then
				info.peakCount = info.camp == winCamp and CrossArenaBase.peakCountInfo.winCount or CrossArenaBase.peakCountInfo.loseCount
			end
		else
			score = conf.drawScore
			info.reward = drop.dropGroup(CrossArenaBase.peakCountInfo.drawDropId)
			if CrossArenaBase.peakCountInfo then
				info.peakCount = CrossArenaBase.peakCountInfo.drawCount
			end
		end

		--mvp得分
		if data.mvpList and data.mvpList[info.aid] then
			score = score + conf.mvpScore
			if CrossArenaBase.peakCountInfo then
				info.peakCount = (info.peakCount or 0) + CrossArenaBase.peakCountInfo.mvpCount
			end
		end

		--首杀
		if data.firstKill == info.aid then
			score = score + conf.firstKillScore
			if CrossArenaBase.peakCountInfo then
				info.peakCount = (info.peakCount or 0) + CrossArenaBase.peakCountInfo.firstKillCount
			end
		end

		--首采
		if data.firstGather == info.aid then
			score = score + conf.firstGatherScore
			if CrossArenaBase.peakCountInfo then
				info.peakCount = (info.peakCount or 0) + CrossArenaBase.peakCountInfo.firstGatherCount
			end
		end

		--是否连胜
		if conf.multiScore and (info.multiWin or 0) > conf.multiScore.count then score = score + conf.multiScore.score end

		--是否逃跑
		if info.isEscape then score = score + conf.escapeScore end

		info.winScore = score
	end
end

--副本创建回调函数
local function onCreateFuBen(ins)
	local data = getFubenData(ins)
	--停止副本AI
	Fuben.setIsNeedAi(ins.handle, false)

	if CrossArenaBase.countTime then
		--战斗开始定时器
		data.startTime = System.getNowTime() + CrossArenaBase.countTime
		data.startEid = LActor.postScriptEventLite(nil, CrossArenaBase.countTime * 1000, function(_, ins)
			Fuben.setIsNeedAi(ins.handle, true)
			ins.data.startEid = nil
			refreshFlagTimer(ins)
		end, ins)
	end

	--注册战斗结束定时器
	data.endEid = LActor.postScriptEventLite(nil, (CrossArenaBase.lastTime + (CrossArenaBase.countTime or 0)) * 1000, function(_, ins)
		ins.data.endEid = nil
		checkWin(ins, nil, true)
	end, ins)

	--随机倒计时出生点
	data.campABornIndex = math.random(1, #CrossArenaBase.readyPos)
	data.campBBornIndex = data.campABornIndex == #CrossArenaBase.readyPos and 1 or #CrossArenaBase.readyPos
end


--进入副本的时候
local function onEnterFb(ins, actor)
	if not ins.data.actorInfo then ins.data.actorInfo = {} end

	local aid = LActor.getActorId(actor)
	local info = ins.data.actorInfo[aid]

	--找不到踢回原服
	if not info then LActor.exitFuben(actor) return end

	LActor.setCamp(actor, info.camp)
	print("333333333333333:"..tostring(info.camp))
	LActor.stopAI(actor)

	sendFubenInfo(ins, actor)
	sendFlagRefreshInfo(ins, actor)
end

local function onExitFb(ins, actor)
	local data = getFubenData(ins)

	--旗帜归属者退出副本
	if data.flagBelong == actor then onFlagBelongChange(ins, nil, nil) end

	local var = getActorFubenData(ins, actor)

	--删除复活定时器
	if var.rebornEid then LActor.cancelScriptEvent(actor, var.rebornEid) var.rebornEid = nil end

	--副本没结束记录逃跑信息
	if not ins:isEnd() then checkWin(ins, actor, false) end

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
	if et then
		local killer_actor = LActor.getActor(et)
		if killer_actor then
			--杀人的人停止AI
			local TargetActor = LActor.getActorByEt(LActor.getAITarget(et))
			if TargetActor and TargetActor == actor then LActor.stopAI(killer_actor) end
		end

		local data = getFubenData(ins)
		local var = getActorFubenData(ins, actor)
		local score = CrossArenaBase.killScore

		--首杀公告且加双倍积分
		if not data.firstKill then
			data.firstKill = LActor.getActorId(killer_actor)
			score = score + CrossArenaBase.killScore

			local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_UpdateNotice)
			LDataPack.writeShort(npack, CrossArenaNotice.FirstKill)
		    LDataPack.writeInt(npack, LActor.getServerId(killer_actor))
		    LDataPack.writeString(npack, LActor.getName(killer_actor))
		    LDataPack.writeInt(npack, LActor.getServerId(actor))
		    LDataPack.writeString(npack, LActor.getName(actor))
		    LDataPack.writeShort(npack, CrossArenaBase.firstKillNoticeId)
		    Fuben.sendData(ins.handle, npack)

			print("crossarenafb.onActorDie:firstKill success, actorId:"..tostring(LActor.getActorId(killer_actor)))
		end

		--杀人数累加
		changeMultiKill(ins.handle, var, (var.multiKill or 0) + 1)
		var.killNum = (var.killNum or 0) + 1

		--助攻次数
		addAssistsCount(ins, actor, killer_actor)

		--增加积分
		addIntegral(ins, var, score)
	end

	--复活定时器
    local var = getActorFubenData(ins, actor)
	var.resurgence_cd = System.getNowTime() + CrossArenaBase.rebornCd
	var.rebornEid = LActor.postScriptEventLite(actor, CrossArenaBase.rebornCd * 1000, reborn, ins)

    notifyRebornTime(var, actor, killerHdl)
end

--开始采集
local function onGatherStart(ins, gather, actor)
	if not actor then return false end
	local data = getFubenData(ins)
	local actorId = LActor.getActorId(actor)

	if not data.flagMonster or data.flagMonster ~= gather then
		print("crossarenafb.onGatherStart:flagMonster not same, actorId:"..tostring(actorId))
		return false
	end

	--是否被采中
	if data.flagBelong then
		print("crossarenafb.onGatherStart:flagBelong exist, actorId:"..tostring(actorId))
		return false
	end

	onFlagBelongChange(ins, actor, System.getNowTime())

	LActor.stopAI(actor)
	print("crossarenafb.onGatherStart:start to gather, actorId:"..tostring(actorId))

	return true
end

--采集结束
local function onGatherFinished(ins, gather, actor, success)
	if not actor then return end
	local data = getFubenData(ins)
	local actorId = LActor.getActorId(actor)

	if not data.flagMonster or data.flagMonster ~= gather then
		print("crossarenafb.onGatherStart:flagMonster not same, actorId:"..tostring(actorId))
		return
	end

	if not data.flagBelong or data.flagBelong ~= actor then
		print("crossarenafb.onGatherFinished:flagBelong not exist, actorId:"..tostring(actorId))
		return
	end

	if success then
		--删除旗帜
		LActor.DestroyEntity(data.flagMonster, true)
		data.flagMonster = nil

		--添加刷新定时器
		data.flagEid = LActor.postScriptEventLite(nil, CrossArenaBase.flagRefreshTime * 1000, function() refreshFlagTimer(ins) end)
		data.flagRefreshTime = System.getNowTime() + CrossArenaBase.flagRefreshTime
		sendFlagRefreshInfo(ins, nil)

		local score = CrossArenaBase.gatherScore

		--首采公告且加双倍积分
		if not data.firstGather then
			data.firstGather = LActor.getActorId(actor)
			score = score + CrossArenaBase.gatherScore

			local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_UpdateNotice)
			LDataPack.writeShort(npack, CrossArenaNotice.FirstGather)
		    LDataPack.writeInt(npack, LActor.getServerId(actor))
		    LDataPack.writeString(npack, LActor.getName(actor))
		    LDataPack.writeShort(npack, CrossArenaBase.firstKillNoticeId)
		    Fuben.sendData(ins.handle, npack)

			print("crossarenafb.onGatherFinished:firstGather success, actorId:"..tostring(actorId))
		end

		local var = getActorFubenData(ins, actor)

		--增加积分
		addIntegral(ins, var, score)
	end

	LActor.stopAI(actor)

	onFlagBelongChange(ins, nil, nil)

	print("crossarenafb.onGatherStart:gather end, actorId:"..tostring(actorId)..", issuccess:"..tostring(success))
end

local function onFuBenEnd(ins)
	cancelEid(ins)

	--计算mvp
	calcMvp(ins)

	local data = getFubenData(ins)

	--计算积分和奖励
	for id, info in pairs(data.actorInfo or {}) do calcScore(data, info) end

	--结算框
	for id, info in pairs(data.actorInfo or {}) do
		local actor = LActor.getActorById(id)
		if actor then
			local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_SendSettleInfo)
			LDataPack.writeInt(npack, data.campScoreA or 0)
			LDataPack.writeInt(npack, data.campScoreA or 0)
			LDataPack.writeShort(npack, data.winCamp)
			LDataPack.writeShort(npack, #(data.integralRank or {}))
			for _, v in ipairs(data.integralRank or {}) do
				local info = data.actorInfo[v.aid]
				LDataPack.writeInt(npack, info.srvId or 0)
				LDataPack.writeString(npack, info.name or 0)
				LDataPack.writeShort(npack, info.killNum or 0)
				LDataPack.writeShort(npack, info.assistNum or 0)
				LDataPack.writeShort(npack, info.flagNum or 0)
				LDataPack.writeShort(npack, info.integral or 0)
				LDataPack.writeShort(npack, info.peakCount or 0)
				LDataPack.writeShort(npack, info.winScore or 0)
				LDataPack.writeByte(npack, info.aid == data.firstKill and 1 or 0)
				LDataPack.writeByte(npack, info.aid == data.firstGather and 1 or 0)
				LDataPack.writeByte(npack, data.mvpList[info.aid] and 1 or 0)
				LDataPack.writeByte(npack, (info.multiWin or 0) > 0 and 1 or 0)
				LDataPack.writeByte(npack, info.isEscape and 1 or 0)
			end

			LDataPack.writeShort(npack, #(info.reward or {}))
			for k, v in pairs(info.reward or {}) do
				LDataPack.writeInt(npack, v.type)
				LDataPack.writeInt(npack, v.id)
				LDataPack.writeInt(npack, v.count)
			end

			LDataPack.flush(npack)
		end
	end
end

--采棋
local function onCollect(actor, packet)
	local actorId = LActor.getActorId(actor)
	if false == checkActorIllegal(actor) then
		print("crossarenafb.onCollect:actor illegal, actorId:"..tostring(actorId))
		return
	end

	local data = getFubenData(instancesystem.getInsByHdl(LActor.getFubenHandle(actor)))
	if not data.actorInfo or not data.actorInfo[actorId] then
		print("crossarenafb.onCollect:actorInfo nil, actorId:"..tostring(actorId))
		return
	end

	--是否在cd
	if (data.flagRefreshTime or 0) > System.getNowTime() then
		print("crossarenafb.onCollect:collect in cd, actorId:"..tostring(actorId))
		return
	end

	--是否存在旗帜
	if not data.flagMonster then
		print("crossarenafb.onCollect:flagMonster is nil, actorId:"..tostring(actorId))
		return
	end

	--不能重复采棋
	if data.flagBelong and data.flagBelong == actor then
		print("crossarenafb.onCollect:collect repeat, actorId:"..tostring(actorId))
		return
	end

	--有归属就打归属，没归属就采棋
	if data.flagBelong then
		if LActor.getFubenHandle(data.flagBelong) == LActor.getFubenHandle(actor) then
			LActor.setAITarget(actor, LActor.getLiveByJob(data.flagBelong))
		else
			print("crossarenafb.onCollect:FubenHandle not same, actorId:"..tostring(actorId))
		end
	else
		LActor.setAITarget(actor, data.flagMonster)
	end
end

--攻击列表
local function onRoleDamage(ins, actor, role, value, attacker, res)
	if not attacker or not actor then return end

	local tActor = LActor.getActor(attacker)
	if tActor then addAttackInfo(ins, actor, tActor) end
end

--查看排行榜
local function onRequestRank(actor, packet)
	local actorId = LActor.getActorId(actor)
	local data = getFubenData(instancesystem.getInsByHdl(LActor.getFubenHandle(actor)))
	if not data.actorInfo or not data.actorInfo[actorId] then
		print("crossarenafb.onRequestRank:actorInfo nil, actorId:"..tostring(actorId))
		return
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_UpdateRankInfo)
	LDataPack.writeShort(npack, #(data.integralRank or {}))
	print("11111111111:"..tostring(#(data.integralRank or {})))
	print(utils.t2s(data.actorInfo))
	for _, info in ipairs(data.integralRank or {}) do
		LDataPack.writeInt(npack, data.actorInfo[info.aid].srvId or 0)
		LDataPack.writeString(npack, data.actorInfo[info.aid].name or "")
		LDataPack.writeShort(npack, data.actorInfo[info.aid].killNum or 0)
		LDataPack.writeShort(npack, data.actorInfo[info.aid].assistNum or 0)
		LDataPack.writeShort(npack, data.actorInfo[info.aid].flagNum or 0)
		LDataPack.writeShort(npack, data.actorInfo[info.aid].integral or 0)
		LDataPack.writeShort(npack, data.actorInfo[info.aid].tianTiScore or 0)
	end

	LDataPack.flush(npack)
end

--启动初始化
local function initGlobalData()
	--注册副本事件
	insevent.registerInstanceEnter(CrossArenaBase.fbId, onEnterFb)
	insevent.registerInstanceExit(CrossArenaBase.fbId, onExitFb)
	insevent.registerInstanceOffline(CrossArenaBase.fbId, onOffline)
	insevent.registerInstanceActorDie(CrossArenaBase.fbId, onActorDie)
	insevent.registerInstanceGatherStart(CrossArenaBase.fbId, onGatherStart) --玩家开始采集时
	insevent.registerInstanceGatherFinish(CrossArenaBase.fbId, onGatherFinished) --玩家采集完成时
	insevent.registerInstanceWin(CrossArenaBase.fbId, onFuBenEnd) --副本胜利时候(提前到达分数)
	insevent.registerInstanceActorDamage(CampBattleConfig.fbId, onRoleDamage) --受到攻击

	netmsgdispatcher.reg(Protocol.CMD_Cross3Vs3, Protocol.cCross3Vs3_RequestCollect, onCollect)
	netmsgdispatcher.reg(Protocol.CMD_Cross3Vs3, Protocol.cCross3Vs3_RequestRankInfo, onRequestRank)
end

table.insert(InitFnTable, initGlobalData)

local handle = nil

local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.cbcfuid = function(actor, args)
	if 1 == tonumber(args[1]) then
		handle = Fuben.createFuBen(CrossArenaBase.fbId)
		local ins = instancesystem.getInsByHdl(handle)
		onCreateFuBen(ins)
		--测试专用
		if not ins.data.actorInfo then ins.data.actorInfo = {} end
		if not ins.data.actorInfo[LActor.getActorId(actor)] then
			ins.data.actorInfo[LActor.getActorId(actor)] = {aid=LActor.getActorId(actor), srvId=LActor.getServerId(actor), camp=math.random(2),
		    name=LActor.getName(actor)}
		end

	elseif 2 == tonumber(args[1]) then
		local ins = instancesystem.getInsByHdl(handle)
		if not ins.data.actorInfo[LActor.getActorId(actor)] then
			ins.data.actorInfo[LActor.getActorId(actor)] = {aid=LActor.getActorId(actor), srvId=LActor.getServerId(actor), camp=math.random(2),
		    name=LActor.getName(actor)}
		end

		local x, y = getCountTimePos(ins, ins.data.actorInfo[LActor.getActorId(actor)].camp)
		LActor.enterFuBen(actor, handle, 0, x, y)
	elseif 3 == tonumber(args[1]) then
		local ins = instancesystem.getInsByHdl(handle)
		checkWin(ins, nil, true)
	end
end
