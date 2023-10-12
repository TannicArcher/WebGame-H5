module("worldboss", package.seeall)

--[[
	bossdata = {
		id  bossId
		hfuben  副本id
		shield  护盾id
		curShield 当前护盾id
		belong  当前归属者
		monster 怪物
		shieldDamageList 护盾伤害列表
		isFinish true表示已不能进入副本，false可以进入
		table lottery {
			number eid  计时器id
			number reward 道具id
			number 最大點數角色 aid
			number 最大點數 point
			table record { [aid]: true} 抽奖记录
		}
	}
--]]

local Type = {
	worldBoss = 1,  --秘境boss
	publicBoss = 2, --野外Boss
	homeBoss = 3, --BOSS之家
	HolyBoss = 4, --神域boss
	Sanctuary = 5, --神兵圣域
	GodTower = 6, --神兵塔
	DarkMjBoss = 7,--暗之秘境
}
local PkMode = {
	belong = 0, --只能打归属模式
	free = 1, --自由pk模式
}
local p = Protocol
local baseConf = WorldBossBaseConfig
local bossConf = WorldBossConfig
worldBossData = worldBossData or {}
bossTypeId = {} --boss里面type=id,对应关系
intRefBossId = {} --定时刷新的世界boss的ID
local homeBossLvCfg = {}

local function getGlobalData()
    return worldBossData
end

local function getBossData(id)
    return worldBossData.bossList[id]
end

local function getGlobalRecord()
	local data = System.getStaticVar()
	if nil == data.worldBossRecord then data.worldBossRecord = {} end
	if nil == data.worldBossRecord.bossRecord then data.worldBossRecord.bossRecord = {} end

	return data.worldBossRecord
end

--[[
	bless = 0 --祝福值
	daily_count[boss类型]  已进入(挑战)次数
	count_lrect[boos类型]  最近恢复挑战次数的时间戳
	buy_count[boss类型]   已经购买次数
	id -- 当前进入的副本id
	deathMark --死亡标记, 用于异步计时器回调时验证
	eid 复活定时器句柄
	enterFbCd[boss类型]  挑战cd
	rebornCd  复活cd
	can_belong_count[boss类型] 可获得归属者次数
	resBelongCountTime[boss类型] 最近一次刷新归属者次数时间
]]
local function getStaticData(actor)
    local var = LActor.getStaticVar(actor)
    if nil == var.worldBoss then var.worldBoss = {} end
	if nil == var.worldBoss.enterFbCd then var.worldBoss.enterFbCd = {} end
	if nil == var.worldBoss.daily_count then var.worldBoss.daily_count = {} end
	if nil == var.worldBoss.count_lrect then var.worldBoss.count_lrect = {} end
	if nil == var.worldBoss.buy_count then var.worldBoss.buy_count = {} end
	if nil == var.worldBoss.resBelongCountTime then var.worldBoss.resBelongCountTime = System.getToday() end
    return var.worldBoss
end

--获取配置的PK模式
local function getPkMode(conf)
	return conf.pkMode or PkMode.belong
end

--改变祝福值
local function changeBless(actor, val)
	local data = getStaticData(actor)
	data.bless = (data.bless or 0) + val
end

--归属者改变
local function onBelongChange(bossData, oldBelong, newBelong)
	local conf = bossConf[bossData.id]
	if getPkMode(conf) == PkMode.belong then
		if oldBelong then
			LActor.setCamp(oldBelong, WorldBossCampType_Normal)
		end
		if newBelong then
			LActor.setCamp(newBelong, WorldBossCampType_Belong)
			--sendAttackedListToBelong(newBelong)
		end
		local actors = Fuben.getAllActor(bossData.hfuben)
		if actors ~= nil then
			for i = 1,#actors do 
				if LActor.getActor(actors[i]) ~= newBelong then 
					LActor.setCamp(actors[i], WorldBossCampType_Normal)
				end
			end
		end
	end
	--广播归属者信息
	sendBelongData(bossData.id, nil, oldBelong)

	if conf.revivalTime then
		--无归属回血
		if not newBelong then
			bossData.revEid = LActor.postScriptEventLite(nil, conf.revivalTime * 1000, function(_, boss)
				boss.revEid = nil
				if bossData.monster then
					LActor.changeHp(bossData.monster, LActor.getHpMax(bossData.monster))
				end
			end, bossData)
		end
	end
	--有新归属的时候清定时器
	if bossData.revEid and newBelong then
		LActor.cancelScriptEvent(nil, bossData.revEid)
		bossData.revEid = nil
	end

	--广播怪物攻击归属者的子角色
	--SendBossTargetRole(nil, bossData)
end

--根据伤害,获得格外的附加奖励
local function appendReward(reward, config, dmg)
	if config.soul and config.soul > 0 then
		table.insert(reward, {type=AwardType_Numeric, id=NumericType_Essence, count = config.soul})
	end
	if config.goldRate and config.goldRate > 0 then
		local gold = config.goldRate * dmg
		if gold > config.goldMax then gold = config.goldMax end
		table.insert(reward, {type=AwardType_Numeric, id=NumericType_Gold, count = gold})
	end
end

--重置每日次数
local function resetCounts(actor)
    local data = getStaticData(actor)
	for t,v in ipairs(baseConf.recoverTime) do
		if v and v == 0 then
			data.daily_count[t] = 0
		end
	end
	data.buy_count = {}

	--补历史天数的次数
	local diff_day = 0
	if data.resBelongCountTime then
		diff_day = math.floor((System.getToday() - data.resBelongCountTime)/(3600*24))--获得间隔几天
	end
	print(LActor.getActorId(actor).." worldboss.resetCounts diff_day:"..diff_day)
	if diff_day > 0 then
		if not data.can_belong_count then data.can_belong_count = {} end
		for t,v in ipairs(baseConf.belongCount) do
			if v and v > 0 then
				if not data.can_belong_count[t] then data.can_belong_count[t] = v end
				local lefCount = diff_day * v
				data.can_belong_count[t] = data.can_belong_count[t] + lefCount
				if data.can_belong_count[t] > baseConf.belongMaxCount[t] then
					data.can_belong_count[t] = baseConf.belongMaxCount[t]
				end
			end
		end
	end
	data.resBelongCountTime = System.getToday()
end

--检测时间恢复增加次数
local function checkTimeRecoverCounts(actor)
	local data = getStaticData(actor)
	local nowt = System.getNowTime()
	for t,cd in ipairs(baseConf.recoverTime) do
		if cd and cd > 0 then --定时恢复
			if (data.daily_count[t] or 0) > 0 then
				local spaic = nowt - (data.count_lrect[t] or 0)
				if spaic > 0 then
					local addCount = math.floor(spaic/(cd * 60))
					data.daily_count[t] = data.daily_count[t] - addCount
					if data.daily_count[t] < 0 then --恢复满了
						data.daily_count[t] = 0 
						data.count_lrect[t] = nowt
					else --还可以恢复
						data.count_lrect[t] = nowt - (spaic - addCount * cd * 60)
					end
				end
			end
		end
	end
end

--获取还剩多久恢复增加次数
local function getRecoverTime(actor, type)
	local data = getStaticData(actor)
	--一次都没用过,不用恢复次数
	if (data.daily_count[type] or 0) <= 0 then
		--print("getRecoverTime data.daily_count[t] <= 0")
		return 0
	end	
	--获取CD配置
	if not baseConf.recoverTime[type] or baseConf.recoverTime[type] <= 0 then
		--print("getRecoverTime baseConf.recoverTime[type] or baseConf.recoverTime[type] <= 0")
		return 0
	end
	local cd = baseConf.recoverTime[type] * 60
	--获取间隔时间
	local nowt = System.getNowTime()
	local spaic = nowt - (data.count_lrect[type] or 0)
	if spaic <= 0 then
		--print("getRecoverTime spaic <= 0")
		return 0
	end
	--间隔的这段时间需要加多少次
	local addCount = math.floor(spaic/cd)
	if addCount > 0 then 
		checkTimeRecoverCounts(actor)
	end
	--剩余时间 = cd - (间隔时间 - (需要加的次数*cd))
	local lefttime = cd - (spaic - (addCount * cd))
	--print("getRecoverTime lefttime="..lefttime)
	return lefttime
end

--获取玩家帮派名 
local function getGuildName(actor)
    local guildName = nil
    if LActor.getGuildPtr(actor) then guildName = LGuild.getGuildName(LActor.getGuildPtr(actor)) end

    return guildName or ""
end

--通知玩家的复活信息
local function notifyRebornTime(actor, killerHdl)
    local data = getStaticData(actor)
    local rebornCd = (data.rebornCd or 0) - System.getNowTime()
    if rebornCd < 0 then rebornCd = 0 end

    local npack = LDataPack.allocPacket(actor, p.CMD_Boss, p.sWorldBoss_updateRebornTime)
    LDataPack.writeShort(npack, rebornCd)
	LDataPack.writeDouble(npack, killerHdl or 0)
    LDataPack.flush(npack)
end

local function getNextShield(id, hp)
    if nil == hp then hp = 101 end

    local conf = bossConf[id]
    if nil == conf then print("getNextShield is null, id:"..id) return nil end

    for i, s in ipairs(conf.shield) do
        if s.hp < hp then return s end
    end

    return nil
end

