module("challengefbsystem", package.seeall)

--curId 玩家当前进入的关卡id，对应配置的关卡id字段
--reward 1表示当天奖励可以领取，2表示已领取
--ydayLv 昨天的通关等级
--recLottery 按位表示,已经领取第几个索引的转盘奖励
--lotteryCount 已经使用了的抽奖次数
--lotteryTag 配置中的tag

--获取玩家挑战副本信息
local function getChallengeFbVar(actor)
	local var = LActor.getStaticVar(actor)
	if nil == var.challengeFb then
		var.challengeFb = {}
		var.challengeFb.curId = 0
		var.challengeFb.ydayLv = 0
		var.challengeFb.reward = 1
	end

	return var.challengeFb	
end

--获取临时动态数据
local function getDynamicData(actor)
	local var = LActor.getDynamicVar(actor)
	if var == nil then return nil end
	if var.challengeFb == nil then
		var.challengeFb = {}
	end
	return var.challengeFb
end

--获取玩家当前关卡等级对应的配置id，战纹用到
function getChallengeId(actor)
	local var = getChallengeFbVar(actor)
	local level = var.curId or 0
	local lvCount = #FbChallengeConfig
	if lvCount < level then level = lvCount end
	return level
end

--获取挑战关卡配置
local function getChallengeConfig(id)
	return FbChallengeConfig[id]
end

--获取当前有多少次抽奖次数
local function getLotteryCount(actor)
	local lv = getChallengeId(actor)
	local config = getChallengeConfig(lv)
	if not config then
		return 0
	end
	return config.lotteryCount or 0
end

--获取抽奖配置
local function getLotteryConfig(count)
	local cfg = FbChallengeLotteryConfig[count]
	if not cfg then
		return FbChallengeLotteryConfig[#FbChallengeLotteryConfig]
	end
	return cfg
end

--检测是否需要清空抽奖过的信息
local function checkClearLotteryInfo(actor)
	local var = getChallengeFbVar(actor)
	local cfg = getLotteryConfig((var.lotteryCount or 0) + 1)
	if var.lotteryTag ~= cfg.tag then
		var.lotteryTag = cfg.tag
		var.recLottery = nil
	end
end

--发送挑战信息
local function challengeInfoSync(actor)
	local var = getChallengeFbVar(actor)
	checkClearLotteryInfo(actor)
	local restatus = ((var.reward or 1) < 3 and (var.ydayLv or 0) > 0) and 1 or 2
	
	local curId = (var.curId or 0) + 1
	if curId > #FbChallengeConfig then curId = 0 end --这里比较蛋疼;0表示全部通关
	
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_ChallengeFb, Protocol.sChallengeCmd_InfoSync)
	if not pack then return end
	LDataPack.writeInt(pack, curId)
	LDataPack.writeShort(pack, restatus)
	LDataPack.writeInt(pack, var.recLottery or 0)
	LDataPack.writeInt(pack, var.lotteryCount or 0)
	LDataPack.flush(pack)	
end

local function createFuben(actor)
	local var = getChallengeFbVar(actor)
	local curId = (var.curId or 0) + 1
	local config = getChallengeConfig(curId)
	if not config then print("challengefbsystem.createFuben:conf is null, curid:"..curId) return end	

	local hfuben = Fuben.createFuBen(config.fbId)
	if 0 == hfuben then print("challengefbsystem.createFuben:createFuBen error, fbId:"..config.fbId) return end

	local ret = LActor.enterFuBen(actor, hfuben)
	if not ret then print("challengefbsystem.createFuben:enterFuBen error") end
end

--是否可以挑战下一关
local function isCanChallgeNext(actor, level)
	local conf = getChallengeConfig(level)
	if not conf then return false end

	if (conf.zsLevelLimit or 0) > LActor.getZhuanShengLevel(actor) or (conf.levelLimit or 0) > LActor.getLevel(actor) then
		return false
	end

	return true
end


local function onFbWin(ins)
	local actor = ins:getActorList()[1]
	if not actor then print("challengefbsystem.onFbWin:can not find actor")  return end --胜利的 时候不可能找不到吧

	local var = getChallengeFbVar(actor)
	local curId = (var.curId or 0) + 1
	local config = getChallengeConfig(curId)
	if not config then print("challengefbsystem.onFbWin:.conf  is null, curid:"..curId) return end
	
	local reward = drop.dropGroup(config.clearReward)
	instancesystem.setInsRewards(ins, actor, reward)

	if (ins.id == config.fbId) then
		var.curId = (var.curId or 0) + 1 --已通关
	end

	challengeInfoSync(actor)

	challengefbrank.updateRankingList(actor, var.curId)
	--成就
	actorevent.onEvent(actor, aeChallengeFb)
end

local function onFbLose(ins)
	local actor = ins:getActorList()[1]
	if not actor then print("challengefbsystem.onFbLose:can not find actor")  return end --胜利的 时候不可能找不到吧

	instancesystem.setInsRewards(ins, actor, nil)
end

