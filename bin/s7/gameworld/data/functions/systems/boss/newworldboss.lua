--新世界boss
module("newworldboss", package.seeall)

local baseConf = NewWorldBossBaseConfig
local lvConf = NewWorldBossLvConfig
local rankConf = NewWorldBossRankConfig


--[[数据结构
 {
	fbhandle = 副本的句柄
	aidZsLv = {
		[玩家ID]=转生等级
	}
	start_time = 活动开始时间
	end_time = 活动结束时间
	scorelist = {
        [actorid] = {name, score}
    },
	scorerank = {
	    {id, name, score}[]
	}
 }
]]
--获取全局动态数据变量
newWorldBossData = newWorldBossData or {}
local function getGlobalData()
	return newWorldBossData
end

--[[数据结构
	{
		blv = 等级
	}
]]
--获取全局静态变量
local function getSystemData()
	local var = System.getStaticVar()
	if var.newworldboss == nil then
		var.newworldboss = {}
	end
	if not var.newworldboss.blv then
		var.newworldboss.blv = 1
	end
	return var.newworldboss
end

--[[
cache={
	rebornCd = 复活CD时间
	eid = 复活定时器ID
}
]]
--获取临时动态数据
local function getDynamicData(actor)
	local var = LActor.getDynamicVar(actor)
	if var == nil then return nil end
	if var.newworldboss == nil then
		var.newworldboss = {}
	end
	return var.newworldboss
end

--判断活动是否开启
local function isOpen()
	local gdata = getGlobalData()
	local now = System.getNowTime()
	if (gdata.start_time or 0) <= now and now < (gdata.end_time or 0) then
		return true
	end
	return false
end

