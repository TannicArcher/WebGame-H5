module("citysystem", package.seeall)

cityFubenHandle = cityFubenHandle --副本handle
cityFubenIns = cityFubenIns --副本的ins实例
cityBelong = cityBelong --归属者
cityBoss = cityBoss --副本里面的boss实体
cityBossCfgId = cityBossCfgId --当前打boss的配置的id索引
cityAllImageAid = cityAllImageAid or {} --在场景里面的镜像玩家ID {[玩家ID]=>实际那个人的handle}
cityExitAddImageAid = cityExitAddImageAid or {} --退出场景需要增加一个玩家镜像的玩家
cityShield = cityShield or {}
--[[护盾
	shield  护盾id
	curShield 当前护盾id
	nextShield
]]
cityBossIdCfg = {}

--[[获取玩家缓存变量{
	reid = 玩家安全区定时奖励eid
}]]
local function getDynamicData(actor)
    local var = LActor.getDynamicVar(actor)
    if nil == var.citysystem then var.citysystem = {} end
    return var.citysystem
end

--[[玩家静态变量
	enterCd = 进入CD
]]
local function getStaticData(actor)
    local var = LActor.getStaticVar(actor)
    if nil == var.citysystem then var.citysystem = {} end
    return var.citysystem
end

--获取全局静态变量
local function getGlobalData()
	local var = System.getStaticVar()
	if var == nil then 
		return nil
	end
	if var.citysystem == nil then 
		var.citysystem = {}
	end
	return var.citysystem
	--[[ 结构定义
		{
			monsterDieCount[怪物ID]=死亡次数
			monsterResCount[怪物ID]=刷出次数
			monsterResTime[怪物ID]=预估的下次刷新时间
		}
	]]
end

--发送主城CD
local function sendCityEnterCd(actor)
	local var = getStaticData(actor)
	local leftTime = (var.enterCd or 0) - System.getNowTime()
	if leftTime < 0 then leftTime = 0 end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_City, Protocol.sCityCmd_EnterCd)
	LDataPack.writeInt(npack, leftTime)
	LDataPack.flush(npack)
end

--获取下一个护盾
local function getNextShield(hp)
    if nil == hp then hp = 101 end

    local conf = CityBossConfig[cityBossCfgId]
    if nil == conf then print("citysystem.getNextShield is null, id:"..cityBossCfgId) return nil end
	for _, s in ipairs(conf.shield) do
        if s.hp < hp then return s end
    end
	return nil
end

--发送当前主城boss
local function sendCurBoss(actor)
	local npack = nil
	if actor then
		npack = LDataPack.allocPacket(actor, Protocol.CMD_City, Protocol.sCityCmd_CurBoss)
	else
		npack = LDataPack.allocBroadcastPacket(Protocol.CMD_City, Protocol.sCityCmd_CurBoss)
	end
	if not npack then return end
	LDataPack.writeInt(npack, cityBoss and LActor.getId(cityBoss) or 0)
	LDataPack.writeDouble(npack, cityBoss and LActor.getHandle(cityBoss) or 0)
	if actor then
		LDataPack.flush(npack)
	else
		System.broadcastData(npack)
	end	
end

