module("leadfuben", package.seeall)

local CampType = {
	MonsterCamp = 0,
	ActorCamp = 1,
	SelfCamp = 2,
}

local FbSubType = {
	PublicBoss = 1,
	GuildBattle = 2
}

--[[
cache={
	robotDie = false, --机器人有没有死过
	robots = {
		{
			hdl = 机器人实体handle,
			id = 机器人配置ID
			die_count = 死亡次数
		},
	} --当前副本中所有的机器人玩家
}
]]
--获取临时动态数据
local function getDynamicData(actor)
	local var = LActor.getDynamicVar(actor)
	if var == nil then return nil end

	if var.leadfuben == nil then
		var.leadfuben = {}
	end
	return var.leadfuben
end

--[[
data = {
	finishFb[副本ID]=1  --已经参与过的副本
}
]]
--获取静态数据
local function getData(actor)
	local data = LActor.getStaticVar(actor)
	if nil == data then return nil end
	if nil == data.leadfuben then data.leadfuben = {} end

	return data.leadfuben
end

--是否已参加过该副本了
local function isJoin(actor, fbId)
	local data = getData(actor)
	if data[fbId] then return true end
	return false
end

--选择奖励
local function getRewardInfo(config, rewardType)
	if not config then return nil end
	if 0 == rewardType then return config.belongReward end
	if 1 == rewardType then return config.reward end
	return nil
end

local function getConfig(fbId)
	local config = LeadFubenConfig[fbId]
	if not config then print("leadfuben.reqEnterFb: config is nil, fbId:"..tostring(fbId)) end

	return config
end

--发送邮件奖励
local function sendRewardMail(actor, reward)
	local mailData = {head=LeadFubenBaseConfig.leadFubenMailHead, context=LeadFubenBaseConfig.leadFubenMailContent, tAwardList={}}
	mailsystem.sendMailById(LActor.getActorId(actor), mailData)
end

--发奖励
local function sendReward(actor, reward, fbId)
	if LActor.canGiveAwards(actor, reward) then 
		LActor.giveAwards(actor, reward, "leadFubenReward, fbId:"..tostring(fbId))
    else
    	sendRewardMail(actor, reward)
    end

    print("leadfuben.sendReward: get reward success, fbId:"..tostring(fbId)..", actorId:"..tostring(LActor.getActorId(actor)))
end

--创建人形怪
local function createRobot(ins, v, reborn)
	local d = RobotData:new_local()
	d.name  = v.name
	d.level = v.level
	d.job = v.job
	d.sex = v.sex 
	d.clothesId = v.clothesId 
	d.weaponId = v.weaponId
	d.wingOpenState = v.wingOpenState
	d.wingLevel = v.wingLevel 
	d.attrs:Reset()
	for j,jv in pairs(v.attrs) do 
		d.attrs:Set(jv.type,jv.value)
	end
	for j,jv in pairs(v.skills) do 
		d.skills[j] = jv
	end
	local x,y = v.posX, v.posY
	if reborn then
		x,y = v.rposX, v.rposY
	end
	local robot = LActor.createRobot(d, ins.scene_list[1], x,y)
	return robot
end

--请求进入副本
local function EnterFb(actor, fbId)
	local config = getConfig(fbId)
	if not config then return end

	local actorId = LActor.getActorId(actor)

	--参加过就不能参加了
	--if true == isJoin(actor, fbId) then 
	--	print("leadfuben.EnterFb: already join before, fbId:"..tostring(fbId)..", actorId:"..tostring(actorId)) 
	--	return 
	--end
	
	--创建副本
	local hfuben = Fuben.createFuBen(fbId)
	if 0 == hfuben then
		print("leadfuben.EnterFb: create fuben failed, fbId:"..tostring(fbId)..", actorId:"..tostring(actorId)) 
		return
	end
	
	local ins = instancesystem.getInsByHdl(hfuben)
	if not ins then
		print("leadfuben.EnterFb: get ins failed, fbId:"..tostring(fbId)..", actorId:"..tostring(actorId)) 
		return
	end
	
	local cache = getDynamicData(actor)
	cache.robots = {}
	--创建人形怪
	for i ,v in pairs(LeadRobotConfig) do
		if v.fbId == fbId then
			local robot = createRobot(ins,v) 
			LActor.setCamp(robot, v.camp)
			table.insert(cache.robots, {hdl=LActor.getHandle(robot),id=v.id})
		end
	end
	
	--进入副本
	if true == LActor.enterFuBen(actor, hfuben) then 
		--记录
		local data = getData(actor)
		data[fbId] = 1 
	end