--获取随机坐标
local function getRandomPoint(id)
    --随机坐标
    local index = math.random(1, #(bossConf[id].enterPos))
	local cfg = bossConf[id].enterPos[index]

    return cfg.posX, cfg.posY
end

--根据开服天数获取bossId
local function getBossId(conf)
	if not conf.openBossList then return conf.bossId end

	local keyList = {}
	for k in pairs(conf.openBossList or {}) do keyList[#keyList+1] = k end
	table.sort(keyList)

	local openDay = System.getOpenServerDay() + 1
	for i = #keyList, 1, -1 do
		if openDay >= keyList[i] then return conf.openBossList[keyList[i]] end
	end

	return conf.bossId
end

--初始化单个boss数据和副本
local function initBossDataFb(conf)
		local hfuben = Fuben.createFuBen(conf.fbid)
		if getPkMode(conf) == PkMode.belong then
			Fuben.setBelong(hfuben)
		end
		local ins = instancesystem.getInsByHdl(hfuben)
		if ins then 
			ins.data.id = conf.id
			ins.data.bossid = getBossId(conf)
			ins.data.type = conf.type
			ins.boss_info = {}
			--print("worldboss fuben create suceess,id:"..conf.id)
		else
			print("worldboss fuben create failure,not ins,id:"..conf.id)
			return
		end
		worldBossData.bossList[conf.id] = {
			id = conf.id,
			hpPercent = 100,
			hfuben = hfuben,
			nextShield = getNextShield(conf.id),
			shield = 0,
			curShield = nil,
			belong = nil,
			monster = nil,
			shieldDamageList = {},
			rbeid = nil,
			isFinish = false
		}
		--定点间隔刷新的处理
		if conf.intervalTime and conf.intervalTime > 0 then
			local dailyZeroTime = System.getToday()
			local curHour = System.getTime()
			local spaicHour = curHour+(conf.intervalTime-curHour%conf.intervalTime)
			worldBossData.bossList[conf.id].refTime = dailyZeroTime + spaicHour * 3600
		end
end

--刷出boss怪物
local function refreshTimer(id)
    --print("call worldboss.refreshTimer , curtime:" .. os.time())
	local conf = bossConf[id]
	local boss = worldBossData.bossList[conf.id]
	if not boss then print("worldboss.refreshTimer:boss is null, id:"..conf.id) return end
	if not boss.hfuben then print("worldboss.refreshTimer:boss.hfuben is null, id:"..conf.id) return end

	local ins = instancesystem.getInsByHdl(boss.hfuben)
	if ins then
		local monster = Fuben.createMonster(ins.scene_list[1], ins.data.bossid)
		if nil == monster then print("create world boss monster failed, bossid:"..ins.data.bossid) return end

		boss.monster = monster
		--print("create worldboss.index:"..tostring(id).." id:"..tostring(ins.data.bossid).. " hp:"..LActor.getHp(monster))
	end

	--初始化boss信息
	boss.nextShield = getNextShield(boss.id)
	boss.curShield = nil
	boss.shield = 0
	boss.isFinish = false
	if boss.shieldEid then
		LActor.cancelScriptEvent(nil, boss.shieldEid)
		boss.shieldEid = nil
	end
	if nil == boss.nextShield then print("worldboss refreshTimer nextShield is NULL,id:"..boss.id) end

	--print("worldboss monster create suceess,id:"..conf.id)

    --noticemanager.broadCastNotice(baseConf.refreshNotice)
end

local function reborn(actor, now_t)
    local data = getStaticData(actor)
    if data.deathMark ~= now_t then print(LActor.getActorId(actor).." worldboss.reborn:data.deathMark ~= now_t") return end

    notifyRebornTime(actor)
	local x, y = getRandomPoint(data.id)
    LActor.relive(actor, x, y)
	local boss = getBossData(data.id)
	--判断是否需要停止AI
	local conf = bossConf[data.id]
    if conf and conf.enterAi then
    	LActor.stopAI(actor)
    elseif boss and boss.monster then
		LActor.setAITarget(actor, boss.monster)
	end
end

--奖励表现类型1,弹窗口
local function SendWorldBossRewardWindow(actor, ins, reward, belong)
	print("worldboss.SendWorldBossRewardWindow to aid:"..LActor.getActorId(actor))
	--发窗口 直接给奖励
	local npack = LDataPack.allocPacket(actor, p.CMD_Boss, p.sWorldBoss_SendReward)
	if npack == nil then return end
	LDataPack.writeByte(npack, actor == belong and 1 or 0)
	LDataPack.writeString(npack, LActor.getName(belong))
	LDataPack.writeByte(npack, LActor.getJob(belong))
	LDataPack.writeByte(npack, LActor.getSex(belong))
	LDataPack.writeShort(npack, #reward)
	for _, v in ipairs(reward) do
		LDataPack.writeInt(npack, v.type or 0)
		LDataPack.writeInt(npack, v.id or 0)
		LDataPack.writeInt(npack, v.count or 0)
	end
	LDataPack.flush(npack)
end

--发送参与奖励
local function sendJoinReward(ins)
    local maxHp = Fuben.getMonsterMaxHp(ins.data.bossid)
    if 0 >= maxHp then print("worldboss.sendJoinReward:0 >= maxHp") return end

    local basePrecent = baseConf.precent or 0
    local info = ins.boss_info or {}
	--boss配置
	local conf = bossConf[ins.data.id]
    if not conf then print("worldboss.sendJoinReward:WorldBossConfig is null, id:"..tostring(ins.data.id)) return end
	local boss = getBossData(ins.data.id)
    --超过一定百分比才有奖励
    if info and info.damagelist then
		for k, v in pairs(info.damagelist) do
			local actor = LActor.getActorById(k)
			local percent = math.floor((v.damage / maxHp) * 100)
			if basePrecent <= percent and k ~= LActor.getActorId(boss.belong) then
				local head = string.format(baseConf.joinMailHead, baseConf.bossName[conf.type])
				local content = string.format(baseConf.joinMailContent, baseConf.bossName[conf.type])
				local reward = drop.dropGroup(conf.joinReward)
				appendReward(reward, conf, v.damage)
				local ahfuben = LActor.getFubenHandle(actor)
				if conf.dropType == 1 and actor and LActor.canGiveAwards(actor, reward) and ahfuben == boss.hfuben then
					LActor.giveAwards(actor, reward, "worldboss("..(ins.data.id)..") reward")
				else
					local mailData = {head=head, context=content, tAwardList=reward }
					mailsystem.sendMailById(k, mailData)
				end
				if ahfuben == boss.hfuben or not LActor.isInFuben(actor) then
					SendWorldBossRewardWindow(actor, ins, reward, boss.belong)
				end
				checkRewardNotice(reward, k, conf)
				print("worldboss.joinReward send : ".. k)
			end
			
			treasureboxsystem.getTreasureBox(k, ins.id) --发放宝箱
			if actor then 
				if conf.type == Type.publicBoss then-- 全民Boss任务
					actorevent.onEvent(actor, aeFullBoss, ins.id)
				elseif conf.type == Type.HolyBoss then --神域boss
					actorevent.onEvent(actor, aeHolyBoss, ins.id)
				elseif conf.type == Type.worldBoss then--秘境boss
					actorevent.onEvent(actor, aeMiJingBoss, ins.id)
				end
				if actor ~= boss.belong then
					--获得祝福值
					if conf.joinBless then
						changeBless(actor, conf.joinBless)
					end
					if conf.actJoinScore then
						actorevent.onEvent(actor, aeGetWBossActScore, conf.actJoinScore)
					end
					actorevent.onEvent(actor, aeWorldBoss, conf.id, ins.id, false)
				end
			end
		end
	end
end

local function endLottery(_, boss)
    if not boss.lottery then print("endLottery:boss.lottery is null") return end
    if not boss.lottery.aid then print("endLottery:boss.lottery.aid is null") return end

    local actorId, roll = boss.lottery.aid, boss.lottery.point

    local conf = bossConf[boss.id]
    if nil == conf then print("endLottery:conf is null, id:"..boss.id) return end
    
    --邮件
    local mailData = {
		head=string.format(baseConf.shieldMailHead, baseConf.bossName[conf.type]), 
		context=string.format(baseConf.shieldMailContent, baseConf.bossName[conf.type]), 
		tAwardList={{type=1,id=boss.lottery.reward,count=1}}
	}
    mailsystem.sendMailById(actorId, mailData)

    local name = LActor.getActorName(actorId)
    local bossName = MonstersConfig[conf.bossId].name or ""
    local itemName 
    if ItemConfig[boss.lottery.reward] then itemName = ItemConfig[boss.lottery.reward].name end

    --护盾奖励获取者公告
    noticemanager.broadCastNotice(baseConf.lotteryNotice, name or "", bossName, itemName or "")

    boss.lottery = nil
end

local function startLottery(ins, reward)
	if not reward then return end
    local id = ins.data.id
    local conf = bossConf[id]
    if nil == conf then print("startLottery:conf is null, id:"..id) return end
    local boss = getBossData(id)
    if nil == boss then print("startLottery:boss is null, id:"..conf.id) return end

    if  0 == #boss.shieldDamageList then print("startLottery:boss.shieldDamageList is Null,id:"..id) return end

    if boss.lottery then
        LActor.cancelScriptEvent(nil, boss.lottery.eid)
        endLottery(nil, boss)
    end

    --抽奖信息初始化
    boss.lottery = {}
    boss.lottery.eid = LActor.postScriptEventLite(nil, (baseConf.lotteryTime or 0) * 1000, endLottery, boss)
    boss.lottery.reward = reward
    boss.lottery.aid = nil
    boss.lottery.point = 0
    boss.lottery.record = {}

    --给护盾造成过伤害的玩家发送摇骰子界面
    for k, aid in pairs(boss.shieldDamageList) do
        local actor = LActor.getActorById(aid)
		if actor and boss.hfuben == LActor.getFubenHandle(actor) then
			local npack =  LDataPack.allocPacket(actor, Protocol.CMD_Boss, Protocol.sWorldBoss_StartLottery)
			LDataPack.writeInt(npack, reward or 0)
			LDataPack.flush(npack)
		end
    end
end

local function sendBossRefresh(type, id)
	--通知客户端;一个boss复活了
	local npack = LDataPack.allocPacket()
	if npack == nil then return end
	LDataPack.writeByte(npack, Protocol.CMD_Boss)
	LDataPack.writeByte(npack, Protocol.sWorldBoss_Refresh)
	LDataPack.writeByte(npack, type)
	LDataPack.writeInt(npack, id)
	System.broadcastData(npack)
end

local function refreshBoss(_, id) 
	print("worldboss.refreshBoss:"..id)
	local conf = bossConf[id]
	if nil == conf then print("worldboss.refreshBoss:conf is null, id:"..tostring(id)) return end
	initBossDataFb(conf)
	refreshTimer(id)
	sendBossRefresh(conf.type, id)
end

local function onWin(ins)
    local conf = bossConf[ins.data.id]
    if nil == conf then print("onWin:conf is null, id:"..tostring(ins.data.id)) return end

    local boss = getBossData(ins.data.id)
    if nil == boss then print("onWin:boss is null, id:"..tostring(ins.data.id)) return end
	if boss.revEid then
		LActor.cancelScriptEvent(nil, boss.revEid)
		boss.revEid = nil
	end
    --记录归属信息
    local gRecord = getGlobalRecord()
	local actorName = ""
    if boss.belong then
    	--把归属者AI恢复
		local role_count = LActor.getRoleCount(boss.belong)
		for i = 0,role_count - 1 do
			local role = LActor.getRole(boss.belong,i)
			LActor.setAIPassivity(role, false)
		end	
    	--减少归属者获得次数
    	local bdata = getStaticData(boss.belong)
    	if baseConf.belongCount[conf.type] and baseConf.belongCount[conf.type] > 0 then
    		if not bdata.can_belong_count then bdata.can_belong_count = {} end
	    	bdata.can_belong_count[conf.type] = (bdata.can_belong_count[conf.type] or 0) - 1
	    	if bdata.can_belong_count[conf.type] < 0 then bdata.can_belong_count[conf.type] = 0 end
	    end
		--记录到副本实例里面,如果在刚赢,就刷新下一个副本
		--这里的boss里面的数据就俨然是新的数据了
		ins.data.belong = boss.belong 
        --发放归属奖励
        sendBelongReward(ins)

        local actorId = LActor.getActorId(boss.belong)
        actorName = LActor.getActorName(actorId)
        local guildName = getGuildName(boss.belong)

        --保存归属数据
        if nil == gRecord.bossRecord[ins.data.id] then gRecord.bossRecord[ins.data.id] = {} end
        gRecord.bossRecord[ins.data.id].name = actorName or ""
        gRecord.bossRecord[ins.data.id].guildName = guildName
    end
	
     --参与奖励
    if conf.joinReward then
    	sendJoinReward(ins)
	end
	
    --设置标志, 活动结束前玩家不能再进入该副本
    boss.isFinish = true
	
	if not conf.intervalTime or conf.intervalTime <= 0 then
		local key = math.min(System.getOpenServerDay()+1, #conf.refreshTime)
		local refreshTime = conf.refreshTime[key]
		--合服的几天,野外boss时间减半
		if conf.type == Type.publicBoss then
			for _, id in pairs(baseConf.halvedActId or {}) do
				if not activitysystem.activityTimeIsEnd(id) then
				refreshTime = refreshTime / 2
					break
			end
		end
		end
		--记录下次刷新时间
		boss.refTime = System.getNowTime() + refreshTime
		--注册定时器通知复活
		boss.rbeid = LActor.postScriptEventLite(nil, refreshTime * 1000, refreshBoss, ins.data.id)
	end
	
	--发消息通知世界boss胜利:sWorldBoss_sendWin
	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_Boss, Protocol.sWorldBoss_sendWin)
	if npack then
		LDataPack.writeString(npack, actorName)
		Fuben.sendData(boss.hfuben, npack)
	end
	
	--挑战记录
	if conf.type ~= Type.worldBoss then
		local info = ins.boss_info
		if info.damagerank and info.damagerank[1] then
			local rank = info.damagerank[1]
			if not boss.record then boss.record = {} end
			if #boss.record >= 5 then
				table.remove(boss.record, 1)
			end
			table.insert(boss.record,{	
				time  = System.getNowTime(),
				name  = rank.name,
				power = LActor.getActorPower(rank.id) 
			})
		end
	end
	
    --清空一些失效数据
	boss.belong = nil
    boss.monster = nil	
	boss.hfuben = nil
	if boss.shieldEid then
		LActor.cancelScriptEvent(nil, boss.shieldEid)
		boss.shieldEid = nil
	end
	
    print("worldboss:boss was killed, id:"..ins.data.id)
    --广播一下boss死亡
 	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, Protocol.CMD_Boss)
	LDataPack.writeByte(pack, Protocol.sWorldBoss_SendBossDie)
	LDataPack.writeInt(pack, ins.data.id)
	System.broadcastData(pack)   
end

local function onLose(ins)
	print("worldboss fuben is Should not be onLose, id:"..tostring(ins.data.id)..", fbid:"..tostring(ins:getFid()))
	print(debug.traceback())
	assert(false)
end

local function notifyShield(hfuben, type, shield, maxShield, reward)
	if not hfuben then return end
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, p.CMD_Boss)
    LDataPack.writeByte(npack, p.sWorldBoss_BossShield)

	LDataPack.writeByte(npack, type or 0)
    LDataPack.writeInt(npack, shield)
	LDataPack.writeInt(npack, maxShield)
	LDataPack.writeByte(npack, reward and 1 or 0)
    Fuben.sendData(hfuben, npack)
end

--发送归属者信息
function sendBelongData(id, actor, oldBelong)
    local boss = getBossData(id)
    if not boss then print("worldboss.sendBelongData:boss is null, id:"..id) return end
    
    local npack = nil
    if actor then
        npack = LDataPack.allocPacket(actor, p.CMD_Boss, p.sWorldBoss_UpdateBelong)    
    else
        npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, p.CMD_Boss)
        LDataPack.writeByte(npack, p.sWorldBoss_UpdateBelong)
    end

	--新归属者
    local hdl = 0 --玩家handle
	if boss.belong then
		hdl = LActor.getHandle(boss.belong)
	end
    LDataPack.writeDouble(npack, hdl)
	
	--上一任归属者
	local ohdl = 0
	local actorName = ""
	if oldBelong then
		ohdl = LActor.getHandle(oldBelong)
		actorName = LActor.getActorName(LActor.getActorId(oldBelong))
	end
	LDataPack.writeDouble(npack, ohdl)
	LDataPack.writeString(npack, actorName)

    if actor then
        LDataPack.flush(npack)
    else
        Fuben.sendData(boss.hfuben, npack)
    end
