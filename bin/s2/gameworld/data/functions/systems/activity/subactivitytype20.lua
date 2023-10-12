-- 节日BOSS
module("subactivitytype20", package.seeall)
--[[
data define:
	getDyanmicVar(id): 缓冲排名
	{
		startindex -- 需要启动的索引
		starttime -- 启动时间
		curFuben  --当前副本
	}
--]]

local subType = 20

-- 动态变量数据
local function getDyanmicVar( id )
	return activitysystem.getDyanmicVar(id)
end

-- 通知客户端消息
local function notifyOnlineActors( id )
	local actorlist = System.getOnlineActorList()
	if actorlist then
		for i=1,#actorlist do
			activitysystem.sendActivityData(actorlist[i], id)
		end
	end
end

-- 建立副本
local function createFuBen(id, index)
	-- 活动结束
	if activitysystem.activityTimeIsEnd(id) then 
		print("subactivitytype20.createFuBen id:"..id.." activity is end")
		return 
	end
	--获取当前活动配置
	local conf = ActivityType20Config[id]
	if not conf then
		print("subactivitytype20.createFuBen id:"..id.." not have config")
		return
	end
	--获取当前索引配置
	local cfg = conf[index]
	if not conf then
		print("subactivitytype20.createFuBen id:"..id..", index:"..index.." not have cfg")
		return
	end

	--记录当前创建的副本
	local dyvar = getDyanmicVar(id)
	dyvar.curFuben = Fuben.createFuBen(cfg.fbid)
	--获取ins
	local ins = instancesystem.getInsByHdl(dyvar.curFuben)
	if not ins then
		print("subactivitytype20.createFuBen fail id:"..id..",index:"..index)
		return
	end
	--记录当前副本的数据
	if not ins.data then ins.data = {} end
	ins.data.index = index
	ins.data.id = id
	ins.data.starttime = System.getNowTime()
	ins.data.endtime = ins.data.starttime + cfg.enterTime + cfg.duration
	print("subactivitytype20.createFuBen success id:"..id..",index:"..index..",fubenhanle:"..dyvar.curFuben)

	-- 通知客户端
	notifyOnlineActors(id)
end

-- 发送活动信息
local function writeRecord(npack, record, config, id, actor)
	local dyvar = getDyanmicVar(id)
	local bEnter = 0 --是否能进入
	local curIndex = dyvar.startindex --开启的索引
	local cfg = config[curIndex] or {}
	local endtime = (dyvar.starttime or 0) + (cfg.enterTime or 0) + (cfg.duration or 0) --结束的时间
	if dyvar.curFuben then
		local ins = instancesystem.getInsByHdl(dyvar.curFuben)
		if ins then
			bEnter = 1
			endtime = ins.data.endtime
			curIndex = ins.data.index
		end
	end
	LDataPack.writeInt(npack, curIndex or 0)
	LDataPack.writeInt(npack, endtime or 0)
	LDataPack.writeChar(npack, bEnter or 0)
end

-- 获取排名奖励
local function getRankReward( rankId, rewPool )
	if not rewPool then return nil end
	for _,v in pairs(rewPool) do
		if rankId >= v.start and rankId <= v.endi then
			return v
		end
	end
end

-- 发送公告
local function sendNotice( actorid, reward , conf)
	if conf and conf.notice then
		for _,v in pairs(reward or {}) do
			if ItemConfig[v.id] and ItemConfig[v.id].needNotice == 1 and conf.notice[ItemConfig[v.id].quality] then
				local itemName = item.getItemDisplayName(v.id)
				noticemanager.broadCastNotice(noticeId, LActor.getActorName(actorid), itemName)
			end
		end
	end
end