--获取需要击杀的个数
local function getNeedKillCount(cfg)
	local gdata = getGlobalData()
	if not gdata.monsterResCount then gdata.monsterResCount = {} end
	local resCount = gdata.monsterResCount[cfg.killBossId] or 0
	local count = cfg.killCount[resCount+1]
	if not count then
		return cfg.killCount[#cfg.killCount]
	end
	return count
end

--发送boss进度
local function sendBossProgress(actor, bossId)
	local npack = nil
	if actor then
		npack = LDataPack.allocPacket(actor, Protocol.CMD_City, Protocol.sCityCmd_BossProgress)
	else
		npack = LDataPack.allocBroadcastPacket(Protocol.CMD_City, Protocol.sCityCmd_BossProgress)
	end
	if not npack then return end

	local gdata = getGlobalData()
	if not gdata.monsterDieCount then gdata.monsterDieCount = {} end
	if not gdata.monsterResCount then gdata.monsterResCount = {} end
	if not gdata.monsterResTime then gdata.monsterResTime = {} end

	if bossId then
		LDataPack.writeShort(npack, 1)
		LDataPack.writeInt(npack, bossId)
		LDataPack.writeInt(npack, gdata.monsterDieCount[bossId] or 0)
		LDataPack.writeInt(npack, gdata.monsterResCount[bossId] or 0)
		LDataPack.writeInt(npack, gdata.monsterResTime[bossId] or 0)
	else
		LDataPack.writeShort(npack, #CityBossConfig)
		for _,v in ipairs(CityBossConfig) do
			LDataPack.writeInt(npack, v.killBossId)
			LDataPack.writeInt(npack, gdata.monsterDieCount[v.killBossId] or 0)
			LDataPack.writeInt(npack, gdata.monsterResCount[v.killBossId] or 0)
			LDataPack.writeInt(npack, gdata.monsterResTime[v.killBossId] or 0)
		end
	end

	if actor then
		LDataPack.flush(npack)
	else
		System.broadcastData(npack)
	end
end

--检测是否需要刷出boss
local function checkNeedCreateBoss(cfg, killCount)
	local needCount = getNeedKillCount(cfg)
	if needCount <= killCount then
	--if cfg.killCount <= killCount then
		--刷出一只boss
		if cityFubenHandle and not cityBoss then
			if cityFubenIns then
				print("citysystem.checkNeedCreateBoss createMonster:"..cfg.bossId)
				if cityShield.shieldEid then
					LActor.cancelScriptEvent(nil, cityShield.shieldEid)
					cityShield.shieldEid = nil
				end
				cityShield = {}
				cityBoss = Fuben.createMonster(cityFubenIns.scene_list[1], cfg.bossId, cfg.point.x, cfg.point.y)
				cityBossCfgId = cfg.idx
				local gdata = getGlobalData()
				if not gdata.monsterDieCount then gdata.monsterDieCount = {} end
				gdata.monsterDieCount[cfg.killBossId] = (gdata.monsterDieCount[cfg.killBossId] or 0) - needCount
				if gdata.monsterDieCount[cfg.killBossId] <= 0 then gdata.monsterDieCount[cfg.killBossId] = nil end
				--广播全服主城出现boss
				sendCurBoss()
				sendBossProgress(nil, cfg.killBossId)
				--初始化护盾
				cityShield.nextShield = getNextShield(nil)
				--公告
				if cfg.noticeId then
					noticemanager.broadCastNotice(cfg.noticeId)
				end
			else
				print("citysystem.checkNeedCreateBoss is no fuben ins")
			end
		else
			print("citysystem.checkNeedCreateBoss is no fuben handle or have cityBoss")
		end
	--else
		--print("citysystem.checkNeedCreateBoss cfg.killcount("..cfg.killCount..") > killcount("..killCount..") createMonster:"..cfg.bossId)
	end
end

--野外boss死亡的时候
function onOutsideBossDie(bossId)
	if (CityBaseConfig.bossOpenSrvDay or 0) > System.getOpenServerDay() then
		return
	end
	local cfg = cityBossIdCfg[bossId]
	if not cfg then
		return
	end
	local gdata = getGlobalData()
	if not gdata.monsterDieCount then gdata.monsterDieCount = {} end
	gdata.monsterDieCount[bossId] = (gdata.monsterDieCount[bossId] or 0) + 1
	if not gdata.monsterResTime then gdata.monsterResTime = {} end
	gdata.monsterResTime[bossId] = System.getNowTime() + (getNeedKillCount(cfg)-gdata.monsterDieCount[bossId]) * (cfg.reTime or 0)
	checkNeedCreateBoss(cfg, gdata.monsterDieCount[bossId])
	--发送进度
	sendBossProgress(nil, bossId)
end

--归属者变更
local function BelongChange(oldBelong, newBelong)
	cityBelong = newBelong
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, Protocol.CMD_City)
	LDataPack.writeByte(npack, Protocol.sCityCmd_Belong)
    LDataPack.writeDouble(npack, oldBelong and LActor.getHandle(oldBelong) or 0)
    LDataPack.writeDouble(npack, newBelong and LActor.getHandle(newBelong) or 0)
	Fuben.sendData(cityFubenHandle, npack)

end

--获取随机出生点
local function getRandomPoint()
	local point = CityBaseConfig.enterPoint[math.random(1,#CityBaseConfig.enterPoint)]
	return point.x, point.y
end

--请求进入主城
local function reqEnterFuben(actor, packet)
	if not cityFubenHandle then 
		print("citysystem.reqEnterFuben cityFubenHandle is nil")
		return
	end
	local var = getStaticData(actor)
	if (var.enterCd or 0) > System.getNowTime() then
		print("citysystem.reqEnterFuben have enterCd")
		return
	end
	--随机坐标
    local x, y = getRandomPoint()
    LActor.enterFuBen(actor, cityFubenHandle, 0, x, y)
end

--请求停止AI
local function reqStopAi(actor, packet)
	LActor.stopAI(actor)
end

--切换目标前
local function OnSwitchTargetBefore(actor, fbId, et, et_acotr)
	if et_acotr then
		if LActor.InSafeArea(et_acotr) then
			print("citysystem.OnSwitchTargetBefore et_acotr in safearea")
			return false
		end
	end
	return true
end

--通知复活时间
local function notifyRebornTime(actor, killerHdl)
    local cache = getDynamicData(actor)
    local rebornCd = (cache.rebornCd or 0) - System.getNowTime()
    if rebornCd < 0 then rebornCd = 0 end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_City, Protocol.sCityCmd_RebornTime)
    LDataPack.writeShort(npack, rebornCd)
	LDataPack.writeDouble(npack, killerHdl or 0)
    LDataPack.flush(npack)
end

--玩家复活
local function reborn(actor, rebornCd)
    local cache = getDynamicData(actor)
    if cache.rebornCd ~= rebornCd then 
    	print(LActor.getActorId(actor).." citysystem.reborn:cache.rebornCd ~= rebornCd") 
    	return
    end
    notifyRebornTime(actor)
	local x, y = getRandomPoint()
    LActor.relive(actor, x, y)
    --设置阵营
	LActor.setCamp(actor, LActor.getActorId(actor))
	LActor.stopAI(actor)
end

--玩家死亡
local function onActorDie(ins, actor, killerHdl)
	--杀人的人停止AI
	local killer_actor = nil
	local et = LActor.getEntity(killerHdl)
    if et then 
		killer_actor = LActor.getActor(et)
		if killer_actor then
			--杀人者的目标的玩家不是被杀的玩家,不停AI
			local TargetActor = LActor.getActorByEt(LActor.getAITarget(et))
			if TargetActor == actor then
				LActor.stopAI(killer_actor)
			end
		else
			print("citysystem.onActorDie not killer_actor")
		end
	else
		print("citysystem.onActorDie not et")
	end
	--改变归属者
	if actor == cityBelong then
		if cityFubenHandle == LActor.getFubenHandle(killer_actor) then
			BelongChange(actor, killer_actor)
		else
			BelongChange(actor, nil)
		end
	end
	-- 计时器自动复活
	local cache = getDynamicData(actor)
	local rebornCd = System.getNowTime() + (CityBaseConfig.rebornCd or 0)
    cache.eid = LActor.postScriptEventLite(actor, (CityBaseConfig.rebornCd or 0) * 1000, reborn, rebornCd)
    cache.rebornCd = rebornCd

    notifyRebornTime(actor, killerHdl)
end

--花钱复活
local function onReqBuyReborn(actor, packet)
    local cache = getDynamicData(actor)
    --复活时间已到
    if (cache.rebornCd or 0) < System.getNowTime() then 
		print("citysystem.onReqBuyReborn: rebornCd < now,  actorId:"..LActor.getActorId(actor)) 
		return 
	end
	--先判断有没有复活道具
	if CityBaseConfig.rebornItem and LActor.getItemCount(actor, CityBaseConfig.rebornItem) > 0 then
		LActor.costItem(actor, CityBaseConfig.rebornItem, 1, "citysystem buy cd")
	else
		--判断钱是否足够
		local yb = LActor.getCurrency(actor, NumericType_YuanBao)
		if CityBaseConfig.BuyRebornCost > yb then 
			print("citysystem.onReqBuyReborn: BuyRebornCost > yb, actorId:"..LActor.getActorId(actor))
			return 
		end
		--扣元宝
		LActor.changeYuanBao(actor, 0 - CityBaseConfig.BuyRebornCost, "citysystem buy reborn")
	end
    cache.rebornCd = nil
	--通知复活时间
    notifyRebornTime(actor)
	--复活
	local x,y = LActor.getPosition(actor)
	LActor.relive(actor, x, y)
	--设置阵营
	LActor.setCamp(actor, LActor.getActorId(actor))
	LActor.stopAI(actor)
end

--获得定时奖励
local function GiveHaveReward(actor, type)
	--计算经验和金币的倍率
	local expex = specialattribute.get(actor,specialattribute.expEx)
	local goldex = specialattribute.get(actor,specialattribute.goldEx)
	if expex ~= 0 then expex = expex / 10000 end
	if goldex ~= 0 then	goldex = goldex / 10000	end
	--获取玩家数据
	local data = chapter.getStaticData(actor)
	--获取当前等级配置
	local conf = ChaptersConfig[data.level]
	if conf == nil then
		conf = ChaptersConfig[data.level - 1]
		if conf == nil then
			print("citysystem.GiveHaveReward config not found")
		end
	end
	--计算掉落
	local getExp = 0 --应该得到的经验
	local getRet = {} --应该得到的掉落
	if type == chapter.expTime then --拿经验的
		getExp = conf.waveExp * (1 + expex)
	elseif type == chapter.eliteDropTime then --这个是精英怪
		getRet = drop.dropGroup(conf.eliteDropId)
	elseif type == chapter.dropTime then --拿普通掉落的
		getRet = drop.dropGroup(conf.monsterDropId)
	end
	--发经验
	if getExp ~= 0 then
		LActor.addExp(actor, getExp, "city time", true)
	end
	--发奖励
	if #getRet > 0 then
		if not LActor.canGiveAwards(actor, getRet) then LActor.sendTipWithId(actor, 1) end
		LActor.giveAwards(actor, getRet, "city time")
	end
end

--定时器到了
local function onScriptTimeOn(actor, type)
	if cityFubenHandle ~= LActor.getFubenHandle(actor) then
		if actor == cityBelong then
			BelongChange(actor, nil)
		end
		return
	end
	--如果在安全区就去掉归属者
	if LActor.InSafeArea(actor) then
		if actor == cityBelong then
			BelongChange(actor, nil)
		end
	end
	--先清除eid
	local cache = getDynamicData(actor)
	if type == chapter.expTime then cache.expEid = nil end
	if type == chapter.dropTime then cache.dropEid = nil end
	if type == chapter.eliteDropTime then cache.eliteEid = nil end
	--发送掉落给客户端
	GiveHaveReward(actor, type)
	--再次注册时间定时器
	local data = chapter.getStaticData(actor)
	--获取当前等级配置
	local conf = ChaptersConfig[data.level]
	if conf == nil then
		conf = ChaptersConfig[data.level - 1]
		if conf == nil then
			return
		end
	end
	--注册定时掉落定时器
	if type == chapter.expTime then 
		cache.expEid = LActor.postScriptEventLite(actor, conf.expTime * 1000, onScriptTimeOn, chapter.expTime) 
	end
	if type == chapter.dropTime then
		cache.dropEid = LActor.postScriptEventLite(actor, conf.dropTime * 1000, onScriptTimeOn, chapter.dropTime) 
	end
	if type == chapter.eliteDropTime then
		cache.eliteEid = LActor.postScriptEventLite(actor, conf.eliteDropTime * 1000, onScriptTimeOn, chapter.eliteDropTime) 
	end
end

--注册定时掉落定时器
local function regScriptTimer(actor)
	if LActor.isImage(actor) then return end
	local data = chapter.getStaticData(actor)
	--获取当前等级配置
	local conf = ChaptersConfig[data.level]
	if conf == nil then
		conf = ChaptersConfig[data.level - 1]
		if conf == nil then
			return
		end
	end
	local cache = getDynamicData(actor)
	--注册定时掉落定时器
	if conf.expTime then 
		cache.expEid = LActor.postScriptEventLite(actor, conf.expTime * 1000, onScriptTimeOn, chapter.expTime) 
	end
	if conf.dropTime then 
		cache.dropEid = LActor.postScriptEventLite(actor, conf.dropTime * 1000, onScriptTimeOn, chapter.dropTime) 
	end
	if conf.eliteDropTime then 
		cache.eliteEid = LActor.postScriptEventLite(actor, conf.eliteDropTime * 1000, onScriptTimeOn, chapter.eliteDropTime) 
	end
end

--停止所有机器人AI
local function stopAllRobotAi()
	local robots = Fuben.getAllCloneRole(cityFubenHandle)
	if robots ~= nil then
		for i = 1,#robots do 
			LActor.setAIPassivity(robots[i], true)
			LActor.setAITargetNull(robots[i])
		end
	end
end

--重刷机器人
local function RefreshAllRobot()
	if (CityBaseConfig.robotOpenSrvDay or 0) > System.getOpenServerDay() then
		return
	end
	cityAllImageAid = {}
	Fuben.clearAllCloneRole(cityFubenIns.scene_list[1])
	--获取随机数量
	local rnum = math.random(CityBaseConfig.robotNum[1], CityBaseConfig.robotNum[2])
	--遍历全服玩家
	if rnum > 0 then
		local players = System.getAllActorList()
		if players and #players > 0 then  
			for _,player in ipairs(players) do
				local plv = LActor.getLevel(player)
				if plv >= CityBaseConfig.enterLv and LActor.getFubenHandle(player) ~= cityFubenHandle then
					--创建一个玩家
					local paId = LActor.getActorId(player)
					local x, y = getRandomPoint()
					LActor.createRoldClone(paId, cityFubenIns.scene_list[1], x, y)
					cityAllImageAid[paId] = LActor.getHandle(player)
					rnum = rnum - 1
					if rnum <= 0 then
						break
					end
				end
			end
		end
	end
	stopAllRobotAi()
end

--刷一个机器人
local function RefreshOneRobot(aid)
	if (CityBaseConfig.robotOpenSrvDay or 0) > System.getOpenServerDay() then
		return
	end
	--遍历全服玩家
	local players = System.getAllActorList()
	if players and #players > 0 then  
		for _,player in ipairs(players) do
			local plv = LActor.getLevel(player)
			local paId = LActor.getActorId(player)
			if plv >= CityBaseConfig.enterLv and 
				LActor.getFubenHandle(player) ~= cityFubenHandle and
				not cityAllImageAid[paId] and paId ~= aid then
				--创建一个玩家
				local x, y = getRandomPoint()
				LActor.createRoldClone(paId, cityFubenIns.scene_list[1], x, y)
				cityAllImageAid[paId] = LActor.getHandle(player)
				break
			end
		end
	end
	stopAllRobotAi()
end

--通知护盾信息
local function notifyShield(nowShield)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, Protocol.CMD_City)
    LDataPack.writeByte(npack, Protocol.sCityCmd_BossShield)

    LDataPack.writeInt(npack, nowShield)
	LDataPack.writeInt(npack, cityShield.curShield and cityShield.curShield.shield or 0)
    Fuben.sendData(cityFubenHandle, npack)
end

--进入副本的时候
local function onEnterFb(ins, actor)
	LActor.setCamp(actor, LActor.getActorId(actor))
	LActor.stopAI(actor)
	--注册定时奖励定时器
	local cache = getDynamicData(actor)
	if cache.expEid then LActor.cancelScriptEvent(actor, cache.expEid) end
	if cache.dropEid then LActor.cancelScriptEvent(actor, cache.dropEid) end
	if cache.eliteEid then LActor.cancelScriptEvent(actor, cache.eliteEid) end
	regScriptTimer(actor)

	--初始化归属者
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_City, Protocol.sCityCmd_Belong)
    LDataPack.writeDouble(npack, 0)
    LDataPack.writeDouble(npack, cityBelong and LActor.getHandle(cityBelong) or 0)
	LDataPack.flush(npack)
	
	--检测是否需要清除镜像
	local aid = LActor.getActorId(actor)
	if cityAllImageAid[aid] then
		cityAllImageAid[aid] = nil
		Fuben.clearCloneRoleById(cityFubenIns.scene_list[1], aid)
		cityExitAddImageAid[aid] = actor
	end
	
	--通知护盾信息
	if cityShield.curShield then
		local nowShield = cityShield.shield - System.getNowTime()
		if nowShield < 0 then nowShield = 0 end
		--护盾信息
		notifyShield(nowShield)
    end