end

local function onEnterFb(ins, actor)
    print("worldboss.onEnterFb:ins.data.id="..tostring(ins.data.id))
    local boss = getBossData(ins.data.id)
    if not boss then print("worldboss.onEnterFb:boss is null, id:"..tostring(ins.data.id)) return end
	local aid = LActor.getActorId(actor)
	--进去过就算
	if not ins.boss_info.damagelist then ins.boss_info.damagelist = {} end
	if not ins.boss_info.damagelist[aid] then
		ins.boss_info.damagelist[aid] = {}
		ins.boss_info.damagelist[aid].name = LActor.getName(actor)
		ins.boss_info.damagelist[aid].damage = 0
	end
	
	local conf = bossConf[ins.data.id]
	
    local data = getStaticData(actor)
    data.enterFbCd[conf.type] = 0
	data.multi_kill = 0

    if boss.curShield then
        nowShield = boss.shield
		if (boss.curShield.type or 0) == 1 then
			nowShield = nowShield - System.getNowTime()
			if nowShield < 0 then nowShield = 0 end
		end
		--护盾信息
		notifyShield(ins.handle, (boss.curShield.type or 0), nowShield, boss.curShield.shield, boss.curShield.reward)
    end

    --归属者信息
    sendBelongData(ins.data.id, actor)

	--设置阵营为普通模式
	local pkm = getPkMode(conf)
	if pkm == PkMode.belong then
		LActor.setCamp(actor, WorldBossCampType_Normal)
	elseif pkm == PkMode.free then
		LActor.setCamp(actor, LActor.getActorId(actor))
		LActor.setAITarget(actor, boss.monster)
	end
	
	--进入场景公告
	if conf.enterNoticeId then
		noticemanager.broadCastNotice(conf.enterNoticeId, LActor.getName(actor))
	end
	if conf.enterAi then
		LActor.stopAI(actor)
	end
	--发送boss正在攻击的归属者的角色ID
	--SendBossTargetRole(actor, boss)
end

local function sendBelongRewardByMail(actorId, bossName, reward)
	local mailData = {
		head=string.format(baseConf.belongMailHead, bossName), 
		context=string.format(baseConf.belongMailContent, bossName), 
		tAwardList=reward
	}
	mailsystem.sendMailById(actorId, mailData)
end

local function getNoticeId(quality)
	for k, v in pairs(WorldBossBaseConfig.qualityNotice or {}) do
		if quality == k then return v end
	end

	return baseConf.rewardNotice
end