-- 
local function giveRewardWindow( actor, reward )
	--发窗口 直接给奖励
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Boss, Protocol.sWorldBoss_SendReward)
	if npack == nil then return end
	LDataPack.writeByte(npack, 0)
	LDataPack.writeString(npack, LActor.getName(actor))
	LDataPack.writeByte(npack, LActor.getJob(actor))
	LDataPack.writeByte(npack, LActor.getSex(actor))
	LDataPack.writeShort(npack, #reward)
	for _, v in ipairs(reward) do
		LDataPack.writeInt(npack, v.type or 0)
		LDataPack.writeInt(npack, v.id or 0)
		LDataPack.writeInt(npack, v.count or 0)
	end
	LDataPack.flush(npack)
end

-- 发放玩家奖励
local function giveActorReward(aid, rankId, damage, cfg, id, index, dyvar, ins)
	if not (aid and (damage or 0) >= (cfg.minDamage or 0)) then
		print("subactivitytype20.giveActorReward damage not enough,aid:"..(aid or -1)..",damage:"..(damage or -1)..",cfg.minDamage:"
			..(cfg.minDamage or 0)..",rankId:"..(rankId or -1))
		return
	end
	-- 排名奖励
	local reward = getRankReward(rankId, cfg.rankReward)
	if reward then
		print("subactivitytype20.giveActorReward send rankReward, id:"..id..",index:"..index..",aid:"..aid..",rankId:"..rankId)
		-- 发邮件
		mailsystem.sendMailById(aid, {head=reward.head, context=reward.context, tAwardList=reward.reward})
	else
		print("subactivitytype20.giveActorReward rankReward fail,index:"..index..",aid:"..aid..",rankId:"..rankId)
	end
	-- 掉落奖励
	reward = getRankReward(rankId, cfg.dropReward)
	if not reward then
		print("subactivitytype20.giveActorReward reward.drop nil,index:"..index..",aid:"..aid..",rankId:"..rankId)
		return
	end
	local dropRew = drop.dropGroup(reward.drop)
	if not dropRew or #dropRew <= 0 then
		print("subactivitytype20.giveActorReward not have dropRew,index:"..index..",aid:"..aid..",rankId:"..rankId)
		return
	end
	print("subactivitytype20.giveActorReward dropRew, id:"..id..",index:"..index..",aid:"..aid..",rankId:"..rankId)
	--获取玩家
	local actor = LActor.getActorById(aid)
	--玩家在线,并且奖励能进入背包,并且在当前副本里面
	if actor and LActor.canGiveAwards(actor, dropRew) and (dyvar.curFuben or 0) == LActor.getFubenHandle(actor) then 
		if rankId == 1 then -- 第1名掉地上捡
			local hscene = LActor.getSceneHandle(actor)
			local x,y = LActor.getPosition(actor)
			Fuben.RewardDropBag(hscene, x or 0, y or 0, aid, dropRew)
		else -- 不是第1名 弹框
			--ins:setRewards(actor, dropRew)
			LActor.giveAwards(actor, dropRew, "type20,index:"..index)
			giveRewardWindow(actor, dropRew)
		end
	else
		-- 发邮件
		mailsystem.sendMailById(aid, {head=reward.head, context=reward.context, tAwardList=dropRew})
	end
	-- 公告
	sendNotice(aid, dropRew, cfg)
end

-- 发放奖励
local function giveReward(ins, id, index, conf, dyvar)
	-- 没有数据
	if not (ins and ins.boss_info and ins.boss_info.damagelist) then 
		print("subactivitytype20.giveReward no damagelist,index:"..(tonumber(index) or -1))
		return 
	end
	local cfg = conf[index]
	--配置不存在
	if not cfg then
		print("subactivitytype20.giveReward cfg not exist,index:"..(tonumber(index) or -1))
		return
	end
	-- 发放奖励
	local damagerank = bossinfo.getDdamageRank(ins)
	for rankId,v in pairs(damagerank or {}) do
		local aid = v.id
		giveActorReward(aid, rankId, v.damage, cfg, id, index, dyvar, ins)
	end
end

-- 进入副本
local function onEnterFuben(actor, id)
	--获取动态变量
	local dyvar = getDyanmicVar(id)
	if not dyvar.curFuben then
		activitysystem.sendActivityData(actor, id)
		print(LActor.getActorId(actor).." subactivitytype20.onEnterFuben is not have fuben")
		return
	end
	-- 进入副本
	LActor.enterFuBen(actor, dyvar.curFuben)
end

-- 请求进入副本
local function getReward( id, typeconfig, actor, record, packet )
	onEnterFuben(actor, id)
end

--副本胜利或失败回调
local function onWinOrLose(id, conf, index)
	return function(ins)
		if ins and ins.data and ins.data.id == id and ins.data.index == index then
			local dyvar = getDyanmicVar(id)
			print("subactivitytype20 onWinOrLose giveReward,index:"..tostring(ins.data.index))
			--获取奖励
			giveReward(ins, id, ins.data.index, conf, dyvar)
			--清空当前副本handle
			dyvar.curFuben = nil
			-- 通知客户端
			notifyOnlineActors(id)
		end
	end
end

-- 副本中下线的处理
local function onOffline(id, conf, index)
	return function(ins, actor)
	    --手动调用退出副本，否则虽然会触发退出副本，但是上线会自动进入副本中
	    if ins and ins.data and ins.data.id == id and ins.data.index == index then
		    LActor.exitFuben(actor)
		end
	end
end

--玩家死亡时候的处理
local function onActorDie(id, conf, index)
	return function ( ins, actor, killerHdl )
		local dyvar = getDyanmicVar(id)
		if not dyvar.curFuben or dyvar.curFuben ~= LActor.getFubenHandle(actor) then return end
		-- 复活
    	local x,y = LActor.getPosition(actor)
        LActor.relive(actor, x, y)

	end
end

--BOSS死亡时候的处理
local function onMonsterDie(id, conf, index)
	return function ( ins, mon, killerHdl )
		if ins and ins.data and ins.data.id == id and ins.data.index == index then
			ins:win()
		end
	end
end

--计算最近一次需要开始的时间和index
local function initStartTime(id, conf, istime)
	--当前时间
	local now_t  = System.getNowTime() 
	--活动的结束时间
	local endTime = activitysystem.getEndTime(id)
	--计算当日距离当前最近的开始时间
	local startTime = nil
	local startIndex = nil
	for index,v in pairs(conf) do
		local time = istime + v.openTime - v.enterTime --当前项的开启时间
		if time > now_t and time < endTime then
			if startTime == nil then
				startTime = time
				startIndex = index
			elseif startTime > time then
				startTime = time
				startIndex = index
			end
		end
	end
	--当天没有,求下一天的
	if not startTime and (istime + (3600*24)) < endTime then
		initStartTime(id, conf, istime + (3600*24))
		return
	end
	--获取动态变量
	local dyvar = getDyanmicVar(id) 
	dyvar.starttime = startTime
	dyvar.startindex = startIndex
	if not dyvar.starttime then
		print("subactivitytype20.initStartTime id:"..id.." is over all")
	else
		local y,m,d,h,i,s = System.timeDecode(dyvar.starttime)
		print("subactivitytype20.initStartTime id:"..id..",index:"..dyvar.startindex..",nexttime:"..string.format("%d-%d-%d %d:%d:%d",y,m,d,h,i,s))
	end
end

local function onTimerEvent(id, conf)
	return function()
		local now_t  = System.getNowTime()
		--获取动态变量
		local dyvar = getDyanmicVar(id)
		if dyvar.starttime and dyvar.starttime <= now_t then
			createFuBen(id, dyvar.startindex)
			initStartTime(id, conf, System.getToday())
		end
	end
end

-- 初始化
local function initFunc(id, conf)
	local dyvar = getDyanmicVar(id)
	for index,v in pairs(conf) do
		-- 注册
		insevent.registerInstanceWin(v.fbid, onWinOrLose(id, conf, index)) -- 胜利
		insevent.registerInstanceLose(v.fbid, onWinOrLose(id, conf, index)) -- 失败
		insevent.registerInstanceOffline(v.fbid, onOffline(id, conf, index)) -- 玩家离线
		insevent.registerInstanceActorDie(v.fbid, onActorDie(id, conf, index))--玩家死亡
		insevent.registerInstanceMonsterDie(v.fbid, onMonsterDie(id, conf, index))--怪物死亡
	end
	dyvar.starttime = nil
	--活动开始那天的零点时间
	local st = activitysystem.getBeginTime(id)
	local y,m,d,h,i,s = System.timeDecode(st)
	print("subactivitytype20.initFunc id:"..id.." act startTime:"..string.format("%d-%d-%d %d:%d:%d",y,m,d,h,i,s))
	local actStartTime = System.timeEncode(y,m,d,0,0,0)
	--活动在之前就开启的
	if actStartTime < System.getToday() then 
		actStartTime = System.getToday()
	end
	initStartTime(id, conf, actStartTime)
	engineevent.regGameTimer(onTimerEvent(id, conf))

end

-- 注册一类活动配置
subactivities.regConf(subType, ActivityType20Config)
subactivities.regInitFunc(subType, initFunc)
subactivities.regWriteRecordFunc(subType, writeRecord)
subactivities.regGetRewardFunc(subType, getReward)