end

local function reqEnterFb(actor, packet)
	local fbId = LDataPack.readInt(packet)
	EnterFb(actor, fbId)
end


local function reqAttackRobot(actor, packet)
	local cache = getDynamicData(actor)
	if not cache.robots or #cache.robots <= 0 then return end
	for _,v in ipairs(cache.robots) do
		if v.hdl then
			local robot = LActor.getEntity(v.hdl)
			if robot then
				LActor.setAITarget(actor, robot)
				LActor.setAITarget(robot, LActor.getLiveByJob(actor))
				LActor.setCamp(robot, CampType.SelfCamp)
				return
			end
		end
	end
	print("leadfuben.reqAttackRobot not find robot, aid:"..LActor.getActorId(actor))
end

local function onWin(ins)
	local actor = ins:getActorList()[1]
	if nil == actor then print("leadfuben.onWin:can't find actor") return end

	local config = getConfig(ins.id)
	if not config then return end
	local reward = config.reward
	if config.type == FbSubType.PublicBoss then
		local cache = getDynamicData(actor)
		if cache.robotDie then
			reward = config.belongReward
		end
	end
	instancesystem.setInsRewards(ins, actor, reward)
end

--只有龙城争霸类型的会出现输的情况
local function onLose(ins)
	local actor = ins:getActorList()[1]
	if not actor then print("leadfuben.onLose:can not find actor") return end
	instancesystem.setInsRewards(ins, actor, nil)
	local config = getConfig(ins.id)
	if not config then return end
	if not config.reward then return end
	sendReward(actor, config.reward, ins.id)
end

local function onOffline(ins, actor)
	print("leadfuben.onOffline:ins,id:"..tostring(ins.id))
    --退出副本
	LActor.exitFuben(actor)
	local config = getConfig(ins.id)
	if not config then return end
	if not config.reward then return end
	sendReward(actor, config.reward, ins.id)
end

local function onCloneRoleDie(ins, robot, killer_hdl)
	local actor = ins:getActorList()[1]
	if actor == nil then 
		return
	end
	
	local cache = getDynamicData(actor)
	if not cache.robots or #cache.robots <= 0 then return end
	cache.robotDie = true
	for idx,v in ipairs(cache.robots) do
		if v.hdl == LActor.getHandle(robot) and (v.die_count or 0) <= 0 then
			v.hdl = nil
			--延迟复活机器人
			LActor.postScriptEventLite(actor, 1000, function(actor, idx, cid, hfuben)
				local dins = instancesystem.getInsByHdl(hfuben)
				if not dins then return end
				local cfg = LeadRobotConfig[cid]
				local robot = createRobot(dins, cfg, true) 
				LActor.setCamp(robot, CampType.SelfCamp)
				LActor.setAITarget(robot, LActor.getLiveByJob(actor))
				--记录机器人handle
				local dcache = getDynamicData(actor)
				dcache.robots[idx].hdl=LActor.getHandle(robot)
			end, idx, v.id, ins.handle)
			v.die_count = (v.die_count or 0) + 1
			break
		end
	end
end

--通知玩家的复活信息
local function notifyRebornTime(actor, killerHdl)
    local cache = getDynamicData(actor)
    local rebornCd = (cache.rebornCd or 0) - System.getNowTime()
    if rebornCd < 0 then rebornCd = 0 end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Fuben, Protocol.sFubenCmd_updateRebornTime)
    LDataPack.writeShort(npack, rebornCd)
	LDataPack.writeDouble(npack, killerHdl or 0)
    LDataPack.flush(npack)
end