--极品奖励公告
function checkRewardNotice(reward, aid, config)
	local actorName = LActor.getActorName(aid)
	local sceneName = baseConf.bossName[config.type] or ""
	local bossName = MonstersConfig[config.bossId].name or ""

    for _, v in ipairs(reward or {}) do
        if v.type == 1 and ItemConfig[v.id] and ItemConfig[v.id].needNotice == 1 then
        	local itemName = item.getItemDisplayName(v.id)
            noticemanager.broadCastNotice(getNoticeId(ItemConfig[v.id].quality), actorName, sceneName, bossName, itemName)
        end
    end
end

--检测附加祝福值奖励,id:boss玩法配置ID
local function appendBlessReward(actor, reward, id)
	if not actor then return end
	print(LActor.getActorId(actor).." worldBoss.appendBlessReward,id:"..id)
	local zsLevel = LActor.getZhuanShengLevel(actor)
	local cfg = BossBlessConfig[zsLevel]
	if not cfg then return end
	local data = getStaticData(actor)
	if cfg.needBless <= (data.bless or 0) then
		for _,cid in ipairs(cfg.boss or {}) do
			if cid == id then
				print(LActor.getActorId(actor).." worldBoss.appendBlessReward,have reward id:"..id)
				local bossCfg = bossConf[id]
				if bossCfg then 
					local breward = drop.dropGroup(bossCfg.blessReward)
					for _,v in ipairs(breward or {}) do
						table.insert(reward, v)
					end
					changeBless(actor, 0-(bossCfg.blessCost or 0))
				else
					print(LActor.getActorId(actor).." worldBoss.appendBlessReward,not bossCfg id:"..id)
				end
				break
			end
		end
	end
end

--发送归属奖励
function sendBelongReward(ins)
	local id = ins.data.id
    local boss = getBossData(id)
    if not boss then print("worldboss.sendBelongReward:boss is null, id:"..id) return end
    if not boss.belong then print("sendBelongReward:boss belong is null, id:"..id) return end

    local actorId = LActor.getActorId(boss.belong)
    local conf = bossConf[id]
    if not conf then print("worldboss.sendBelongReward:conf is null, id:"..id) return end
    if not conf.belongReward then print("sendBelongReward:conf.belongReward is null, id:"..id) return end
	--增加归属者的祝福值
	if boss.belong then
		if conf.belongBless then
			changeBless(boss.belong, conf.belongBless)
		end
		if conf.actBelongScore then
			actorevent.onEvent(boss.belong, aeGetWBossActScore, conf.actBelongScore)
		end
		actorevent.onEvent(boss.belong, aeWorldBoss, conf.id, ins.id, true)
	end
	--奖励掉落
	local reward = drop.dropGroup(conf.belongReward)
	local damage = ins.boss_info and ins.boss_info.damagelist and ins.boss_info.damagelist[actorId] and ins.boss_info.damagelist[actorId].damage or 0
	if damage > 0 then
		appendReward(reward, conf, damage)
	end
	--检测祝福值奖励
	if not conf.blessRate or conf.blessRate >= math.random(100) then
		appendBlessReward(boss.belong, reward, id)
	end
	if LActor.getFubenHandle(boss.belong) == boss.hfuben then
		if conf.dropType == 1 then
			if LActor.canGiveAwards(boss.belong, reward) then
				LActor.giveAwards(boss.belong, reward, "worldboss("..(ins.data.id)..") reward")
			else
			    --邮件
				sendBelongRewardByMail(actorId, baseConf.bossName[conf.type], reward)
			end
			SendWorldBossRewardWindow(boss.belong, ins, reward, boss.belong)
		else
			local hscene = LActor.getSceneHandle(boss.belong)
			Fuben.RewardDropBag(hscene, ins.data.boss_die_x or 0, ins.data.boss_die_y or 0, actorId, reward)
		end

		checkRewardNotice(reward, actorId, conf)
	else
		print(actorId.." worldboss.sendBelongReward, belong is not in worldboss fb, boss.hfuben="..tostring(boss.hfuben)..", belong_fbh="..LActor.getFubenHandle(boss.belong))
	end
    print("worldboss send reward to boss belong: ".. actorId)
	actorevent.onEvent(boss.belong, aeGetWroldBossBelong, id, conf.bossId)
    local actorName = LActor.getActorName(actorId)
    local guildName = getGuildName(boss.belong)

    local bossName = nil
    if conf.bossId and MonstersConfig[conf.bossId] then bossName = MonstersConfig[conf.bossId].name end

    --公告
    noticemanager.broadCastNotice(baseConf.killNotice, actorName or "", guildName, bossName or "")
end

--清空归属者
local function clearBelongInfo(ins, actor)
    local bossData = getBossData(ins.data.id)
    if nil == bossData then print("worldboss.clearBelongInfo:bossData is null, id:"..ins.data.id) return end

    if actor == bossData.belong then
        bossData.belong = nil
		onBelongChange(bossData, actor, bossData.belong)
    end
end

local function canGetBelong(actor, cfg)
	if not cfg then return false end
	local canCount = baseConf.belongCount[cfg.type] or 0
	if canCount <= 0 then return true end
	local data = getStaticData(actor)
	if not data.can_belong_count then data.can_belong_count = {} end
	if not data.can_belong_count[cfg.type] then data.can_belong_count[cfg.type] = canCount end
	return data.can_belong_count[cfg.type] > 0
end

local function onBossDamage(ins, monster, value, attacker, res)
    local bossId = ins.data.bossid
    local monid = Fuben.getMonsterId(monster)
    if monid ~= bossId then print("worldboss.onBossDamage:monid ~= bossId, id:"..ins.data.id) return end

    local boss = getBossData(ins.data.id)
    if nil == boss then print("worldboss.onBossDamage:bossdata is null, id:"..ins.data.id) return end
    local cfg = bossConf[ins.data.id]
    if nil == cfg then print("worldboss.onBossDamage:cfg is null, id:"..ins.data.id) return end
    --第一下攻击者为boss归属者
    if nil == boss.belong and boss.hfuben == LActor.getFubenHandle(attacker) then 
        local actor = LActor.getActor(attacker)
        if actor and LActor.isDeath(actor) == false and canGetBelong(actor,cfg) then 
			local oldBelong = boss.belong
			boss.belong = actor         
			onBelongChange(boss, oldBelong, actor)
			--使怪物攻击归属者
			LActor.setAITarget(monster, LActor.getLiveByJob(actor))
		end		
    end

    local oldhp = LActor.getHp(monster)
    if oldhp <= 0 then print("worldboss.onEnterFb:boss oldhp <= 0, monid:"..monid) return end
    local hp  = res.ret --实际血量

    --血量百分比
    hp = hp / LActor.getHpMax(monster) * 100
	
	boss.hpPercent = math.ceil(hp)

    if 0 == boss.shield or nil == boss.shield then
        --需要触发护盾
        if boss.nextShield and 0 ~= boss.nextShield.hp and hp < boss.nextShield.hp then
            boss.curShield = boss.nextShield
            boss.nextShield = getNextShield(ins.data.id, boss.curShield.hp)
            res.ret = math.floor(LActor.getHpMax(monster) * boss.curShield.hp / 100)
			if (boss.curShield.type or 0) == 0 then
				boss.shield = boss.curShield.shield
				notifyShield(boss.hfuben, 0, boss.shield, boss.curShield.shield, boss.curShield.reward)
			else
				LActor.SetInvincible(monster, true)
				boss.shield = boss.curShield.shield + System.getNowTime()
				notifyShield(boss.hfuben, 1, boss.curShield.shield, boss.curShield.shield, boss.curShield.reward)
				print("worldboss.onBossDamage: postScriptEventLite shieldEid, id:"..(ins.data.id))
				--注册护盾结束定时器
				boss.shieldEid = LActor.postScriptEventLite(nil, (boss.curShield.shield or 0) * 1000, function(_,boss) 
					boss.shield = 0
					LActor.SetInvincible(boss.monster, false)
					notifyShield(boss.hfuben, 1, 0, boss.curShield.shield, boss.curShield.reward)
				end, boss)
			end
        end
    elseif boss.curShield and (boss.curShield.type or 0) == 0 then
	    --记录对护盾造成伤害的玩家
		local actor = LActor.getActor(attacker)
		if actor then
			local id = LActor.getActorId(actor)
			local isFind = false
			for k, v in pairs(boss.shieldDamageList) do
				if v == id then 
					isFind = true
					break
				end
			end

			if not isFind then 
				table.insert(boss.shieldDamageList, id)
			end
		end
		--记录变更前的护盾百分比
        local lastShield = math.floor(boss.shield / boss.curShield.shield * 100)
		--检测扣除护盾的值或者护盾结束
        if boss.shield > value then
            boss.shield = boss.shield - value
            res.ret = oldhp
        else
            --护盾消失
            boss.shield = 0
            value = value - boss.shield
            hp = oldhp - value
            if hp < 0 then hp = 0 end
            res.ret = hp
            --触发抽奖
            startLottery(ins, boss.curShield.reward)
        end
        --护盾百分比变化时广播
        local nowShield = math.floor(boss.shield / boss.curShield.shield * 100)
        if lastShield ~= nowShield then
	        print("worldboss.onBossDamage nowShield: "..nowShield)
            notifyShield(boss.hfuben, boss.curShield.type or 0, boss.shield, boss.curShield.shield)
        end
    end
end

-- 清除玩家副本内的伤害信息
local function clearHurtInfo(ins, actor)
    
    local id = LActor.getActorId(actor)
    local info = ins.boss_info or {}

    --清除对boss的伤害
    for k, v in pairs(info.damagelist or {}) do
        if id == k then table.remove(info.damagelist, k) break end
    end

    local bossData = getBossData(ins.data.id)
    if nil == bossData then print("worldboss.clearHurtInfo:bossData is null, id:"..ins.data.id) return end

    --清除对护盾的伤害
    for k, v in pairs(bossData.shieldDamageList or {}) do
        if id == k then table.remove(bossData.shieldDamageList, k) break end
    end