end

--退出的处理
local function onExitFb(ins, actor)
	--去除定时奖励定时器
	local cache = getDynamicData(actor)
	if cache.expEid then 
		LActor.cancelScriptEvent(actor, cache.expEid)
		cache.expEid = nil
	end
	if cache.dropEid then 
		LActor.cancelScriptEvent(actor, cache.dropEid)
		cache.dropEid = nil
	end
	if cache.eliteEid then
		LActor.cancelScriptEvent(actor, cache.eliteEid)
		cache.eliteEid = nil
	end
	--归属者退出副本
	if actor == cityBelong then
		BelongChange(actor, nil)
	end
	--退出把AI恢复
	local role_count = LActor.getRoleCount(actor)
	for i = 0,role_count - 1 do
		local role = LActor.getRole(actor,i)
		LActor.setAIPassivity(role, false)
	end	
	--删除复活定时器
    cache.deathMark = nil
	if cache.eid then
		LActor.cancelScriptEvent(actor, cache.eid)
		cache.eid = nil
	end
	--刷一个机器人
	local aid = LActor.getActorId(actor)
	if cityExitAddImageAid[aid] then
		cityExitAddImageAid[aid] = nil
		RefreshOneRobot(aid)
	end
	--记录cd
	local var = getStaticData(actor)
	var.enterCd = System.getNowTime() + CityBaseConfig.enterCd
	--发送主城CD
	sendCityEnterCd(actor)
