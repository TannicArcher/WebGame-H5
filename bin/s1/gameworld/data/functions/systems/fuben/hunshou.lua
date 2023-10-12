module("hunshou", package.seeall)

--curId 玩家当前进入的关卡id，对应配置的关卡id字段
--dayCount 当天的奖励次数，每天有最多通关次数

--获取玩家挑战副本信息
local function getHunShouFbVar(actor)
	local var = LActor.getStaticVar(actor)
	if nil == var.hunshouFb then
		var.hunshouFb = {}
		var.hunshouFb.curId = 0
	end

	return var.hunshouFb
end

local function actor_log(actor, str)
	if not actor or not str then return end
	local aid = LActor.getActorId(actor)
	print("hunshou aid:" .. aid .. " log:" .. str)
end

--发送挑战信息
local function challengeInfoSync(actor)
	local var = getHunShouFbVar(actor)
	if not var or not var.curId then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_HunGu, Protocol.sHunShouCmd_InfoSync)
	if not pack then return end
	
	LDataPack.writeInt(pack, var.curId)
	LDataPack.writeInt(pack, var.dayCount or 0)

	LDataPack.flush(pack)
end

local function onFbWin(ins)
	local actor = ins:getActorList()[1]
	if not actor then
		print("hunshoufbsystem.onFbWin:can not find actor")
		return
	end

	local var = getHunShouFbVar(actor)
	local curId = (var.curId or 0) + 1
	local config = FsFbConfig[curId]
	if not config then
		actor_log(actor, "hunshoufbsystem.onFbWin:.conf is null, curId:"..curId)
		return
	end
	
	instancesystem.setInsRewards(ins, actor, config.award)

	challengeInfoSync(actor)
end

local function onGetAward(ins, actor)
	if not actor then return end

	if not ins.is_win then return end

	local var = getHunShouFbVar(actor)
	if not var or not var.curId then return end

	var.dayCount = (var.dayCount or 0) + 1
	var.curId = (var.curId or 0) + 1

	challengeInfoSync(actor)
end

local function onFbLose(ins)
	local actor = ins:getActorList()[1]
	if not actor then
		print("hunshoufbsystem.onFbLose:can not find actor")
		return
	end

	instancesystem.setInsRewards(ins, actor, nil)
end

local function onNewDay(actor)
	local var = getHunShouFbVar(actor)
	if not var or not var.curId then return end

	var.dayCount = 0
	challengeInfoSync(actor)
end

local function onEnterFb(ins, actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_HunGu, Protocol.sHunShouCmd_LeftTime)
	LDataPack.writeInt(pack, ins.end_time)

	LDataPack.flush(pack)
end

local function onChallenge(actor)
	-- 开服天数
	if (System.getOpenServerDay() + 1) < HunGuConf.fbOpenDay then
		return
	end

	local var = getHunShouFbVar(actor)
	local curId = (var.curId or 0) + 1
	local conf = FsFbConfig[curId]
	if not conf then
		actor_log(actor, "hunshoufbsystem.onChallenge:conf is null,curId:"..curId)
		return
	end	
	-- 转生等级
	if conf.zsLevelLimit > LActor.getZhuanShengLevel(actor) then
		actor_log(actor, "hunshoufbsystem.onChallenge:check zslevel failed,idx:"..conf.idx)
		return
	end

	-- 每日通关次数
	if (var.dayCount or 0) >= HunGuConf.dayRewardCount then
		actor_log(actor, "hunshoufbsystem.onChallenge:check dayCount failed,idx:"..conf.idx..",dayCount:"..(var.dayCount or 0))
		return
	end
	
	local hfuben = Fuben.createFuBen(conf.fbId)
	if 0 == hfuben then
		actor_log(actor, "hunshoufbsystem.createFuben:createFuBen error, fbId:"..conf.fbId)
		return
	end

	local ret = LActor.enterFuBen(actor, hfuben)
	if not ret then
		actor_log(actor, "hunshoufbsystem.createFuben:enterFuBen error")
	end
end

-- 扫荡
local function onSweep( actor )
	local var = getHunShouFbVar(actor)
	local curId = var.curId or 0
	local conf = FsFbConfig[curId]
	-- 配置与配置奖励不存在，直接返回
	if not conf then
		actor_log(actor, "hunshoufbsystem.onSweep:conf is null,curId:"..curId)
		return
	end
	if not conf.dropId then
		actor_log(actor, "hunshoufbsystem.onSweep dropId nil,curId:"..curId)
		return
	end
	
	-- 每日通关次数
	local dayCount = var.dayCount or 0
	if dayCount >= HunGuConf.dayRewardCount then
		actor_log(actor, "hunshoufbsystem.onSweep:check dayCount failed,idx:"..conf.idx..",dayCount:"..dayCount)
		return
	end
	-- 扫荡开启
	if curId < HunGuConf.sweepLayer then
		actor_log(actor, "hunshoufbsystem.onSweep:check sweepLayer failed,idx:"..conf.idx)
		return
	end

	local award = drop.dropGroup(conf.dropId)
	-- 能否放进背包
	if not LActor.canGiveAwards(actor, award) then
		actor_log(actor, "hunshoufbsystem.onSweep not canGiveAwards,curId:"..curId)
		return
	end
	-- 发放奖励
	var.dayCount = dayCount + 1
	LActor.giveAwards(actor, award, "hunshou,idx:"..curId)
	
	-- 发送扫荡结果消息
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_HunGu, Protocol.sHunShouCmd_SweepResult)
	if not pack then return end

	LDataPack.writeInt(pack, curId)
	LDataPack.writeInt(pack, HunGuConf.dayRewardCount - var.dayCount)
	LDataPack.writeInt(pack, #award)
	for _, v in pairs(award) do
		LDataPack.writeInt(pack, v.type)
		LDataPack.writeInt(pack, v.id)
		LDataPack.writeInt(pack, v.count)
	end

	LDataPack.flush(pack)
end

actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeUserLogin, challengeInfoSync)

netmsgdispatcher.reg(Protocol.CMD_HunGu, Protocol.cHunShouCmd_Challenge, onChallenge)
netmsgdispatcher.reg(Protocol.CMD_HunGu, Protocol.cHunShouCmd_Sweep, onSweep)

--注册相关回调
for _, config in pairs(FsFbConfig) do
	insevent.registerInstanceWin(config.fbId, onFbWin)
	insevent.registerInstanceLose(config.fbId, onFbLose)
	insevent.registerInstanceEnter(config.fbId, onEnterFb)
	insevent.registerInstanceGetRewards(config.fbId, onGetAward)
end


local gmsystem    = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.hunshou = function(actor, args)
	local tmp = tonumber(args[1])
	if tmp == 1 then
		onChallenge(actor)
	elseif tmp == 2 then
		onSweep(actor)
	elseif tmp == 3 then
		onNewDay(actor)
	elseif tmp == 4 then
		local var = getHunShouFbVar(actor)
		if not var or not var.curId then return end

		var.curId = tonumber(args[2])

		challengeInfoSync(actor)
	end
end