end

--发送所有boss信息
local function sendBossViewData(actor, boss_type)
	local ids = bossTypeId[boss_type]
	if not ids then return end
	
	local data = getStaticData(actor)
    local gRecord = getGlobalRecord()
	local now_t = System.getNowTime()
	
    local cd = (data.enterFbCd[boss_type] or 0) - now_t
    if 0 > cd then cd = 0 end
	
    local npack = LDataPack.allocPacket(actor, p.CMD_Boss, p.sWorldBoss_UpdateBossViewInfo)
    LDataPack.writeByte(npack, boss_type) --gdata.isOpen and 1 or 0)
    LDataPack.writeShort(npack, cd or 0)
    LDataPack.writeShort(npack, baseConf.dayCount[boss_type] - (data.daily_count[boss_type] or 0))
    LDataPack.writeShort(npack, #ids)
	
	
    for _, id in pairs(ids) do
		local boss = getBossData(id)
        --if nil == gRecord.bossRecord[id] then gRecord.bossRecord[id] = {} end
		local intervaltime = (boss.refTime or 0) - System.getNowTime()
		if intervaltime < 0 then intervaltime = 0 end
		
		local chNum = 0
		local isCh = 0
		--获取伤害列表,bossinfo
		if boss.hfuben then
			local ins = instancesystem.getInsByHdl(boss.hfuben)
			if ins and ins.boss_info and ins.boss_info.damagelist then
				chNum = #(ins.boss_info.damagerank or {})
				isCh = ins.boss_info.damagelist[LActor.getActorId(actor)] and 1 or 0
			end
		end
		
        LDataPack.writeInt(npack, id)
        LDataPack.writeString(npack, gRecord.bossRecord[id] and gRecord.bossRecord[id].name or "")
        LDataPack.writeString(npack, gRecord.bossRecord[id] and gRecord.bossRecord[id].guildName or "")
        LDataPack.writeInt(npack, intervaltime)
        LDataPack.writeShort(npack, boss.isFinish and 2 or 1)
		LDataPack.writeByte(npack, boss.hpPercent or 100) --血量百分比
		LDataPack.writeShort(npack, chNum) --挑战中的玩家数
		LDataPack.writeByte(npack, isCh) --是否正在挑战
    end
    
	LDataPack.writeShort(npack, getRecoverTime(actor, boss_type) or 0)
	LDataPack.writeShort(npack, data.buy_count[boss_type] or 0)
	LDataPack.writeShort(npack, data.can_belong_count and data.can_belong_count[boss_type] or (baseConf.belongCount[boss_type] or 0))
	
    LDataPack.flush(npack)
end

--退出的处理,特别注意:如果副本已经赢了,退出,其中很有可能会操作到新数据的bossData
local function onExitFb(ins, actor)
    local data = getStaticData(actor)
	local bossData = getBossData(ins.data.id)
    if ins.is_win == false then 
		data.enterFbCd[ins.data.type] = System.getNowTime() + baseConf.challengeCd[ins.data.type] 
	elseif bossData and ins.data.belong == actor then
		local drops = Fuben.getAllDropBag(ins:getHandle())
		if drops ~= nil then 
			local actorId = LActor.getActorId(actor)
			local reward = {}
			for i = 1,#drops do 
				local aid,type,id,count = LActor.getDropBagData(drops[i])
				if aid and (aid == 0 or aid == actorId) then
					table.insert(reward, {type=type,id=id,count=count})
					LActor.DestroyEntity(drops[i])
				end
			end
			if reward then
				sendBelongRewardByMail(actorId, baseConf.bossName[ins.data.type], reward)
			end
		end
	end
	
	--删除复活定时器
    data.deathMark = nil
	if data.eid then
		LActor.cancelScriptEvent(actor, data.eid)
		data.eid = nil
	end
	
	--清空连杀数量
    data.multi_kill = 0
	--退出副本时候切换回正常阵营
	LActor.setCamp(actor, WorldBossCampType_Normal)
	
	if ins.is_win == false then 
		--清除玩家伤害信息
		clearHurtInfo(ins, actor)

		--清空归属
		clearBelongInfo(ins, actor)
		
		if nil == bossData then
			print("worldboss.onExitFb:bossData is null, id:"..ins.data.id)
		elseif bossData.belong then
			sendAttackedListToBelong(bossData.belong)
		end
	end
	
    --发送boss信息
    sendBossViewData(actor, ins.data.type)
	data.id = nil
	data.rebornCd = nil
	--退出把AI恢复
	local role_count = LActor.getRoleCount(actor)
	for i = 0,role_count - 1 do
		local role = LActor.getRole(actor,i)
		LActor.setAIPassivity(role, false)
	end	
end

--副本中下线的处理,特别注意:如果副本已经赢了,下线,其中很有可能会操作到新数据的bossData
local function onOffline(ins, actor)
    --手动调用退出副本，否则虽然会触发退出副本，但是上线会自动进入副本中
    LActor.exitFuben(actor)

	if ins.is_win == false then 
		--清除玩家相关信息
		clearHurtInfo(ins, actor)

		--清空归属
		clearBelongInfo(ins, actor)
	end

    local data = getStaticData(actor)
    data.multi_kill = 0
end

--连杀公告
local function multiKillNotice(ins, actor)
    local data = getStaticData(actor)
    if nil == data.multi_kill then data.multi_kill = 0 end

    local actorId = LActor.getActorId(actor)
    local actorName = LActor.getActorName(actorId)
	local conf = WorldBossKillMsgConfig
	local msgId = nil
	for _,v in ipairs(conf) do
		if v.killNum == data.multi_kill then
			msgId = v.id
			break
		end
	end
	if not msgId then msgId = #conf end
    if conf[msgId] and conf[msgId].killNum <= data.multi_kill then
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, p.CMD_Boss)
		LDataPack.writeByte(npack, p.sWorldBoss_MultiKillNotice)
        LDataPack.writeString(npack, actorName or "")
        LDataPack.writeShort(npack, data.multi_kill)
		LDataPack.writeShort(npack, msgId)
        Fuben.sendData(ins.handle, npack)
    end
end

local function onActorDie(ins, actor, killerHdl)
    local data = getStaticData(actor)
	
    local et = LActor.getEntity(killerHdl)
    if not et then print("onActorDie:et is null") return end

    local bossData = getBossData(ins.data.id)
    if nil == bossData then print("onActorDie:bossData is null, id:"..ins.data.id) return end

    local actorId = LActor.getActorId(actor)
    local actorName = LActor.getActorName(actorId)
    local actorGuildName = getGuildName(actor)

    --杀人数累加
	local killer_actor = LActor.getActor(et)
    if killer_actor then
        local data = getStaticData(killer_actor)
        data.multi_kill = (data.multi_kill or 0) + 1

        --连杀公告处理
        multiKillNotice(ins, killer_actor)
    end
    local cfg = bossConf[ins.data.id]
	local pkm = getPkMode(cfg)
    if actor == bossData.belong then
		--归属者被玩家打死，该玩家是新归属者
        if killer_actor and LActor.getFubenHandle(killer_actor) == ins.handle and canGetBelong(killer_actor, cfg) then 
            bossData.belong = killer_actor
            --怪物攻击新的归属者
            if bossData.monster then LActor.setAITarget(bossData.monster, et) end
        else--归属者不是被场景内的玩家
            bossData.belong = nil
        end

        --广播归属者信息
		onBelongChange(bossData, actor, bossData.belong)
	else		
		if pkm == PkMode.belong then
			--不是归属者,死亡时候切换回正常阵营
			if LActor.getCamp(actor) == WorldBossCampType_Attack then
				LActor.setCamp(actor, WorldBossCampType_Normal)
				sendAttackedListToBelong(bossData.belong)
			end
		end
    end
	
	--所有目标是死亡的人;打boss去
	local actors = Fuben.getAllActor(bossData.hfuben)
	if actors ~= nil and bossData.monster then
		for i = 1,#actors do 
			if LActor.getActor(LActor.getAITarget(LActor.getLiveByJob(actors[i]))) == actor then
				if cfg.killerStopAi then
					LActor.stopAI(actors[i])
				elseif pkm == PkMode.free then
					LActor.setAITarget(actors[i], bossData.monster)
				end
			end
		end
	end

	local nowt = System.getNowTime()
    -- 计时器自动复活
	if baseConf.rebornCd[ins.data.type] and baseConf.rebornCd[ins.data.type] > 0 then
		data.eid = LActor.postScriptEventLite(actor, baseConf.rebornCd[ins.data.type] * 1000, reborn, nowt)
		data.rebornCd = nowt + baseConf.rebornCd[ins.data.type]
	end
    data.deathMark = nowt

    notifyRebornTime(actor, killerHdl)
end

--内部统一处理函数
local function enter(actor, id)
    --随机坐标
    local x, y = getRandomPoint(id)

    local boss = getBossData(id)
    return LActor.enterFuBen(actor, boss.hfuben, 0, x, y)
end

local function onReqBossList(actor, packet)
	local boss_type = LDataPack.readByte(packet)
	checkTimeRecoverCounts(actor)
    sendBossViewData(actor, boss_type)
end