--领取抽奖奖励
local function RecLottery(actor)
	local cache = getDynamicData(actor)
	if not cache.lotteryReward then
		return
	end
	--领奖
	if LActor.canGiveAwards(actor, {cache.lotteryReward}) then
		LActor.giveAwards(actor, {cache.lotteryReward}, "challengefb lottery")
	else
		local mailData = {head=FbChallengeBaseConfig.LotteryMailTitle, context=FbChallengeBaseConfig.LotteryMailText, tAwardList={cache.lotteryReward} }
		mailsystem.sendMailById(LActor.getActorId(actor), mailData)
	end
	--清空缓存
	cache.lotteryReward = nil
end

--请求抽奖
local function reqLottery(actor, packet)
	local var = getChallengeFbVar(actor)
	local cache = getDynamicData(actor)
	if cache.lotteryReward then
		RecLottery(actor)
	end
	--先判断次数是否足够
	if (var.lotteryCount or 0) >= getLotteryCount(actor) then
		print(LActor.getActorId(actor).." challengefbsystem.reqLottery not count")
		return
	end
	--拿抽奖池
	local cfg = getLotteryConfig((var.lotteryCount or 0)+1)
	local randTab = {}
	local randCount = 0
	for i,v in ipairs(cfg.group) do
		--判断这一次出不出
		if v.rate and v.rate > 0 then
			--判断是否已经出过
			if not System.bitOPMask(var.recLottery or 0, i) then
				table.insert(randTab, {i=i,reward=v})
				randCount = randCount + v.rate
			end
		end
	end
	--在奖池里面随机
	if randCount <= 0 then
		print(LActor.getActorId(actor).." challengefbsystem.reqLottery not reward,count:"..((var.lotteryCount or 0)+1)..",rec:"..(var.recLottery or 0))
		return
	end
	local randI = 0
	local rand = math.random(1,randCount)
	for _,v in ipairs(randTab) do
		if rand <= v.reward.rate then
			randI = v.i
			break;
		end
		rand = rand - v.reward.rate
	end
	if randI == 0 then
		print(LActor.getActorId(actor).." challengefbsystem.reqLottery randI=0,count:"..((var.lotteryCount or 0)+1)..",rec:"..(var.recLottery or 0))
		return
	end
	--记录奖品给缓存
	cache.lotteryReward = cfg.group[randI]
	--标记为已经抽奖
	var.recLottery = System.bitOpSetMask(var.recLottery or 0, randI, true)
	--增加次数
	var.lotteryCount = (var.lotteryCount or 0) + 1
	--发送抽奖结果给客户端
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_ChallengeFb, Protocol.sChallengeCmd_LotteryRes)
	LDataPack.writeInt(pack, var.lotteryCount)
	LDataPack.writeInt(pack, randI)
	LDataPack.flush(pack)
end

--请求领取抽奖奖励
local function reqRecLottery(actor, packet)
	RecLottery(actor)
	--同步数据到客户端
	challengeInfoSync(actor)
end

local function onLogin(actor)
	challengeInfoSync(actor)

	local var = getChallengeFbVar(actor)
	if not var then return end
	challengefbrank.updateRankingList(actor, var.curId)
end


local function onNewDay(actor, login)
	local var = getChallengeFbVar(actor)
	var.reward = 1
	var.ydayLv = var.curId
	if not login then
		onLogin(actor)
	end
end

local function onLogout(actor)
	RecLottery(actor)
end

--发送剩余时间
local function sendData(times, actor)
	if not times then print("times  is null") return end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_ChallengeFb, Protocol.sChallengeCmd_LeftTime)
	LDataPack.writeInt(pack, times)
	LDataPack.flush(pack)	
end

local function onEnterFb(ins, actor)
	local var = getChallengeFbVar(actor)
	local curId = (var.curId or 0) + 1
	local config = getChallengeConfig(curId)
	if not config then print("challengefbsystem.onEnterFb:config  is null, curid:"..curId) return end	

	sendData(config.limitTimes, actor)
end

local function onChallenge(actor)
	local var = getChallengeFbVar(actor)
	local curId = (var.curId or 0) + 1
	local conf = getChallengeConfig(curId)
	if not conf then print("challengefbsystem.onChallenge:conf is null,curid:"..curId) return end	

	local actorId = LActor.getActorId(actor)

	if conf.zsLevelLimit > LActor.getZhuanShengLevel(actor) then
        print("challengefbsystem.onChallenge:check zslevel failed,actor:"..LActor.getActorId(actor)..",id:"..conf.id)
        return
    end

	if conf.levelLimit > LActor.getLevel(actor) then
		print("challengefbsystem.onChallenge:check level failed,actor:"..LActor.getActorId(actor)..",id:"..conf.id)
		return
	end

	--[[
   if LActor.isInFuben(actor) then
		print("challengefbsystem.onChallenge:actor is in fuben. actorId:".. LActor.getActorId(actor))
		return
	end
	]]

	createFuben(actor)
end