--复活倒计时到了
local function reborn(actor, rebornCd)
    local cache = getDynamicData(actor)
    if cache.rebornCd ~= rebornCd then print(LActor.getActorId(actor).." leadfuben.reborn:cache.rebornCd ~= rebornCd") return end
    notifyRebornTime(actor)
    LActor.relive(actor)
end

--玩家死亡了
local function onActorDie(ins, actor, killerHdl)
    local cache = getDynamicData(actor)
	-- 计时器自动复活
	local rebornCd = System.getNowTime() + (LeadFubenBaseConfig.rebornCd or 0)
    cache.eid = LActor.postScriptEventLite(actor, (LeadFubenBaseConfig.rebornCd or 0) * 1000, reborn, rebornCd)
    cache.rebornCd = rebornCd
	--通知复活时间
    notifyRebornTime(actor, killerHdl)
end

--花钱复活
local function onReqBuyReborn(actor, packet)
    local cache = getDynamicData(actor)
    --复活时间已到
    if (cache.rebornCd or 0) < System.getNowTime() then 
		print("leadfuben.onReqBuyReborn: rebornCd < System.getNowTime(),  actorId:"..LActor.getActorId(actor)) 
		return 
	end
	--先判断有没有复活道具
	if WorldBossBaseConfig.rebornItem and LActor.getItemCount(actor, WorldBossBaseConfig.rebornItem) > 0 then
		LActor.costItem(actor, WorldBossBaseConfig.rebornItem, 1, "leadfuben buy cd")
	else
		--判断钱是否足够
		local yb = LActor.getCurrency(actor, NumericType_YuanBao)
		if LeadFubenBaseConfig.BuyRebornCost > yb then 
			print("leadfuben.onReqBuyReborn: BuyRebornCost > yb, actorId:"..LActor.getActorId(actor))
			return 
		end
		--扣元宝
		LActor.changeYuanBao(actor, 0 - LeadFubenBaseConfig.BuyRebornCost, "leadfuben buy reborn")
	end
    cache.rebornCd = nil
	--通知复活时间
    notifyRebornTime(actor)
	--复活
	LActor.relive(actor)
end

--怪物死亡的时候
local function onMonsterDie(ins, mon, killerHdl)
	local actor = ins:getActorList()[1]
	if not actor then print("leadfuben.onMonsterDie:can not find actor") return end
    local monid = Fuben.getMonsterId(mon)
	local cfg = LeadfbMonsterDropConfig[monid]
    if not cfg then return end
	local rewards = drop.dropGroup(cfg.drop)
	local posX,posY = LActor.getPosition(mon) -- 获取所在位置;用于掉落位置
	local dropRewards = {}
	local job = LActor.getJob(actor)
	for _,v in ipairs(rewards) do
		if not v.job or v.job == job then
			table.insert(dropRewards, v)
		end
	end
	--产生掉落物
	local hscene = LActor.getSceneHandle(actor)
	Fuben.RewardDropBag(hscene, posX, posY, LActor.getActorId(actor), dropRewards)
end

--初始化全局数据
local function initGlobalData()
	netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_EnterLeadFuben, reqEnterFb)
	netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_AttackLeadRobot, reqAttackRobot)
	netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_BuyReborn, onReqBuyReborn) --花钱复活

	for _, v in pairs(LeadFubenConfig or {}) do
		insevent.registerInstanceWin(v.fbId, onWin)
		insevent.registerInstanceLose(v.fbId, onLose)
		insevent.registerInstanceOffline(v.fbId, onOffline)
		if v.type ~= FbSubType.GuildBattle then
			insevent.regCloneRoleDie(v.fbId, onCloneRoleDie)
			insevent.registerInstanceActorDie(v.fbId, onActorDie)
		else
			insevent.registerInstanceMonsterDie(v.fbId, onMonsterDie)
		end
	end
end

table.insert(InitFnTable, initGlobalData)

--Gm命令:leadfb
function gmHandle(actor, arg)
	local op = arg[1]
	if op == "e" then
		local fbId = tonumber(arg[2])
		EnterFb(actor, fbId)
	elseif op == "a" then
		reqAttackRobot(actor, nil)
	end
end