local function DefaultCheckEnter(actor, conf, boss)
	--先判断开服日期
	if conf.openTime and conf.openTime > System.getOpenServerDay() then
		print(string.format("worldboss.DefaultCheckEnter req failed. actorId:%d, openTime:%d, confopentime:%d", LActor.getActorId(actor), System.getOpenServerDay(), conf.openTime))
		return false
	end
	--判断转生等级是否符合
	if LActor.getZhuanShengLevel(actor) < conf.zsLevel then
		print(string.format("worldboss.DefaultCheckEnter req failed. actorId:%d, actorzsLevel:%d, confzsLevel:%d", LActor.getActorId(actor), LActor.getZhuanShengLevel(actor), conf.zsLevel))
		LActor.sendTipmsg(actor, string.format(LAN.BOSS.wb006, conf.zsLevel), ttTipmsgWindow)
		return false
	end
	
	--判断等级是否符合
	if LActor.getLevel(actor) < conf.level then
		print(string.format("worldboss.DefaultCheckEnter req failed. actorId:%d, actorLevel:%d, confLevel:%d", LActor.getActorId(actor), LActor.getLevel(actor), conf.level))
		LActor.sendTipmsg(actor, string.format(LAN.BOSS.wb005, conf.level), ttTipmsgWindow)
		return false
	end

	--判断轮回等级是否符合
	if LActor.getReincarnateLv(actor) < (conf.samsaraLv or 0) then
		print(string.format("worldboss.DefaultCheckEnter req failed. actorId:%d, actorLevel:%d, confLevel:%d", LActor.getActorId(actor), LActor.getReincarnateLv(actor), conf.samsaraLv or 0))
		return false
	end
	return true
end

local checkEnterType = {
	[Type.worldBoss] = function(actor, conf, boss)
		--判断转生等级是否符合
		local zsLevel = LActor.getZhuanShengLevel(actor)
		if zsLevel % 2 == 0 then zsLevel = zsLevel-1 end
		if zsLevel ~= conf.zsLevel then
			print(string.format("worldBoss.checkEnter:req failed. actorId:%d, actorzsLevel:%d, confzsLevel:%d", LActor.getActorId(actor), LActor.getZhuanShengLevel(actor), conf.zsLevel))
			LActor.sendTipmsg(actor, string.format(LAN.BOSS.wb006, conf.zsLevel), ttTipmsgWindow)
			return false
		end
		
		--判断等级是否符合
		if LActor.getLevel(actor) < conf.level then
			print(string.format("worldboss.checkEnter:req failed. actorId:%d, actorLevel:%d, confLevel:%d", LActor.getActorId(actor), LActor.getLevel(actor), conf.level))
			LActor.sendTipmsg(actor, string.format(LAN.BOSS.wb005, conf.level), ttTipmsgWindow)
			return false
		end	
		return true
	end,
	[Type.Sanctuary] = function(actor, conf, boss)
		--判断转生等级是否符合
		if LActor.getZhuanShengLevel(actor) < conf.zsLevel[1] or
			LActor.getZhuanShengLevel(actor) > conf.zsLevel[2] then
			print(string.format("Sanctuary.checkEnter:req failed. actorId:%d, actorzsLevel:%d, confzsLevel:%d", LActor.getActorId(actor), LActor.getZhuanShengLevel(actor), conf.zsLevel))
			LActor.sendTipmsg(actor, string.format(LAN.BOSS.wb006, conf.zsLevel), ttTipmsgWindow)
			return false
		end
		return true
	end,
	[Type.GodTower] = function(actor, conf, boss)
		--判断转生等级是否符合
		if LActor.getZhuanShengLevel(actor) < conf.zsLevel[1] or
			LActor.getZhuanShengLevel(actor) > conf.zsLevel[2] then
			print(string.format("GodTower.checkEnter:req failed. actorId:%d, actorzsLevel:%d, confzsLevel:%d", LActor.getActorId(actor), LActor.getZhuanShengLevel(actor), conf.zsLevel))
			LActor.sendTipmsg(actor, string.format(LAN.BOSS.wb006, conf.zsLevel), ttTipmsgWindow)
			return false
		end
		return true
	end,
}


--检测并进入副本
local function checkEnter(actor, id)
    local conf = bossConf[id]
    if nil == conf then print("worldboss.checkEnter: conf is null, id:"..tostring(id)) return false end

    --怪物被杀死了也不能进去
    local boss = getBossData(id)
    if true == boss.isFinish then 
		print("worldboss.checkEnter:boss.isFinish is true, id:"..id)
		LActor.sendTipmsg(actor, LAN.BOSS.wb002, ttTipmsgWindow)
		return false 
	end
    if 0 == boss.hfuben then print("worldboss.checkEnter:boss.hfuben is 0, id:"..id) return false end

    local data = getStaticData(actor)
    --是否有冷却时间
    if (data.enterFbCd[conf.type] or 0) > System.getNowTime() then 
		local leftTime = (data.enterFbCd[conf.type] or 0)-System.getNowTime()
		print("worldboss.checkEnter:data.enterFbCd("..leftTime..") is not pass, actorId:"..LActor.getActorId(actor)) 
		LActor.sendTipmsg(actor, string.format(LAN.BOSS.wb003,leftTime), ttTipmsgWindow)
		return false 
	end
	
	if baseConf.dayCount[conf.type] > 0 then --不是boss之家才需要检测次数
		checkTimeRecoverCounts(actor) --检测次数之前,先检测
		--进入新的副本，检测次数
		if (data.daily_count[conf.type] or 0) >= baseConf.dayCount[conf.type] then
			print("worldboss.checkEnter:daily_count is not enough. actor:".. LActor.getActorId(actor)..", id:"..id)
			LActor.sendTipmsg(actor, LAN.BOSS.wb004, ttTipmsgWindow)
			return false
		end
	end
	
	--判断VIP等级
	if conf.vip and conf.vip > LActor.getVipLevel(actor) then
		print(string.format("worldboss.checkEnter:req failed. actorId:%d, actorvip:%d, conf.vip:%d", LActor.getActorId(actor), LActor.getVipLevel(actor), conf.vip))
		return false
	end
	
	local cfun = checkEnterType[conf.type]
	if not cfun then
		cfun = DefaultCheckEnter
	end
	
	local check = cfun(actor, conf, boss)
	if not check then return false end
	
	--检测是否够道具
	if baseConf.challengeItem and baseConf.challengeItem[conf.type] and baseConf.challengeItem[conf.type] > 0 then
		if LActor.getItemCount(actor, baseConf.challengeItem[conf.type]) > 0 then
			LActor.costItem(actor, baseConf.challengeItem[conf.type], 1, "boss enter "..conf.type)
		else
			print(LActor.getActorId(actor).." worldboss.checkEnter type("..tostring(conf.type)..") not have item check yuanbao")
			--检测是否够代替的元宝
			if baseConf.challengeItemYb and baseConf.challengeItemYb[conf.type] and baseConf.challengeItemYb[conf.type] > 0 then
				local yb = LActor.getCurrency(actor, NumericType_YuanBao)
				if yb >= baseConf.challengeItemYb[conf.type] then
					LActor.changeYuanBao(actor, 0 - baseConf.challengeItemYb[conf.type], "boss enter "..conf.type)
				else
					print(LActor.getActorId(actor).." worldboss.checkEnter type("..tostring(conf.type)..") not have yuanbao")
					return false
				end
			end
		end
	end
	
    if LActor.isInFuben(actor) then 
		print("worldboss.checkEnter:isInFuben, actorId:"..LActor.getActorId(actor)) 
		LActor.sendTipmsg(actor, LAN.BOSS.wb007, ttTipmsgWindow)
		return false
	end 

	if baseConf.dayCount[conf.type] > 0 then --不是boss之家才需要扣次数
		data.daily_count[conf.type] = (data.daily_count[conf.type] or 0) + 1
		if baseConf.recoverTime[conf.type] > 0 then --有间隔恢复时间
			if data.daily_count[conf.type] == 1 then --刚好等于1,指的是之前是满次数的,这一次最第一次扣次数
				data.count_lrect[conf.type] = System.getNowTime() --记录最后一次刷新时间
			end
		end
	end
	
    data.id = id
	if data.eid then 
		LActor.cancelScriptEvent(actor, data.eid) 
		data.eid = nil
	end
	--进入副本
    enter(actor, id)
    return true
end

local function onReqChallenge(actor, packet)
    local id = LDataPack.readInt(packet)
    --检测进入条件
    local canEnter = checkEnter(actor, id)
    if not canEnter then print("worldboss.onReqChallenge:canEnter is false, id:"..id) return end
end

--参与摇骰子
local function onReqLottery(actor, packet)
    local data = getStaticData(actor)
    local actorId = LActor.getActorId(actor)

    if nil == data.id then print("worldboss.onReqLottery: data.id is nil, actorId:"..actorId) return end

    local gdata = getGlobalData()

    local boss = getBossData(data.id)
    if nil == boss then print("worldboss.onReqLottery:boss is null, id:"..data.id) return end

    if nil == boss.lottery then print("worldboss.onReqLottery: boss.lottery is nil, id:"..data.id) return end
	--判断玩家还在不在副本里面
	if boss.hfuben ~= LActor.getFubenHandle(actor) then
		print("worldboss.onReqLottery: actor is not in boss fuben, id:"..data.id)
		return
	end
	
    if boss.lottery.record[actorId] then print("worldboss.onReqLottery: lottery record is not nil, actorId:" .. actorId) return end

    local roll = math.random(100)
    boss.lottery.record[actorId] = roll

    local npack = LDataPack.allocPacket(actor, p.CMD_Boss, p.sWorldBoss_ReqLottery)
    LDataPack.writeShort(npack, roll)
    LDataPack.flush(npack)

    --如果是最高点数则保存
    if roll > boss.lottery.point then
        boss.lottery.point = roll
        boss.lottery.aid = actorId
        local recordname = LActor.getActorName(LActor.getActorId(actor))

        local ins = instancesystem.getInsByHdl(gdata.bossList[data.id].hfuben)
        if nil == ins then print("worldboss.onReqLottery:nil == ins") return end

        local npack = LDataPack.allocPacket()

        --通知其他玩家最高的骰子信息
        for k, v in pairs(boss.shieldDamageList) do
			local oactor = LActor.getActorById(v)
			if oactor and boss.hfuben == LActor.getFubenHandle(oactor) then
				local npack = LDataPack.allocPacket(oactor,  Protocol.CMD_Boss, Protocol.sWorldBoss_UpdateLottery)
				LDataPack.writeString(npack, recordname or "")
				LDataPack.writeShort(npack, roll)
				LDataPack.flush(npack)
			end
        end
    end