--领取每日奖励
local function onGetReward(actor)
	local var = getChallengeFbVar(actor)
	local actorId = LActor.getActorId(actor)

	local status = 1   
	if 1 == var.reward then
		repeat
			--领取过了
			if 2 == var.reward then 
				print("challengefbsystem.onGetReward:already get reward, actorId:"..tostring(actorId)) 
				status = 2 
				break
			end
			local level = (var.ydayLv or 0)
			--一层也没通关过也不能领取
			if 0 == level then 
				print("challengefbsystem.onGetReward:curid is 1, actorId:"..tostring(actorId)) 
				status = 2 
				break
			end
			--判断配置是否存在
			local config = getChallengeConfig(level)
			if nil == config then 
				print("challengefbsystem.onGetReward: conf is null, id:"..level) 
				status = 2 
				break
			end
			
			local rewards = drop.dropGroup(config.dayReward)
			
			--记录奖励
			local reward_count = 0
			if not var.dayRewards then var.dayRewards = {} end
			for _,v in ipairs(rewards) do
				for ii = 1,v.count do 
					local k = reward_count + 1
					var.dayRewards[k] = {}
					var.dayRewards[k].type = v.type
					var.dayRewards[k].id = v.id
					var.dayRewards[k].count = 1
					reward_count = k
				end
			end
			var.dayRewardsCount = reward_count --一共有多少个
			var.dayRewardsRec = 0 --已经领取到第几个
			var.reward = 2
			print("send challengefb get rewards begin, actorId:"..tostring(actorId).." id:"..tostring(level))


			local conf = getChallengeConfig(level)
			if #FbChallengeConfig == level and conf then actorevent.onEvent(actor, aeEnterFuben, conf.fbId, false) end
			if not isCanChallgeNext(actor, level+1) then actorevent.onEvent(actor, aeEnterFuben, conf.fbId, false) end
		until(true)
	end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_ChallengeFb, Protocol.sChallengeCmd_GetReward)
	--LDataPack.writeShort(pack, status)
	LDataPack.writeShort(pack, (var.dayRewardsCount or 0) - (var.dayRewardsRec or 0))
	for i = (var.dayRewardsRec or 0)+1,(var.dayRewardsCount or 0) do
		local v = var.dayRewards[i]
		LDataPack.writeInt(pack, v.type)
		LDataPack.writeInt(pack, v.id)
		LDataPack.writeInt(pack, v.count)
	end
	LDataPack.flush(pack)	
end

local function onRecReward(actor)
	local var = getChallengeFbVar(actor)
	if 2 ~= var.reward then
		print("send challengefb not have rec rewards, actorId:"..tostring(actorId).." id:"..tostring(level))
		return
	end
	local rewards = {}
	--计算获取个数,最多12个
	local rec_count = math.min(12, (var.dayRewardsCount or 0) - (var.dayRewardsRec or 0))
	for i = 1,rec_count do
		local k = i + (var.dayRewardsRec or 0)
		local v = var.dayRewards[k]
		table.insert(rewards, {type=v.type, id=v.id, count=v.count})
	end
	--记录领取到第几个
	var.dayRewardsRec = (var.dayRewardsRec or 0) + rec_count
	--发放奖励咯
	LActor.giveAwards(actor, rewards or {}, "challengefb daily rewards")
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_ChallengeFb, Protocol.sChallengeCmd_RecReward)
	LDataPack.flush(pack)
	--判断一下是否发完了
	if (var.dayRewardsRec or 0) >= (var.dayRewardsCount or 0) then
		--发完了记录一下状态
		var.reward = 3
		--清空临时记录
		var.dayRewardsRec = nil
		var.dayRewardsCount = nil
		var.dayRewards = nil
	end
	--发一次奖励界面信息
	onGetReward(actor)
	challengeInfoSync(actor)
end

actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeUserLogout, onLogout) --玩家离线

netmsgdispatcher.reg(Protocol.CMD_ChallengeFb, Protocol.cChallengeCmd_Challenge, onChallenge)
netmsgdispatcher.reg(Protocol.CMD_ChallengeFb, Protocol.cChallengeCmd_GetReward, onGetReward)
netmsgdispatcher.reg(Protocol.CMD_ChallengeFb, Protocol.cChallengeCmd_RecReward, onRecReward)
netmsgdispatcher.reg(Protocol.CMD_ChallengeFb, Protocol.cChallengeCmd_ReqLottery, reqLottery)
netmsgdispatcher.reg(Protocol.CMD_ChallengeFb, Protocol.cChallengeCmd_RecLottery, reqRecLottery)

--注册相关回调
for _, config in pairs(FbChallengeConfig) do
	insevent.registerInstanceWin(config.fbId, onFbWin)
	insevent.registerInstanceLose(config.fbId, onFbLose)
	insevent.registerInstanceEnter(config.fbId, onEnterFb)
end

--challengeFb
function gmTestChallenge(actor, args)
	if args[1] == "lo" then
		reqLottery(actor, nil)
	elseif args[1] == "rlo" then
		reqRecLottery(actor, nil)
	elseif args[1] == "clo" then
		local var = getChallengeFbVar(actor)
		var.recLottery = nil
		var.lotteryCount = nil
		var.lotteryTag = nil
	else
		local level = tonumber(args[1])
		local conf = getChallengeConfig(level)
		if not conf then return end
		local var = getChallengeFbVar(actor)
		var.curId = level
		challengeInfoSync(actor)
	end
end