--获取进入坐标点
local function getRandomPoint()
	local pos = baseConf.enterPos[math.random(1,#baseConf.enterPos)]
	return pos.posX,pos.posY
end

--获取当前需要刷的怪物ID
local function getBossId()
	local sdata = getSystemData()
	--防止cfg改变
	local lvc = lvConf[sdata.blv]
	if not lvc then
		print("newworldboss.getBossId blv is not cfg,"..sdata.blv)
		lvc = lvConf[#lvConf]
	end
	return lvc.bossId
end

--[[
ins.data数据结构 {
	bossid = 当前挑战的BOSSid
}
]]
--创建副本
local function createFb(gdata)
	gdata.fbhandle = Fuben.createFuBen(baseConf.fbId)
	local ins = instancesystem.getInsByHdl(gdata.fbhandle)
	if not ins then
		print("newworldboss.createFb not ins")
		return false
	end
	ins.data.bossid = getBossId()
	ins.boss_info = {}
	if not ins.data.bossid then
		print("newworldboss.createFb not bossid")
		return false
	end
	--创建怪物
	local monster = Fuben.createMonster(ins.scene_list[1], ins.data.bossid)
	if nil == monster then
		print("newworldboss.createFb create monster failed, bossid:"..ins.data.bossid)
		return
	end
	return true
end

--请求进入新世界boss副本
local function reqEnterFb(actor, packet)
	if LActor.getLevel(actor) < baseConf.openLv then
		print("newworldboss.reqEnterFb level err")
		return
	end
	local gdata = getGlobalData()
	--判断活动是否开启
	if not gdata.fbhandle or gdata.fbhandle == 0 then
		if not isOpen() then
			print("newworldboss.reqEnterFb gdata.fbhandle is nil and not open")
			return
		end
		if not createFb(gdata) then
			return
		end
	end
	--获取副本实例
	local ins = instancesystem.getInsByHdl(gdata.fbhandle)
	if not ins then
		print("newworldboss.reqEnterFb not ins,hfuben:"..gdata.fbhandle)
		return
	end
	--进入副本
    local x, y = getRandomPoint() --随机坐标
    return LActor.enterFuBen(actor, gdata.fbhandle, 0, x, y)
end

--获取红装掉落组
local function getReadDrop()
	local cfg = NewWorldBossRedConfig[System.getOpenServerDay()+1]
	if not cfg then
		cfg = NewWorldBossRedConfig[#NewWorldBossRedConfig]
	end
	return cfg.did
end

local function onScoreRankTimer(now_t, force)
	local gdata = getGlobalData()
	if not force and ((gdata.rankTimer or 0) > now_t) then return end
	gdata.rankTimer = now_t + 3 --3秒执行一次
	--排序
	if gdata.scorelist then
	    gdata.scorerank = {}
	    for aid, v in pairs(gdata.scorelist) do
	        table.insert(gdata.scorerank, {id=aid,name=v.name,score=math.floor(v.score)})
	    end
	    table.sort(gdata.scorerank, function(a,b)
	        return a.score > b.score
	    end)
    end
    --广播给副本内的所有玩家
    local actors = Fuben.getAllActor(gdata.fbhandle)
	if actors ~= nil then
		for i = 1,#actors do
			local actor = actors[i]
			local npack = LDataPack.allocPacket(actor, Protocol.CMD_Boss, Protocol.sNewWorldBoss_RankInfo)
			if npack then 
				if gdata.scorerank == nil then
					LDataPack.writeShort(npack, 0)
				else
					local sendCount = math.min(baseConf.rankCount, #gdata.scorerank)
					LDataPack.writeShort(npack, sendCount)
					for i=1,sendCount do
						LDataPack.writeInt(npack, gdata.scorerank[i].id)
						LDataPack.writeString(npack, gdata.scorerank[i].name)
						LDataPack.writeDouble(npack, gdata.scorerank[i].score)
					end
				end
				LDataPack.flush(npack)
			end	
		end
	end
end

--获取伤害排名
local function getScoreRank()
	onScoreRankTimer(System.getNowTime(), true)
	local gdata = getGlobalData()
	return gdata.scorerank
end

--发放排名奖励
local function sendRankRewardtomail(ins, isKill, lastKillActor)
	local rank = getScoreRank()
	if rank and #rank > 0 then
		local gdata = getGlobalData()
		local sdata = getSystemData()
		local rconf = rankConf[sdata.blv]
		if not rconf then rconf = rankConf[#rankConf] end
		local redReward = drop.dropGroup(getReadDrop())
		local redDropR = math.random(1, #rank) --拿到红装应该掉落给谁
		for r,v in ipairs(rank) do
			local rCfg = rconf[r]
			if not rCfg then 
				rCfg = rconf[#rconf]
			end
			--获取进来时候的转生等级
			local zsLv = gdata.aidZsLv[v.id]
			if not zsLv then
				zsLv = 0
				print("newworldboss.sendRankRewardtomail not have zsLv aid:"..tostring(v.id))
			end

			if r > baseConf.joinRank then
				--参与奖励
				local reward = drop.dropGroup(rCfg.reward[zsLv+1])
				local mailData = {head=baseConf.joinMailHead, context=baseConf.joinMailContent, tAwardList=reward }
				mailsystem.sendMailById(v.id, mailData)
			else
				--排名奖励
				local reward = drop.dropGroup(rCfg.reward[zsLv+1])
				--发奖励邮件
				local mailData = {head=baseConf.rankMailHead, context=baseConf.rankMailContent, tAwardList=reward }
				mailsystem.sendMailById(v.id, mailData)
			end

			--红装掉落
			local hasRedDrop = false
			if redReward and #redReward > 0 and r == redDropR then
				--发奖励邮件
				hasRedDrop = true
				local mailData = {head=baseConf.redMailHead, context=baseConf.redMailContent, tAwardList=redReward }
				mailsystem.sendMailById(v.id, mailData)
			end

			--发送弹框
			local rActor = LActor.getActorById(v.id)
			if rActor then
				if LActor.getFubenHandle(rActor) == ins.handle then
					local npack = LDataPack.allocPacket(rActor, Protocol.CMD_Boss, Protocol.sNewWorldBoss_SendResult)
					if npack then
						LDataPack.writeChar(npack, isKill and 1 or 0)
						LDataPack.writeInt(npack, r)
						LDataPack.writeString(npack, lastKillActor and LActor.getName(lastKillActor) or "")
						LDataPack.writeString(npack, hasRedDrop and rank[redDropR].name or "")
						LDataPack.writeInt(npack, (gdata.end_time or 0) - (gdata.start_time or 0))
						LDataPack.writeShort(npack, #(redReward or {}))
						for _,v in ipairs(redReward or {}) do
							LDataPack.writeInt(npack, v.type)
							LDataPack.writeInt(npack, v.id)
							LDataPack.writeInt(npack, v.count)
						end
						LDataPack.flush(npack)
					end
				end
				actorevent.onEvent(rActor, aeNewWorldBoss)
			end
		end
	else
		print("newworldboss.sendRankRewardtomail scorerank is nil")
	end
end

--发送或广播图标状态
local function sendIconOpenStatus(status, actor)
	local gdata = getGlobalData()
	if actor then
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Boss, Protocol.sNewWorldBoss_SendIcon)  
		if npack == nil then return end
		LDataPack.writeByte(npack, status and 1 or 0)
		LDataPack.writeInt(npack, gdata.start_time or 0)
		LDataPack.flush(npack)
	else
		local npack = LDataPack.allocPacket()
		if npack == nil then return end
		LDataPack.writeByte(npack, Protocol.CMD_Boss)
		LDataPack.writeByte(npack, Protocol.sNewWorldBoss_SendIcon)
		LDataPack.writeByte(npack, status and 1 or 0)
		LDataPack.writeInt(npack, gdata.start_time or 0)
		System.broadcastData(npack)
	end
end

--结束PVE
local function endPve(isKill, lastKillActor)	
	--发送图标开启状态
	sendIconOpenStatus(false, nil)
	
	local gdata = getGlobalData()
	gdata.pveEid = nil
	gdata.openIcon = false
	gdata.end_time = System.getNowTime()
	--是否有副本
	if not gdata.fbhandle or gdata.fbhandle == 0 then
		return
	end
	local ins = instancesystem.getInsByHdl(gdata.fbhandle)
	if not ins then
		gdata.fbhandle = nil
		print("newworldboss.endPve not ins")
		return
	end

	--发放排名奖励
	sendRankRewardtomail(ins, isKill, lastKillActor)
	--给最后一刀玩家一个称号
	if lastKillActor and baseConf.lastTitle then
		titlesystem.addTitle(lastKillActor, baseConf.lastTitle)
		local lastActorId = LActor.getActorId(lastKillActor)
		local zsLv = gdata.aidZsLv[lastActorId]
		if not zsLv then
			zsLv = 0
			print("newworldboss.sendRankRewardtomail not have zsLv last aid:"..lastActorId)
		end
		--最后一刀的奖励
		local reward = drop.dropGroup(baseConf.lastDrop[zsLv+1])
		local mailData = {head=baseConf.lastMailHead, context=baseConf.lastMailContent, tAwardList=reward }
		mailsystem.sendMailById(lastActorId, mailData)
	end

	--结束时候的收尾工作
	ins:win()
	local sdata = getSystemData()
	local usingTime = gdata.end_time - gdata.start_time
	for _,v in ipairs(baseConf.lvUpTime) do
		if usingTime < v.t then
			sdata.blv = sdata.blv + v.lv
			if sdata.blv <= 0 then
				sdata.blv = 1
			elseif sdata.blv > #lvConf then
				sdata.blv = #lvConf
			end
			break
		end
	end
	gdata.fbhandle = nil
	gdata.scorelist = nil
	gdata.scorerank = nil
end

--BOSS死亡时候的处理
local function onMonsterDie(ins, mon, killerHdl)
    local bossId = ins.data.bossid
    local monid = Fuben.getMonsterId(mon)
    if monid ~= bossId then 
		print("newworldboss.onMonsterDie:monid ~= bossId") 
		return
	end
	--删除结束定时器
	local gdata = getGlobalData()
	if gdata.pveEid then
		LActor.cancelScriptEvent(nil, gdata.pveEid)
	end
	local lastKillActor = LActor.getActor(LActor.getEntity(killerHdl))
	--结束pve
	endPve(true, lastKillActor)
end

--通知玩家的复活信息
local function notifyRebornTime(actor, killerHdl)
	local cache = getDynamicData(actor)
    local rebornCd = (cache.rebornCd or 0) - System.getNowTime()
    if rebornCd < 0 then rebornCd = 0 end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Boss, Protocol.sNewWorldBoss_RebornCd)
    LDataPack.writeShort(npack, rebornCd)
    LDataPack.flush(npack)
end

--复活倒计时到了
local function reborn(actor, rebornCd)
    local cache = getDynamicData(actor)
    if cache.rebornCd ~= rebornCd then print(LActor.getActorId(actor).." newworldboss.reborn:cache.rebornCd ~= rebornCd") return end
    notifyRebornTime(actor)
	local x,y = getRandomPoint()
    LActor.relive(actor, x, y)
end

--加入鼓舞属性
local function AddAttr(actor)
	local attr = LActor.getNewWorldBossAttr(actor)
	attr:Reset()
	local cache = getDynamicData(actor)
	if cache.attrId then
		local cfg = NewWorldBossAttrConfig[cache.attrId]
		if cfg then
			for _,v in ipairs(cfg.attr) do
				attr:Add(v.type, v.value)
			end
		end
	end
	LActor.reCalcAttr(actor)
end

--玩家死亡时候的处理
local function onActorDie(ins, actor, killerHdl)
	local cache = getDynamicData(actor)
	-- 计时器自动复活
	local rebornCd = System.getNowTime() + (baseConf.rebornCd or 0)
	cache.eid = LActor.postScriptEventLite(actor, (baseConf.rebornCd or 0) * 1000, reborn, rebornCd)
	cache.rebornCd = rebornCd
	--通知复活时间
	notifyRebornTime(actor, killerHdl)
end

--副本中下线的处理
local function onOffline(ins, actor)
    --手动调用退出副本，否则虽然会触发退出副本，但是上线会自动进入副本中
    LActor.exitFuben(actor)
end

--玩家退出副本的时候
local function onExitFb(ins, actor)
	local cache = getDynamicData(actor)
	cache.attrId = nil
	--清除属性
	local attr = LActor.getNewWorldBossAttr(actor)
	attr:Reset()
	LActor.reCalcAttr(actor)
end

--发送鼓舞次数
local function sendAttrCount(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Boss, Protocol.sNewWorldBoss_BuyAttrCount)  
	if npack == nil then return end
	local cache = getDynamicData(actor)
	LDataPack.writeShort(npack, cache.attrId or 0)
	LDataPack.flush(npack)
end

--进入副本回调
local function onEnterFb(ins, actor)
	local gdata = getGlobalData()
	if not gdata.aidZsLv then gdata.aidZsLv = {} end
	local aid = LActor.getActorId(actor)
	gdata.aidZsLv[aid] = LActor.getZhuanShengLevel(actor)
	print("newworldboss.onEnterFb aid:"..aid..", zsLv:"..gdata.aidZsLv[aid])
	--加上属性
	AddAttr(actor)
	--发送排名
	onScoreRankTimer(System.getNowTime(), true)
	--发送鼓舞次数给客户端
	sendAttrCount(actor)
end

--获取是否能开启活动
local function canOpenAct()
	if (baseConf.openSevDay or 0) <= System.getOpenServerDay() then
		return true
	end
	return false
end

--开启前10分钟
local function newWorldBossPerStart(now_t, perTime)
	if not canOpenAct() then return end
	local gdata = getGlobalData()
	gdata.openIcon = true
	gdata.start_time = now_t + perTime
	print("newworldboss.newWorldBossPerStart start_time:"..(gdata.start_time or 0))
	--发个公告
	noticemanager.broadCastNotice(baseConf.perOpenNotice)
	--发送图标开启状态
	sendIconOpenStatus(true, nil)
end
_G.newWorldBossPerStart = newWorldBossPerStart

--全局开始动作
local function newWorldBossStart(now_t)
	if not canOpenAct() then return end
	if isOpen() then 
		print("newWorldBossStart is opened!")
		return 
	end
	local gdata = getGlobalData()
	gdata.openIcon = true
	gdata.aidZsLv = nil
	gdata.start_time = now_t
	gdata.end_time = gdata.start_time + baseConf.bossTime
	gdata.pveEid = LActor.postScriptEventLite(nil, baseConf.bossTime * 1000, endPve, false)
end
_G.newWorldBossStart = newWorldBossStart

--请求bossid
local function reqGetBossId(actor, packet)
	local bossid = getBossId()
	local curHp = nil
	local gdata = getGlobalData()
	if gdata.fbhandle and gdata.fbhandle ~= 0 then
		local ins = instancesystem.getInsByHdl(gdata.fbhandle)
		if ins and ins.boss_info and ins.boss_info.hp then
			curHp = ins.boss_info.hp
		end
	end
	if not curHp then
		curHp = MonstersConfig[bossid] and MonstersConfig[bossid].hp or 0
	end
	
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Boss, Protocol.sNewWorldBoss_SendBossId)  
	if npack == nil then return end
	LDataPack.writeInt(npack, bossid)
	LDataPack.writeDouble(npack, curHp)
	LDataPack.flush(npack)
end

--购买复活
local function reqBuyReborn(actor, packet)
    local cache = getDynamicData(actor)
    --复活时间已到
    if (cache.rebornCd or 0) < System.getNowTime() then 
		print("newworldboss.onReqBuyReborn: rebornCd < System.getNowTime(),  actorId:"..LActor.getActorId(actor)) 
		return 
	end
	--先判断有没有复活道具
	if baseConf.rebornItem and LActor.getItemCount(actor, baseConf.rebornItem) > 0 then
		LActor.costItem(actor, baseConf.rebornItem, 1, "newworldboss buy cd")
	else
		--判断钱是否足够
		local yb = LActor.getCurrency(actor, NumericType_YuanBao)
		if baseConf.clearCdCost > yb then 
			print("newworldboss.onReqBuyReborn: clearCdCost > yb, actorId:"..LActor.getActorId(actor))
			return 
		end
		--扣元宝
		LActor.changeYuanBao(actor, 0 - baseConf.clearCdCost, "newworldboss buy reborn")
	end
    cache.rebornCd = nil
	--通知复活时间
    notifyRebornTime(actor)
	--复活
	local x,y = LActor.getPosition(actor)
	LActor.relive(actor, x, y)
end

--请求购买鼓舞
local function reqBuyAttr(actor, packet)
	local gdata = getGlobalData()
	--判断活动是否开启 玩家是否在副本里面
	if not isOpen() and LActor.getFubenHandle(actor) ~= gdata.fbhandle then
		print(LActor.getActorId(actor).." newworldboss.reqBuyAttr not open or not in Fuben")
		return
	end
	local cache = getDynamicData(actor)
	local cfg = NewWorldBossAttrConfig[(cache.attrId or 0)+1]
	if not cfg then
		print(LActor.getActorId(actor).." newworldboss.reqBuyAttr not have cfg, attrId:"..tostring((cache.attrId or 0)+1))
		return
	end
	--判断是否够钱
	if LActor.getCurrency(actor, cfg.type or 2) < cfg.count then
		print(LActor.getActorId(actor).." newworldboss.reqBuyAttr not have money, attrId:"..tostring((cache.attrId or 0)+1))
		return
	end
	--扣钱
	LActor.changeCurrency(actor, cfg.type or 2, -cfg.count, "newworldboss buy attr")
	--设置ID
	cache.attrId = (cache.attrId or 0)+1
	--获取属性
	AddAttr(actor)
	--回应数据包给客户端
	sendAttrCount(actor)
end

--登陆事件回调
local function onLogin(actor)
	local gdata = getGlobalData()
	if gdata.openIcon then
		sendIconOpenStatus(true, actor)
	end
end

--根据伤害获得积分
local function getScore(damage)
	local p = baseConf.scoreParm
	return p.a * math.pow(damage, p.b) + p.c
end

--boss伤害的时候
local function onBossDamage(ins, monster, value, attacker, res)
	local gdata = getGlobalData()
	if gdata.scorelist == nil then gdata.scorelist = {} end
    local actor = LActor.getActor(attacker)
    if actor and value > 0 then
		local info = gdata.scorelist[LActor.getActorId(actor)]
		if info == nil then
			gdata.scorelist[LActor.getActorId(actor)] = {name = LActor.getName(actor), score = getScore(value)}
		else
			info.score = info.score + getScore(value)
		end
   		onScoreRankTimer(System.getNowTime(), false)
	end
end

--启动初始化
local function initGlobalData()
    --副本事件
	insevent.registerInstanceEnter(baseConf.fbId, onEnterFb)--进入副本回调
	insevent.registerInstanceActorDie(baseConf.fbId, onActorDie)--玩家死亡
	insevent.registerInstanceMonsterDie(baseConf.fbId, onMonsterDie)--怪物死亡
	insevent.registerInstanceOffline(baseConf.fbId, onOffline)--玩家离线
	insevent.registerInstanceExit(baseConf.fbId, onExitFb) --玩家退出副本事件
	insevent.registerInstanceMonsterDamage(baseConf.fbId, onBossDamage) --boss受伤事件
	
	--玩家事件
	actorevent.reg(aeUserLogin, onLogin)
	
	--消息处理
    netmsgdispatcher.reg(Protocol.CMD_Boss, Protocol.cNewWorldBoss_ReqEnter, reqEnterFb) --请求进入新世界boss副本
	netmsgdispatcher.reg(Protocol.CMD_Boss, Protocol.cNewWorldBoss_GetBossId, reqGetBossId)--获取bossid
	netmsgdispatcher.reg(Protocol.CMD_Boss, Protocol.cNewWorldBoss_BuyReborn, reqBuyReborn)--购买复活
	netmsgdispatcher.reg(Protocol.CMD_Boss, Protocol.cNewWorldBoss_BuyAttr, reqBuyAttr)--购买复活
end

table.insert(InitFnTable, initGlobalData)

--newworldboss
function gmHandle(actor, args)
	local cmd = args[1]
	if cmd == "start" then
		newWorldBossPerStart(System.getNowTime(), 0)
		newWorldBossStart(System.getNowTime())
	elseif cmd == "enter" then
		reqEnterFb(actor,nil)
	elseif cmd == "end" then
		endPve(false)
	elseif cmd == "bid" then
		print("newworldboss bossId:"..getBossId())
	elseif cmd == 'gw' then
		reqBuyAttr(actor, nil)
	elseif cmd == 'lv' then
		local sdata = getSystemData()
		print(sdata.blv)
	end
	return true
end