end

local function onReqBuyCd(actor, packet)
    local data = getStaticData(actor)

    --复活时间已到
    if not data.deathMark then 
		print(LActor.getActorId(actor).." worldboss.onReqBuyCd is not die") 
		return 
	end
    
	local conf = bossConf[data.id]
	if not conf then
		print("worldboss.onReqBuyCd: bossConf["..tostring(data.id).."] is nil,  actorId:"..LActor.getActorId(actor)) 
		return
	end
	--先判断有没有复活道具
	if baseConf.rebornItem and LActor.getItemCount(actor, baseConf.rebornItem) > 0 then
		LActor.costItem(actor, baseConf.rebornItem, 1, "worldboss buy cd")
	else
		--判断钱是否足够
		local yb = LActor.getCurrency(actor, NumericType_YuanBao)
		if baseConf.clearCdCost[conf.type] > yb then 
			print("worldboss.onReqBuyCd: clearCdCost > yb, actorId:"..LActor.getActorId(actor)) 
			return 
		end
		print("worldboss.onReqBuyCd:changeYuanBao count=" .. tostring(baseConf.clearCdCost[conf.type]))
		LActor.changeYuanBao(actor, 0 - baseConf.clearCdCost[conf.type], "worldboss buy cd")
	end
    data.rebornCd = nil
    notifyRebornTime(actor)

    --清除死亡标志
    if data.deathMark then
        --随机坐标
        --local x, y = getRandomPoint(data.id)
		local x,y = LActor.getPosition(actor)
        LActor.relive(actor, x, y)
		local boss = getBossData(data.id)
		if boss and boss.monster then
			LActor.setAITarget(actor, boss.monster)
		end
        data.deathMark = nil
		if data.eid then
			LActor.cancelScriptEvent(actor, data.eid)
			data.eid = nil
		end
    end
    --判断是否需要停止AI
    if conf.enterAi then
    	LActor.stopAI(actor)
    end
end

local function onReqChallengeRecord(actor, packet)
	local id = LDataPack.readInt(packet)
	local boss = getBossData(id)
	if boss == nil then
		print("worldboss.onReqChallengeRecord not found id="..id..",aid:"..LActor.getActorId(actor))
		return
	end

	local npack = LDataPack.allocPacket(actor, p.CMD_Boss, p.sWorldBoss_ChallengeRecord)
	if npack == nil then return end
	
	local record = boss.record or {}
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, #record)
	for _, record in ipairs(record) do
		LDataPack.writeInt(npack,record.time)
		LDataPack.writeString(npack,record.name)
		LDataPack.writeDouble(npack,record.power)
	end
	
	LDataPack.flush(npack)
end

local function SendSetClientData(actor)
	local npack = LDataPack.allocPacket(actor, p.CMD_Boss, p.sWorldBoss_SetClientData)
	if npack == nil then return end
	local data = getStaticData(actor)
	if nil == data.clientSet then 
		data.clientSet = {}
		local i = 1
		for id,cfg in ipairs(bossConf) do
			data.clientSet[i] = id
			i = i + 1
		end
	end
	local count = #(data.clientSet)
	LDataPack.writeShort(npack, count)
	for i = 1,count do
		LDataPack.writeShort(npack, data.clientSet[i] or 0)
	end
	LDataPack.flush(npack)
end

--actor事件
local function onLogin(actor)
	SendSetClientData(actor)
end

local function onNewDay(actor)
    resetCounts(actor)
end

local function OnSwitchTargetBefore(actor, fbId, et, et_acotr)
	--[[通过副本ID获取配置
	local bossData = nil
	for _, conf_ in pairs(bossConf) do
		if conf_.fbid == fbId then
			local bossData_ = getBossData(conf_.id)
			if bossData_ and bossData_.hfuben == LActor.getFubenHandle(et_acotr) then 
				bossData = bossData_
				break
			end
		end
	end]]
	if LActor.getActorByEt(LActor.getAITarget(LActor.getLiveByJob(actor))) == et_acotr then return false end
	local data = getStaticData(actor)
    if nil == data.id then 
		print("worldboss.OnSwitchTargetBefore: data.id is nil, actorId:"..LActor.getActorId(actor)) 
		return false 
	end
	--自由PK模式可以随便打
	local pkm = getPkMode(bossConf[data.id])
	if pkm == PkMode.free then
		return true
	elseif pkm == PkMode.belong then
		--非自由PK模式
		local bossData = getBossData(data.id)
		if not bossData then  print("worldboss.OnSwitchTargetBefore not bossData") return true end
		if bossData.hfuben ~= LActor.getFubenHandle(et_acotr) then
			print("worldboss.OnSwitchTargetBefore: actor not in fuben, actorId:"..LActor.getActorId(actor)) 
			return false
		end
		
		if not bossData.belong then  print("worldboss.OnSwitchTargetBefore not bossData.belong = "..tostring(bossData.belong)) return false  end
		--可以选归属者作为目标
		if LActor.getActorId(bossData.belong) == LActor.getActorId(et_acotr) then 
			print("worldboss.OnSwitchTargetBefore is belong")
			LActor.sendTipmsg(actor, string.format(LAN.BOSS.wb008,LActor.getName(et_acotr)), ttScreenCenter)
			LActor.sendTipmsg(et_acotr, string.format(LAN.BOSS.wb009,LActor.getName(actor)), ttScreenCenter)
			return true
		end
		--如果我是归属者,可以选打过我的人作为目标
		if LActor.getActorId(bossData.belong) == LActor.getActorId(actor) then
			--判断et_actor是否打过我
			if LActor.getCamp(et_acotr) == WorldBossCampType_Attack then
				LActor.sendTipmsg(actor, string.format(LAN.BOSS.wb010,LActor.getName(et_acotr)), ttScreenCenter)
				LActor.sendTipmsg(et_acotr, string.format(LAN.BOSS.wb009,LActor.getName(actor)), ttScreenCenter)
				return true
			end
		end
	end
	return false
end

--BOSS死亡时候的处理
local function onMonsterDie(ins, mon, killerHdl)
    local bossId = ins.data.bossid
    local monid = Fuben.getMonsterId(mon)
    if monid ~= bossId then 
		print("worldboss.onMonsterDie:monid("..tostring(monid)..") ~= bossId("..tostring(bossId).."), id:"..ins.data.id)
		return
	end
	ins.data.boss_die_x,ins.data.boss_die_y = LActor.getPosition(mon) -- 获取死亡时候,boss所在位置;用于掉落位置
	ins:win()
	--主城玩法监听boss死亡
	citysystem.onOutsideBossDie(monid)
end

--[[角色死亡时候的处理
local function onRoleDie(ins,role,killer_hdl)
	local bossData = getBossData(ins.data.id)
	--没有归属者
	if not bossData.belong then return end
	local actor = LActor.getActor(role)
	--玩家不是归属者
	if LActor.getActorId(bossData.belong) ~= LActor.getActorId(actor) then return end
	SendBossTargetRole(nil, bossData)
end
]]

local function GetCanBuyCount(vipLv, boss_type)
	local vipCfg = VipConfig[vipLv]
	if not vipCfg then return nil end
	if boss_type == Type.worldBoss then
		return vipCfg.boss2buy
	elseif boss_type == Type.publicBoss then
		return vipCfg.boss1buy
	end
	return nil
end

--购买挑战次数
local function doBuyDayCount(actor, boss_type)
	local data = getStaticData(actor)
	if (data.daily_count[boss_type] or 0) <= 0 then
		print(LActor.getActorId(actor).." worldboss.onBuyDayCount boss_type:"..boss_type.." daily_count is 0")
		return
	end
	local vipLv = LActor.getVipLevel(actor)
	local canBuyCount = GetCanBuyCount(vipLv, boss_type)
	if not canBuyCount or canBuyCount <= 0 then
		print(LActor.getActorId(actor).." worldboss.onBuyDayCount boss_type:"..boss_type.." vipLv:"..vipLv.." not have buy count cfg")
		return
	end
	if (data.buy_count[boss_type] or 0) >= canBuyCount then
		print(LActor.getActorId(actor).." worldboss.onBuyDayCount boss_type:"..boss_type.." vipLv:"..vipLv.." is buy max count")
		return
	end
	local price = baseConf.buyCountPrice[boss_type]
	if not price then 
		print(LActor.getActorId(actor).." worldboss.onBuyDayCount boss_type:"..boss_type.." not price config")
		return
	end
	--判断钱是否足够
	if price > 0 then
		local yb = LActor.getCurrency(actor, NumericType_YuanBao)
		if price > yb then 
			print(LActor.getActorId(actor).." worldboss.onBuyDayCount boss_type:"..boss_type.." price("..price..") > yb("..yb..")")
			return 
		end
		LActor.changeYuanBao(actor, 0 - price, "worldboss buy count")
	end
	data.daily_count[boss_type] = data.daily_count[boss_type] - 1
	if data.daily_count[boss_type] <= 0 and data.count_lrect[boss_type] then
		data.count_lrect[boss_type] = System.getNowTime() --记录最后一次刷新时间
	end
	data.buy_count[boss_type] = (data.buy_count[boss_type] or 0) + 1
	sendBossViewData(actor, boss_type)