end

--发放归属者奖励
local function SetBelongReward(rewardInfo)
	print("citysystem.SetBelongReward")
	if not cityBelong then return end
	local cfg = CityBossConfig[cityBossCfgId]
	if not cfg then 
		print("citysystem.SendBelongReward no idx:"..tostring(cityBossCfgId).." cfg")
		return
	end
	local belongId = LActor.getActorId(cityBelong)
	if not rewardInfo[belongId] then rewardInfo[belongId] = {} end
	local rewards = drop.dropGroup(cfg.belongReward)
	table.insert(rewardInfo[belongId], rewards)
	if LActor.canGiveAwards(cityBelong, rewards) then
		LActor.giveAwards(cityBelong, rewards, "city belong")
	else
		local mailData = {head=cfg.belongRewardMailTitle, context=cfg.belongRewardMailText, tAwardList=rewards }
		mailsystem.sendMailById(belongId, mailData)
	end
end

--发参与奖励
local function SetJoinReward(rewardInfo, allJoinId)
	print("citysystem.SetJoinReward")
	local cfg = CityBossConfig[cityBossCfgId]
	if not cfg then 
		print("citysystem.SetJoinReward no idx:"..tostring(cityBossCfgId).." cfg")
		return
	end
	if not cityFubenIns.boss_info then
		print("citysystem.SetJoinReward no boss_info")
		return
	end
	if not cityFubenIns.boss_info.damagelist then
		print("citysystem.SetJoinReward no boss_info.damagelist")
		return
	end
	local belongId = 0
	if cityBelong then
		belongId = LActor.getActorId(cityBelong)
	end
	--遍历伤害排行,拿参与奖
	for aid, data in pairs(cityFubenIns.boss_info.damagelist) do
		if aid ~= belongId then --归属者不发参与奖励
			table.insert(allJoinId, aid)
			if not rewardInfo[aid] then rewardInfo[aid] = {} end
			local rewards = drop.dropGroup(cfg.joinReward)
			table.insert(rewardInfo[aid], rewards)
			local actor = LActor.getActorById(aid)
			if actor and LActor.canGiveAwards(actor, rewards) then
				LActor.giveAwards(actor, rewards, "city join")
			else
				local mailData = {head=cfg.joinRewardMailTitle, context=cfg.joinRewardMailText, tAwardList=rewards }
				mailsystem.sendMailById(aid, mailData)
			end
		end
	end