end

local function onBuyDayCount(actor, packet)
	local boss_type = LDataPack.readByte(packet)
	doBuyDayCount(actor, boss_type)
end

--取消归属者
local function onCancelBelong(actor, packet)
	local data = getStaticData(actor)
    if nil == data.id then 
		print("worldboss.onCancelBelong: data.id is nil, actorId:"..LActor.getActorId(actor)) 
		return 
	end
	local conf = bossConf[data.id]
	if not conf then
		print("worldboss.onCancelBelong: conf is nil, data.id:"..data.id.." actorId:"..LActor.getActorId(actor)) 
		return
	end
	local fbhandle = LActor.getFubenHandle(actor)
	local ins = instancesystem.getInsByHdl(fbhandle)
	if not ins then
		print("worldboss.onCancelBelong: ins is nil, data.id:"..data.id.." actorId:"..LActor.getActorId(actor)) 
		return
	end
	if (baseConf.belongCount[conf.type] or 0) <= 0 then
		print("worldboss.onCancelBelong: can not cancel belong, data.id:"..data.id.." actorId:"..LActor.getActorId(actor)) 
		return
	end
	clearBelongInfo(ins, actor)
	LActor.stopAI(actor)
end

--每个小时调用一次的函数
local function WorldBossOnHour()
	print("do WorldBossOnHour~")
	local now_t = System.getNowTime()
	local refHomeBoss = {}
	local refBossRecord = {}
	for _,id in ipairs(intRefBossId) do
		local conf = bossConf[id]
		local boss = getBossData(id)
		if boss and boss.refTime <= now_t then
			boss.refTime = boss.refTime + conf.intervalTime * 3600
			if boss.monster then
				LActor.DestroyEntity(boss.monster)
			end
			if not boss.hfuben then
				initBossDataFb(conf)
			end
			refreshTimer(id)
			if homeBossLvCfg[id] then
				refHomeBoss[homeBossLvCfg[id].id] = 1
			else
				table.insert(refBossRecord, {type=conf.type, id=id})
			end
		end
	end
	for k,_ in pairs(refHomeBoss) do
		sendBossRefresh(Type.homeBoss, k)
	end
	for _,val in ipairs(refBossRecord) do
		sendBossRefresh(val.type, val.id)
	end
end
_G.WorldBossOnHour = WorldBossOnHour

local function onSetClientData(actor, packet)
	local count = LDataPack.readShort(packet)
	if count > #bossConf then 
		print("worldboss.onSetClientData: count("..count..") > #bossConf="..(#bossConf))
		return 
	end
	local data = getStaticData(actor)
	data.clientSet = {}
	for i = 1,count do
		local id = LDataPack.readShort(packet)
		data.clientSet[i] = id
	end
end

--获取指定类型的使用次数
function GetDailyCount(actor, type)
    local data = getStaticData(actor)
    return data.daily_count[type] or 0
end

--设置指定类型的使用次数
function SetDailyCount(actor, type, count)
	local data = getStaticData(actor)
	data.daily_count[type] = count
end

function actorChangeName(actor, name)
    local targetId = LActor.getActorId(actor)
	for id, boss in pairs(bossConf) do
        local data = getBossData(boss.id)
        if data and data.hfuben then
	        local ins = instancesystem.getInsByHdl(data.hfuben)
	        if ins and ins.boss_info and ins.boss_info.damagelist then
				if ins.boss_info.damagelist[targetId] then
					ins.boss_info.damagelist[targetId].name = name
				end
	        end
	    end
    end
end

local function onZhuansheng(actor, zhuanshengLevel)
	local cfg = BossBlessConfig[zhuanshengLevel]
	if not cfg then return end
	if not cfg.init then return end
	changeBless(actor, cfg.init)
end

--启动初始化
local function initGlobalData()
	if not System.isCommSrv() then return end
    --副本事件
	local isRegFbId = {}
    for _, conf in pairs(bossConf) do
		if not isRegFbId[conf.fbid] then  
			isRegFbId[conf.fbid] = true
			insevent.registerInstanceWin(conf.fbid, onWin)
			insevent.registerInstanceLose(conf.fbid, onLose)
			insevent.registerInstanceEnter(conf.fbid, onEnterFb)
			insevent.registerInstanceMonsterDamage(conf.fbid, onBossDamage)
			insevent.registerInstanceExit(conf.fbid, onExitFb)
			insevent.registerInstanceOffline(conf.fbid, onOffline)
			insevent.registerInstanceActorDie(conf.fbid, onActorDie)
			--insevent.regRoleDie(conf.fbid, onRoleDie)
			role.registerSwitchTargetBeforeFunc(conf.fbid, OnSwitchTargetBefore)
			insevent.registerInstanceMonsterDie(conf.fbid, onMonsterDie)
		end
    end
	isRegFbId = nil

    --消息处理
    netmsgdispatcher.reg(p.CMD_Boss, p.cWorldBoss_ReqBossViewInfo, onReqBossList) --获取boss列表数据
    netmsgdispatcher.reg(p.CMD_Boss, p.cWorldBoss_ChallengeBoss , onReqChallenge) --请求挑战
    netmsgdispatcher.reg(p.CMD_Boss, p.cWorldBoss_ReqLottery, onReqLottery) --请求摇骰子
    netmsgdispatcher.reg(p.CMD_Boss, p.cWorldBoss_BuyCd, onReqBuyCd) --花钱复活
	netmsgdispatcher.reg(p.CMD_Boss, p.cWorldBoss_ChallengeRecord, onReqChallengeRecord) --获取挑战记录
	netmsgdispatcher.reg(p.CMD_Boss, p.cWorldBoss_SetClientData, onSetClientData)
	netmsgdispatcher.reg(p.CMD_Boss, p.cWorldBoss_BuyDayCount, onBuyDayCount) --购买挑战次数
	netmsgdispatcher.reg(p.CMD_Boss, p.cWorldBoss_CancelBelong, onCancelBelong) --取消归属者

    --actor事件
    actorevent.reg(aeNewDayArrive, onNewDay)
    actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeZhuansheng, onZhuansheng)

    --初始化记录
    local count = 0
    if nil == worldBossData.bossList then worldBossData.bossList = {} end
    for id, boss in pairs(bossConf) do
        if nil == getBossData(boss.id) then
			initBossDataFb(boss)
			refreshTimer(id)
        end
		if not bossTypeId[boss.type] then bossTypeId[boss.type] = {} end
		table.insert(bossTypeId[boss.type], id)
		if boss.intervalTime and boss.intervalTime > 0 then
			table.insert(intRefBossId, id)
		end
    end
	
	for _,cfg in pairs(BossHomeConfig) do
		for _,id in ipairs(cfg.boss) do 
			homeBossLvCfg[id] = cfg
		end
	end
end

table.insert(InitFnTable, initGlobalData)


function worldBossGmHandle(actor, arg)
	local param = arg[1]
	if param == "cd" then
        local data = getStaticData(actor)
		data.enterFbCd = {}
		data.daily_count = {}
	elseif param == "rsf" then
		local module_name = "systems.boss.worldboss"
		package.loaded[module_name] = nil
		require (module_name)		
	elseif param == "en" then
		checkEnter(actor, tonumber(arg[2]))
	elseif param == "rb" then
		local boss = getBossData(tonumber(arg[2]))
		if not boss then return false end
		if not boss.rbeid then return false end
		LActor.cancelScriptEvent(nil, boss.rbeid)
		refreshBoss(nil, boss.id)
	elseif param == "st" then
		local gtype = tonumber(arg[2])
		for _,id in ipairs(bossTypeId[gtype] or {}) do
			local cfg = bossConf[id]
			local boss = getBossData(id)
			local type_name = {"世界Boss","全民Boss","Boss之家"}
			local status_name = {"活着","已杀"}
			local str = type_name[cfg.type]..",".."id:"..id..","
			str = str..status_name[boss.isFinish and 2 or 1]..",下次刷新或复活时间:"..(boss.refTime or 0)
			LActor.sendTipmsg(actor,str,ttTipmsgWindow)
		end
	elseif param == "bc" then
		doBuyDayCount(actor, tonumber(arg[2]))
	elseif param == 'bl' then
		changeBless(actor, tonumber(arg[2]))
	elseif param == "cb" then
		local data = getStaticData(actor)
		print(LActor.getActorId(actor).." bless:"..(data.bless or 0))
		LActor.sendTipmsg(actor, " bless:"..(data.bless or 0), ttDialog)
	elseif param == "c" then
		onCancelBelong(actor, nil)
	elseif param == "cbc" then
		local data = getStaticData(actor)
		local boss_type = tonumber(arg[2])
		local count = data.can_belong_count and data.can_belong_count[boss_type] or (baseConf.belongCount[boss_type] or 0)
		LActor.sendTipmsg(actor, " can_belong_count:"..count, ttDialog)
	else
		LActor.sendTipmsg(actor, [[
		命令使用格式:
		@worldboss cd --清除挑战CD
		@worldboss rsf --刷新worldboss脚本代码
		@worldboss en [id] --进入挑战指定ID的boss
		@worldboss rb [id] --复活指定ID的boss
		@worldboss st [Boss类型] --查询该类型刷新状态
		@worldboss bc [Boss类型] --购买挑战次数
		@worldboss bl [数量] --增加祝福值
		@worldboss cb  --查看我的祝福值
		@worldboss c  --放弃归属者
		]], ttDialog)
    end
	return true
end