end

--发幸运奖励
local function SetLuckyReward(rewardInfo, allJoinId)
	print("citysystem.SetLuckyReward")
	local cfg = CityBossConfig[cityBossCfgId]
	if not cfg then 
		print("citysystem.SetLuckyReward no idx:"..tostring(cityBossCfgId).." cfg")
		return
	end
	--拷贝一份奖励配置
	local luckyReward = utils.table_clone(cfg.luckyReward)
	--先发归属者的N个
	local belongLuckyRewards = {}
	for i = 1, cfg.luckyCount do
		if #luckyReward <= 0 then 
			print("citysystem.SetLuckyReward idx:"..tostring(cityBossCfgId).." luckyReward is send over on belong")
			return
		end
		local dropId = table.remove(luckyReward, math.random(1,#luckyReward))
		local rewards = drop.dropGroup(dropId)
		for _,v in ipairs(rewards or {}) do
			table.insert(belongLuckyRewards, v)
		end
	end
	--发放归属者奖励
	if cityBelong and #belongLuckyRewards > 0 then
		print("citysystem.SetLuckyReward cityBelong")
		local belongId = LActor.getActorId(cityBelong)
		if not rewardInfo[belongId] then rewardInfo[belongId] = {} end
		table.insert(rewardInfo[belongId], belongLuckyRewards)
		if LActor.canGiveAwards(cityBelong, belongLuckyRewards) then
			LActor.giveAwards(cityBelong, belongLuckyRewards, "city lucky")
		else
			local mailData = {head=cfg.luckyRewardMailTitle, context=cfg.luckyRewardMailTitle, tAwardList=belongLuckyRewards }
			mailsystem.sendMailById(belongId, mailData)
		end			
	end
	--这里下发其它人的幸运奖励
	while(#luckyReward > 0 and #allJoinId > 0)
	do
		local dropId = table.remove(luckyReward, math.random(1,#luckyReward))
		local aid = table.remove(allJoinId, math.random(1,#allJoinId))
		if not rewardInfo[aid] then rewardInfo[aid] = {} end
		local rewards = drop.dropGroup(dropId)
		table.insert(rewardInfo[aid], rewards)
		print("citysystem.SetLuckyReward aid:"..aid)
		local actor = LActor.getActorById(aid)
		if actor and LActor.canGiveAwards(actor, rewards) then
			LActor.giveAwards(actor, rewards, "city lucky")
		else
			local mailData = {head=cfg.luckyRewardMailTitle, context=cfg.luckyRewardMailTitle, tAwardList=rewards }
			mailsystem.sendMailById(aid, mailData)
		end
	end
end

--给所有人发送面板信息
local function SendRewardMianBan(rewardInfo)
	local monName = MonstersConfig[CityBossConfig[cityBossCfgId].bossId].name or ""
	for aid, rewardsTab in pairs(rewardInfo) do
		local actor = LActor.getActorById(aid)
		--玩家在线, 在主城里,或者在野外都弹出奖励框
		if actor and (LActor.getFubenHandle(actor) == cityFubenHandle or not LActor.isInFuben(actor)) then
			local npack = LDataPack.allocPacket(actor, Protocol.CMD_City, Protocol.sCityCmd_SendReward)
			if npack then 
				LDataPack.writeByte(npack, actor == cityBelong and 1 or 0)
				LDataPack.writeString(npack, cityBelong and LActor.getName(cityBelong) or "")
				LDataPack.writeByte(npack, cityBelong and LActor.getJob(cityBelong) or 0)
				LDataPack.writeByte(npack, cityBelong and LActor.getSex(cityBelong) or 0)
				local rewardCount = 0
				local count_pos = LDataPack.getPosition(npack)
				LDataPack.writeShort(npack, rewardCount)
				local allItem = {}
				for _,reward in ipairs(rewardsTab) do
					for _, v in ipairs(reward) do
						LDataPack.writeInt(npack, v.type or 0)
						LDataPack.writeInt(npack, v.id or 0)
						LDataPack.writeInt(npack, v.count or 0)
						rewardCount = rewardCount + 1
						
						if v.type == 1 and ItemConfig[v.id] and ItemConfig[v.id].needNotice == 1 then
							local itemName = item.getItemDisplayName(v.id)
							table.insert(allItem, itemName)
						end
					end
				end
				--写入奖励个数到包
				local end_pos = LDataPack.getPosition(npack)
				LDataPack.setPosition(npack, count_pos)
				LDataPack.writeShort(npack, rewardCount)
				LDataPack.setPosition(npack, end_pos)
				LDataPack.flush(npack)
				for _, itemName in ipairs(allItem) do
					noticemanager.broadCastNotice(CityBaseConfig.rewardNotice, LActor.getActorName(aid), "主城", monName, itemName)
				end
			end
		else
			for _,reward in ipairs(rewardsTab) do
				for _, v in ipairs(reward) do
					if v.type == 1 and ItemConfig[v.id] and ItemConfig[v.id].needNotice == 1 then
						local itemName = item.getItemDisplayName(v.id)
						noticemanager.broadCastNotice(CityBaseConfig.rewardNotice, LActor.getActorName(aid), "主城", monName, itemName)
					end
				end
			end
		end
	end
end

--BOSS死亡时候的处理
local function onMonsterDie(ins, mon, killerHdl)
	if cityBoss == mon then
		local rewardInfo = {
		--[[
			[玩家ID]={
				{{type=0,id=0,count=1}},{type=0,id=0,count=1}}--奖励
			}
		]]
		}
		--这里发奖励
		if cityBelong then
			--发放归属者奖励
			SetBelongReward(rewardInfo)
		end
		--发参与奖励
		local allJoinId = {}
		SetJoinReward(rewardInfo, allJoinId)
		--发幸运奖励
		SetLuckyReward(rewardInfo, allJoinId)
		--清空ins的伤害排名
		ins.boss_info = {}
		--给发送面板信息
		SendRewardMianBan(rewardInfo)
		--清空归属者
		BelongChange(cityBelong, nil)
		--场景所有玩家立即停止AI
		local actors = Fuben.getAllActor(cityFubenHandle)
		if actors ~= nil then
			for i = 1,#actors do 
				LActor.stopAI(actors[i])
			end
		end
		--护盾定时器
		if cityShield.shieldEid then
			LActor.cancelScriptEvent(nil, cityShield.shieldEid)
			cityShield.shieldEid = nil
		end
		--清空怪物
		cityBoss = nil
		--广播全服玩家boss死亡了
		sendCurBoss()
		--获取当前boss配置
		local conf = CityBossConfig[cityBossCfgId]
		local gdata = getGlobalData()
		if conf then
			if not gdata.monsterResCount then gdata.monsterResCount = {} end
			gdata.monsterResCount[conf.killBossId] = (gdata.monsterResCount[conf.killBossId] or 0) + 1
			gdata.monsterResTime[conf.killBossId] = System.getNowTime() + (getNeedKillCount(conf)-(gdata.monsterDieCount[conf.killBossId] or 0)) * (conf.reTime or 0)
		end
		--这里检测一下看看有没boss可以刷
		if gdata.monsterDieCount then
			for idx, cfg in ipairs(CityBossConfig or {}) do
				checkNeedCreateBoss(cfg, gdata.monsterDieCount[cfg.killBossId] or 0)
			end
		end
		--发送boss击杀进度
		if conf then
			sendBossProgress(nil, conf.killBossId)
		end
	end
end

--boss收到伤害的时候
local function onBossDamage(ins, monster, value, attacker, res)
	if monster ~= cityBoss then return end
	--第一下攻击者为boss归属者
    if nil == cityBelong and cityFubenHandle == LActor.getFubenHandle(attacker) then 
        local actor = LActor.getActor(attacker)
        if actor and LActor.isDeath(actor) == false then 
        	--改变归属者
			BelongChange(nil, actor)
			--使怪物攻击归属者
			--LActor.setAITarget(monster, LActor.getLiveByJob(actor))
		end		
    end
	
	--血量百分比
	local hp  = res.ret --实际血量
    hp = hp / LActor.getHpMax(monster) * 100
	
	if nil == cityShield.shield or 0 == cityShield.shield then
		--需要触发护盾
		if cityShield.nextShield and 0 ~= cityShield.nextShield.hp and hp < cityShield.nextShield.hp then
			cityShield.curShield = cityShield.nextShield
			cityShield.nextShield = getNextShield(cityShield.curShield.hp)
			--重置血量
			res.ret = math.floor(LActor.getHpMax(monster) * cityShield.curShield.hp / 100)
			--设置无敌
			LActor.SetInvincible(monster, true)
			cityShield.shield = cityShield.curShield.shield + System.getNowTime()
			notifyShield(cityShield.curShield.shield)
			print("citysystem.onBossDamage: postScriptEventLite shieldEid")
			--注册护盾结束定时器
			cityShield.shieldEid = LActor.postScriptEventLite(nil, (cityShield.curShield.shield or 0) * 1000, function() 
				cityShield.shield = 0
				LActor.SetInvincible(cityBoss, false)
				notifyShield(0)
				cityShield.shieldEid = nil
			end)
		end
	end
end

--玩家登陆时回调
function onLogin(actor)
	--发送boss击杀进度
	sendBossProgress(actor, nil)
	--发送一下当前主城内的bossid
	sendCurBoss(actor)
	--发送主城CD
	sendCityEnterCd(actor)
end

--创新新角色的时候
local function onCreateRole(actor, roleId)
	if cityFubenHandle == LActor.getFubenHandle(actor) then
		--设置阵营
		LActor.setCamp(actor, LActor.getActorId(actor))
		local role = LActor.getRole(actor, 0)--获得第一个角色
		local newRole = LActor.getRole(actor, roleId)--获得新角色
		if role and newRole then
			LActor.setAIPassivity(newRole, LActor.getAIPassivity(role))
		end
	end
end

--玩家离线的时候
local function onOffline(ins, actor)
	LActor.exitFuben(actor)
end

--玩家登出下线
local function onLogout(actor)
	local aid = LActor.getActorId(actor)
	if cityAllImageAid[aid] then
		Fuben.clearCloneRoleById(cityFubenIns.scene_list[1], aid)
		cityAllImageAid[aid] = nil
		RefreshOneRobot(aid)
	end
end

--开启前10分钟
local function createCityBoss(now_t, id)
	onOutsideBossDie(id)
end
_G.createCityBoss = createCityBoss

--初始化全局数据
local function initGlobalData()
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeCreateRole, onCreateRole)
	actorevent.reg(aeUserLogout, onLogout)

	role.registerSwitchTargetBeforeFunc(CityBaseConfig.fbId, OnSwitchTargetBefore)
	insevent.registerInstanceActorDie(CityBaseConfig.fbId, onActorDie)
	insevent.registerInstanceEnter(CityBaseConfig.fbId, onEnterFb)
	insevent.registerInstanceExit(CityBaseConfig.fbId, onExitFb)
	insevent.registerInstanceMonsterDie(CityBaseConfig.fbId, onMonsterDie)
	insevent.registerInstanceMonsterDamage(CityBaseConfig.fbId, onBossDamage)
	insevent.registerInstanceOffline(CityBaseConfig.fbId, onOffline)
	
	for idx, cfg in ipairs(CityBossConfig or {}) do
		cityBossIdCfg[cfg.killBossId] = cfg
	end

	if not cityFubenHandle then
		cityFubenHandle = Fuben.createFuBen(CityBaseConfig.fbId)
		cityFubenIns = instancesystem.getInsByHdl(cityFubenHandle)
		--这里检测一下看看有没boss可以刷
		local gdata = getGlobalData()
		if gdata.monsterDieCount then
			for idx, cfg in ipairs(CityBossConfig or {}) do
				checkNeedCreateBoss(cfg, gdata.monsterDieCount[cfg.killBossId] or 0)
			end
		end
	end
	
	netmsgdispatcher.reg(Protocol.CMD_City, Protocol.cCityCmd_Enter, reqEnterFuben) --请求进入主城
	netmsgdispatcher.reg(Protocol.CMD_City, Protocol.cCityCmd_StopAi, reqStopAi) --请求停止AI
	netmsgdispatcher.reg(Protocol.CMD_City, Protocol.cCityCmd_BuyReborn, onReqBuyReborn) --花钱复活
end

table.insert(InitFnTable, initGlobalData)

engineevent.regGameStartEvent(function()
	local timerInterval = CityBaseConfig.robotRefresh
	LActor.postScriptEventEx(nil, 1, RefreshAllRobot, timerInterval * 1000, -1)
end)

--city命令
function gmhandle(actor, args)
	if args[1] == "sai" then
		local role_count = LActor.getRoleCount(actor)
		for i = 0,role_count - 1 do
			local role = LActor.getRole(actor,i)
			LActor.setAIPassivity(role, false)
		end
	elseif args[1] == "eai" then
		LActor.stopAI(actor)
	elseif args[1] == "b" then
		onOutsideBossDie(tonumber(args[2]))
	elseif args[1] == "r" then
		onReqBuyReborn(actor, nil)
	elseif args[1] == "robot" then
		RefreshAllRobot()
	else
		reqEnterFuben(actor, nil)
	end
end
