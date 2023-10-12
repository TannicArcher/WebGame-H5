--公会副本

--[[
--1.保存在公会中的信息
guildfb = {
	--每关通关的人数(不重置) 
	wavePass = {
		[wave] = 0,  --通关人数
	}
	--每天每关前5名通过玩家（每天重置）
	daywavePass = {
		[wave] = {                 
			{actorId, name},
			{actorId, name},  
	}
	--昨天最高通关人（每天重置）
	dayTop = { actorId, wave}
	--今日最高通关
	dayTopWave,
	--全民奖励进度
	dayAward = {level, Num},  --level 第x段奖励 Num 通过人数
	--助威人数
	cheerNum,
}
]]--

--[[
--2.保存在玩家上的信息
guildfb = {
	wave,        --通关关数
	daywave,     --本日通关关数
	sweep,       --扫荡关卡
	finishsweep, --完成扫荡
	welfare,     --领取全民福利的次数
	cheer,       --助威次数
}

]]--

module("guildfuben", package.seeall)


local rankName    = "guild_"
local rankFile    = "guild_%d.rank"
--local rankColumns = {"actorId", "wave"} 
local rankMaxSzie = 50

--获取玩家的公会副本信息
local function getActorGuildfbVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var.guildfb then
		var.guildfb = {}
	end
	if not var.guildfb.wave then
		var.guildfb.wave = 0
	end
	if not var.guildfb.daywave then
		var.guildfb.daywave = 0
	end
	if not var.guildfb.sweep then
		var.guildfb.sweep = 0
	end
	if not var.guildfb.welfare then
		var.guildfb.welfare = 0
	end
	if not var.guildfb.cheer then
		var.guildfb.cheer = 0
	end
	if not var.guildfb.finishsweep then
		var.guildfb.finishsweep = 0
	end
	return var.guildfb
end

--获取公会副本信息
local function getGuildfbVar(guild)
	local var = LGuild.getStaticVar(guild, true)
	if not var.fb then
		var.fb = {}
	end
	if not var.fb.wavePass then
		var.fb.wavePass = {}
	end
	if not var.fb.daywavePass then
		var.fb.daywavePass = {}
	end
	if not var.fb.dayTop then
		var.fb.dayTop = {}
	end
	if not var.fb.dayAward then
		var.fb.dayAward = {}
	end
	if not var.fb.cheerNum then
		var.fb.cheerNum = 0
	end
	if not var.fb.dayTopWave then
		var.fb.dayTopWave = 0
	end
	return var.fb
end

--通知公会信息变更
local function noticeGuildfbInfoChange(guild, type)
	local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, Protocol.CMD_Guildfb)
	LDataPack.writeByte(pack, Protocol.sGuildCmd_InfoChange)
	LDataPack.writeByte(pack, type)
	LGuild.broadcastData(guild, pack)
end

--通知公会全民每日福利变更
local function noticeGuildfbDayAward(guild)
	local var  = getGuildfbVar(guild) 
	local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, Protocol.CMD_Guildfb)
	LDataPack.writeByte(pack, Protocol.sGuildfbCmd_DayAward)
	LDataPack.writeWord(pack, var.dayAward.Level or 0)
	LDataPack.writeWord(pack, var.dayAward.Num or 0)
	LGuild.broadcastData(guild, pack)
end

--通知下一波怪
local function noticeGuildfbNextWave(actor, wave)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Guildfb, Protocol.sGuildfbCmd_NextWave)
	if not pack then return end
	LDataPack.writeWord(pack, wave)
	LDataPack.flush(pack)
end

--通知这一波的剩余时间
local function noticeGuildfbWaveTime(ins, actor)
	local time = ins:onGetCustomVariable("waveTime")
	local wave = ins:onGetCustomVariable("wave")
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Guildfb, Protocol.sGuildfbCmd_WaveTime)
	if not pack then return end

	LDataPack.writeWord(pack, wave)
	LDataPack.writeInt(pack, time)
	LDataPack.flush(pack)
end

--更新玩家信息
local function sendActorGuildfbInfo(actor)
	local guild = LActor.getGuildPtr(actor)
	if not guild then return end  

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Guildfb, Protocol.sGuildfbCmd_ActorInfo)
	if not pack then return end

	local var  = getGuildfbVar(guild)
	local Info = getActorGuildfbVar(actor)
	LDataPack.writeWord(pack, Info.wave)
	LDataPack.writeByte(pack, Info.finishsweep)
	LDataPack.writeWord(pack, Info.sweep)
	LDataPack.writeByte(pack, Info.welfare)
	LDataPack.writeByte(pack, Info.cheer)
	LDataPack.writeByte(pack, var.wavePass[Info.wave + 1] or 0)
	LDataPack.flush(pack)
	--print("sendActorGuildfbInfo")
end

--更新全民每日福利信息
local function SendActorDayAward(actor)
	local guild = LActor.getGuildPtr(actor)
	if not guild then return end

	local var  = getGuildfbVar(guild)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Guildfb, Protocol.sGuildfbCmd_DayAward) 
	LDataPack.writeWord(pack, var.dayAward.Level or 0)
	LDataPack.writeWord(pack, var.dayAward.Num or 0)
	LDataPack.flush(pack)
end

--获取公会副本排行
local function getGuildfbRank(guild)
	local guildId = LGuild.getGuildId(guild)
	local name = rankName..guildId
	
	local rank = Ranking.getRanking(name)
	if not rank then
		rank = Ranking.add(name, rankMaxSzie)
		if not rank then return end  

		local file = string.format(rankFile, guildId)
		if not Ranking.load(rank, file) then
			Ranking.save(rank, file)
		end
		return rank
	end
	return rank
end

--添加公会副本排行
local function addGuildfbRank(guild, actorId, wave)
	local rank = getGuildfbRank(guild)
	if not rank then return false end

	local item
	local oldrank = Ranking.getItemIndexFromId(rank, actorId)
	if oldrank >= 0 then
		item = Ranking.setItem(rank, actorId, wave)
	else
		item = Ranking.addItem(rank, actorId, wave)
	end
	if not item then return false end
	
	local newrank = Ranking.getIndexFromPtr(item)
	if newrank < guildfbconfig.rankShowMax then
		noticeGuildfbInfoChange(guild, 1)
	end
end

--记录每天通关前x位
local function setDayWavePassRecord(guild, actor, wave)
	local Info = getActorGuildfbVar(actor)
	local oldwave = Info.daywave
	if oldwave >= wave then return end
	Info.daywave = wave
	

	local var = getGuildfbVar(guild)
	if wave > var.dayTopWave then
		var.dayTopWave = wave
	end

	local record = {
		actorId = LActor.getActorId(actor), 
		name    = LActor.getName(actor),
	}
	for i = oldwave + 1, wave do 
		if not var.daywavePass[i] then 
			var.daywavePass[i] = {}
		end
		local len = #var.daywavePass[i]
		if len < guildfbconfig.dayRecordMax then
			var.daywavePass[i][len+1] = record
		end
	end
end

--记录通关奖励进度
local function setGuildDayAward(guild)
	local var = getGuildfbVar(guild)
	local oldLevel = var.dayAward.Level or 0
	local oldNum   = var.dayAward.Num   or 0
	
	local Award = guildfbDayAwardConfig
	for i = #Award, math.max(oldLevel, 1), -1 do 
		local data    = Award[i]
		local List    = var.daywavePass[data.wave]
		if List and #List > 0 then
			var.dayAward.Level = i
			var.dayAward.Num   = #List 
			break
		end  
	end
	--通知进度发生改变
	if oldLevel ~= (var.dayAward.Level or 0) or oldNum ~= (var.dayAward.Num or 0) then
		noticeGuildfbDayAward(guild)
	end
end

--给予通关奖励
local function giveWaveAward(actor, wave)
	if not guildfbAwardConfig[wave] then return end

	local itemId = guildfbAwardConfig[wave].waveAward
	if not itemId then return end

	local rewards = {
		{type = AwardType_Item, id = itemId, count = 1},
	}

	if not LActor.canGiveAwards(actor, rewards) then --发邮件
		local Title = guildfbconfig.waveTitle or "guildfb waveAward"
		local mailData = {
			head      = Title, 
			context   = "", 
			tAwardList= rewards
		}
		mailsystem.sendMailById(LActor.getActorId(actor), mailData)
	else                                             --直接给奖励
		LActor.giveAwards(actor, rewards, "guildfb waveAward")
    end
end

--给予扫荡奖励
local function giveSweepAward(actor, sweepWave, Info, last)
	if not guildfbAwardConfig[sweepWave] then return end
	local rewards_A,rewards_B 

	local awardId_A = guildfbAwardConfig[sweepWave].sweepAward_A
    if not awardId_A then return end

 	--print("awardId_A:"..awardId_A)
    rewards_A = drop.dropGroup(awardId_A)
	if not rewards_A then return end

	if not LActor.canGiveAwards(actor, rewards_A) then
		LActor.sendTipmsg(actor, guildfbconfig.noticefull or " ", 2)
		local pack = LDataPack.allocPacket(actor, Protocol.CMD_Guildfb, Protocol.sGuildfbCmd_StopSweep)
		if not pack then return end
		LDataPack.flush(pack)
		return 
	end

	if last then
		local awardId_B = guildfbAwardConfig[sweepWave].sweepAward_B
    	if not awardId_B then return end
    	--print("awardId_B:"..awardId_B)

    	rewards_B = drop.dropGroup(awardId_B)
		if not rewards_B then return end

		if not LActor.canGiveAwards(actor, rewards_B) then
			LActor.sendTipmsg(actor, guildfbconfig.noticefull or " ", 2)
			local pack = LDataPack.allocPacket(actor, Protocol.CMD_Guildfb, Protocol.sGuildfbCmd_StopSweep)
			if not pack then return end
			LDataPack.flush(pack)
			return
		end 
	end
	
	if rewards_A then
		LActor.giveAwards(actor, rewards_A, "guildfb sweepAward")
	end

	if rewards_B then
		LActor.giveAwards(actor, rewards_B, "guildfb sweepAward")
		Info.finishsweep = 1
	end

	return true

	-- if not LActor.canGiveAwards(actor, rewards) then --发邮件
	-- 	local Title = guildfbconfig.sweepTitle or "guildfb sweepAward"
	-- 	local mailData = {
	-- 		head      = Title, 
	-- 		context   = "", 
	-- 		tAwardList= rewards
	-- 	}
	-- 	mailsystem.sendMailById(LActor.getActorId(actor), mailData)
	-- 	LActor.sendTipmsg(actor, guildfbconfig.noticefull or " ")
	-- else                                             --直接给奖励
	-- 	LActor.giveAwards(actor, rewards, "guildfb sweepAward")
 --    end

 --    if last then
 --    	awardId = guildfbAwardConfig[Info.wave].sweepAward_B
 --    	if not awardId then return end

 --    	if not LActor.canGiveAwards(actor, rewards) then --发邮件
	-- 		local Title = guildfbconfig.sweepTitle or "guildfb sweepAward"
	-- 		local mailData = {
	-- 			head      = Title, 
	-- 			context   = "", 
	-- 			tAwardList= rewards
	-- 		}	
	-- 		mailsystem.sendMailById(LActor.getActorId(actor), mailData)
	-- 		LActor.sendTipmsg(actor, guildfbconfig.noticefull or " ")
	-- 	else                                             --直接给奖励
	-- 		LActor.giveAwards(actor, rewards, "guildfb sweepAward")
 --    	end
 --    	Info.finishsweep = 1
 --    end
end

--------------------副本逻辑相关------------------
--开始下一波
local function NextWave(ins)
	local actor = ins:getActorList()[1]
	if not actor then return end

	
	local fbConfig = InstanceConfig[guildfbconfig.fbId]
	if not fbConfig or not fbConfig.templateConfig or not fbConfig.templateConfig.failTime then return end

	local time = System.getNowTime()
	time = time + fbConfig.templateConfig.failTime
	ins:onSetCustomVariable("waveTime", time)

	noticeGuildfbWaveTime(ins, actor)
end
insevent.regCustomFunc(guildfbconfig.fbId, NextWave, "NextWave")

--杀死第X组怪
local function KillMonGroup(ins)
	local actor = ins:getActorList()[1]
	if not actor then return end
	--1.设置玩家的通关数
	local Info       = getActorGuildfbVar(actor) 
	Info.wave        = (Info.wave or 0) + 1
	sendActorGuildfbInfo(actor)
	--2.设置公会相关信息
	local guild     = LActor.getGuildPtr(actor)
	if not guild then return end
	local var  = getGuildfbVar(guild)

	local actorid   = LActor.getActorId(actor)    
	--2.1 公会成员的通关排名
	addGuildfbRank(guild, actorid, Info.wave)
	--2.2 每关通关人数
	var.wavePass[Info.wave] = (var.wavePass[Info.wave] or 0) + 1     
	--2.3 记录每天每关前5名通关玩家
	setDayWavePassRecord(guild, actor, Info.wave)
	setGuildDayAward(guild)
	--给予奖励
	giveWaveAward(actor, Info.wave)
	--通知客户端3秒后刷下一波
	local maxWave = guildfbconfig.waveMax or 0
	if Info.wave >= maxWave then return end
	noticeGuildfbNextWave(actor, Info.wave)
end
insevent.regCustomFunc(guildfbconfig.fbId, KillMonGroup, "KillMonGroup")

--怪物创建
local function onMonsterCreater(ins, mon)
	local monid = Fuben.getMonsterId(mon)
	if monid == guildfbconfig.gateId then   --城门怪
		Fuben.setMonsterCamp(mon, CampType_Player)
	else                                    --关卡怪
		local guildId = ins.data.guildId
		if not guildId then return end

		--获取当前关的通关人数
		local wave = ins["wave"]
		if not wave then return end

		local passNum = 0
		local guild = LGuild.getGuildById(guildId)
		if not guild then return end
		local var = getGuildfbVar(guild)

		if var.wavePass and var.wavePass[wave] then
			passNum = var.wavePass[wave]
		end

		--设置怪物属性
		if passNum > 0 then
			local rate = passNum * guildfbconfig.attrParam
			if rate > guildfbconfig.maxAttr then
				rate = guildfbconfig.maxAttr
			end
			Fuben.setBaseAttr(mon, 1 - rate)
		end
	end
end
insevent.registerInstanceMonsterCreate(guildfbconfig.fbId, onMonsterCreater)

--进入副本
local function onGuildfbEnter(ins, actor)
	local guild = LActor.getGuildPtr(actor)
	if not guild then return end

	--该波的剩余时间
	noticeGuildfbWaveTime(ins, actor)

	--助威效果
	local actorId = LActor.getActorId(actor)
	local var = getGuildfbVar(guild)
	if var.dayTop.actorId ~= actorId then return end
	if not var.cheerNum or var.cheerNum <= 0 then return end

	local Num = var.cheerNum or 0
	if Num > #guildfbconfig.cheerEffect then
		Num = #guildfbconfig.cheerEffect
	end

	local cheerEffect = guildfbconfig.cheerEffect[Num]
	if not cheerEffect then return end
	for i = 1, #cheerEffect do
		LActor.addEffect(actor, cheerEffect[i])
	end
	--print("set cheerEffect")
end
insevent.registerInstanceEnter(guildfbconfig.fbId, onGuildfbEnter)

--副本胜利
local function onGuildfbWin(ins)
	local actor = ins:getActorList()[1]
	if not actor then return end
	instancesystem.setInsRewards(ins, actor, nil)
end
insevent.registerInstanceWin(guildfbconfig.fbId, onGuildfbWin)

--副本失败
local function onGuildfbLose(ins)
	local actor = ins:getActorList()[1]
	if actor == nil then return end
	instancesystem.setInsRewards(ins, actor, nil)
end
insevent.registerInstanceLose(guildfbconfig.fbId, onGuildfbLose)


--------------------响应玩家请求------------------
--请求关卡排名
local function onQueryRank(actor)
	local guild = LActor.getGuildPtr(actor)
	if not guild then return end

	local rank = getGuildfbRank(guild)
	if not rank then return end

	local len = Ranking.getRankItemCount(rank)      
	if len > guildfbconfig.rankShowMax then
		len = guildfbconfig.rankShowMax
	end

	local rankTbl = Ranking.getRankingItemList(rank, len)
	if not rankTbl then
		rankTbl = {}
		len     = 0
	end 

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Guildfb, Protocol.sGuildfbCmd_Rank)
	if not pack then return end

	LDataPack.writeByte(pack, len)
	for i = 1, len do
		local item    = rankTbl[i]
		local actorid = Ranking.getId(item)
		local name = LGuild.getMemberInfo(guild, actorid)
		LDataPack.writeString(pack, name)
		LDataPack.writeWord(pack, Ranking.getPoint(item))
	end
	LDataPack.flush(pack)
end
netmsgdispatcher.reg(Protocol.CMD_Guildfb, Protocol.cGuildfbCmd_Rank, onQueryRank)

--请求昨日最高通关
local function onQueryTop(actor)
	local guild = LActor.getGuildPtr(actor)
	if not guild then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Guildfb, Protocol.sGuildfbCmd_DayTop)
	if not pack then return end

	local var = getGuildfbVar(guild)
	if not var.dayTop.actorId then
		LDataPack.writeByte(pack, 0)
	else
		LDataPack.writeByte(pack, 1)
		local name, _, job, _, _, sex = LGuild.getMemberInfo(guild, var.dayTop.actorId)
		LDataPack.writeString(pack, name or " ")
		LDataPack.writeByte(pack, job or 1)
		LDataPack.writeByte(pack, sex or 0)
		LDataPack.writeWord(pack, var.dayTop.wave)
		LDataPack.writeByte(pack, var.cheerNum or 0)
	end
	LDataPack.flush(pack)
end
netmsgdispatcher.reg(Protocol.CMD_Guildfb, Protocol.cGuildfbCmd_DayTop, onQueryTop)

--请求某关卡的通关玩家
local function onQueryPass(actor, reader)
	local wave = LDataPack.readWord(reader)
	if wave <= 0 then return end

	local guild = LActor.getGuildPtr(actor)
	if not guild then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Guildfb, Protocol.sGuildfbCmd_WavePass)
	if not pack then return end
	LDataPack.writeWord(pack, wave)

	local var = getGuildfbVar(guild)
	local len = 0
	if var.daywavePass[wave] and #var.daywavePass[wave] > 0 then
		len = #var.daywavePass[wave]
	end

	LDataPack.writeByte(pack, len)
	for i = 1, len do
		local data = var.daywavePass[wave][i] 
		if data then
			LDataPack.writeString(pack, data.name)
		end
	end
	LDataPack.flush(pack)
end
netmsgdispatcher.reg(Protocol.CMD_Guildfb, Protocol.cGuildfbCmd_WavePass, onQueryPass)

--挑战公会副本
local function onChallenge(actor)
	if System.getOpenServerDay() + 1 < (guildfbconfig.openDay or 0) then return end

	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then return end

	local Info    = getActorGuildfbVar(actor)
	local wave    = (Info.wave or 0) + 1
	local maxWave = 0
	local fbConfig = InstanceConfig[guildfbconfig.fbId]
	if fbConfig and fbConfig.templateConfig and fbConfig.templateConfig.maxWave then 
		maxWave = fbConfig.templateConfig.maxWave
	end

	if wave > maxWave then return end

	local hfuben = Fuben.createFuBen(guildfbconfig.fbId)
	if hfuben == 0 then
		print("create guildfb failed. fbId:"..guildfbconfig.fbId)
		return
	end

	local ins = instancesystem.getInsByHdl(hfuben)
	if not ins then return end
	ins.data.did     = guildfbconfig.id
	ins.data.guildId = guildId
	ins:onSetCustomVariable("wave", wave)

	LActor.enterFuBen(actor, hfuben)

	--local Info = getActorGuildfbVar(actor)
	--local wave = Info.wave or 1
	noticeGuildfbNextWave(actor, wave)
end
netmsgdispatcher.reg(Protocol.CMD_Guildfb, Protocol.cGuildfbCmd_Challenge, onChallenge)

--扫荡
local function onSweep(actor)
	--print("onSweep")
	local guild = LActor.getGuildPtr(actor)
	if not guild then return end

	local Info = getActorGuildfbVar(actor)
	local sweepWave = (Info.sweep or 0) + 1
	if Info.finishsweep > 0 then return end
	if not Info.wave or Info.wave <= 0 then return end 
	if sweepWave > Info.wave then return end

	--给予奖励
    if not giveSweepAward(actor, sweepWave, Info, sweepWave == Info.wave) then return end
    
    Info.sweep = sweepWave
	--记录每天每关前5名通关玩家
	setDayWavePassRecord(guild, actor, Info.sweep)
	setGuildDayAward(guild)
    sendActorGuildfbInfo(actor)
end
netmsgdispatcher.reg(Protocol.CMD_Guildfb, Protocol.cGuildfbCmd_Sweep, onSweep)

--助威
local function onCheer(actor)
	local guild = LActor.getGuildPtr(actor)
	if not guild then return end

	local Info = getActorGuildfbVar(actor)
	if not Info.wave or Info.wave <= 0 then return end 
	if Info.cheer   and Info.cheer > 1 then return end

	local var = getGuildfbVar(guild)
	if not var.dayTop or not var.dayTop.actorId then return end 
	var.cheerNum = (var.cheerNum or 0) + 1

	Info.cheer = (Info.cheer or 0) + 1
	sendActorGuildfbInfo(actor)
	noticeGuildfbInfoChange(guild, 2)
end
netmsgdispatcher.reg(Protocol.CMD_Guildfb, Protocol.cGuildfbCmd_Cheer, onCheer)

--领取全民每日福利
local function onGetWelfare(actor)
	local guild = LActor.getGuildPtr(actor)
	if not guild then return end

	local Info = getActorGuildfbVar(actor)
	if Info.welfare and Info.welfare > 1 then return end

	local var = getGuildfbVar(guild) 
	if not var.dayAward.level then return end

	if LActor.getEquipBagSpace(actor) < (guildfbconfig.needSpace or 0) then
		LActor.sendTipmsg(actor, guildfbconfig.noticefullex or " ", 2)
		return
	end 

	local hitFive, hitOne
	for i = var.dayAward.level, 1, -1 do 
		if hitFive and hitOne then break end

		local Awards = guildfbDayAwardConfig[i]
		if not Awards then return end

		local wave = guildfbDayAwardConfig[i].wave
		local num = 0
		if var.daywavePass[wave] then
			num = #var.daywavePass[wave]
		end

		local awardId,rewards
		if not hitFive and num >= guildfbconfig.dayRecordMax then
			--print("get five")
			awardId = Awards.awardex
			hitFive = true
			rewards = drop.dropGroup(awardId)
			if rewards then
				LActor.giveAwards(actor, rewards, "guildfb dayAward")
			end
		end
		
		if not hitOne and num > 0 then
			--print("get one")
			awardId = Awards.award
			hitOne = true
			rewards = drop.dropGroup(awardId)
			if rewards then
				LActor.giveAwards(actor, rewards, "guildfb dayAward")
			end
		end 
		

		-- if not LActor.canGiveAwards(actor, rewards) then --发邮件
		-- 	local Title = guildfbconfig.dayTitle or "guildfb dayAward"
		-- 	local Context = guildfbconfig.dayContext or "guildfb dayAward"
		-- 	local mailData = {
		-- 		head      = Title, 
		-- 		context   = Context, 
		-- 		tAwardList= rewards
		-- 	}
		-- 	mailsystem.sendMailById(LActor.getActorId(actor), mailData)
		-- else                                             --直接给奖励
		--	LActor.giveAwards(actor, rewards, "guildfb dayAward")
    	-- end 
    end
	Info.welfare = (Info.welfare or 0) + 1
	sendActorGuildfbInfo(actor)
end
netmsgdispatcher.reg(Protocol.CMD_Guildfb, Protocol.cGuildfbCmd_Welfare, onGetWelfare)

--------------------事件触发------------------
--玩家登录
local function onLogin(actor)
	sendActorGuildfbInfo(actor)
	SendActorDayAward(actor)
end
actorevent.reg(aeUserLogin, onLogin)
--玩家加入公会
local function onJoninGuild(actor, guild)
	local var = getGuildfbVar(guild)

	local Info      = getActorGuildfbVar(actor)
	local actorId   = LActor.getActorId(actor) 

	if Info.wave and Info.wave > 0 then 
		--加入通关排名
		addGuildfbRank(guild, actorId, Info.wave)
		--增加每关通关的人数
		for i = 1, Info.wave do
			var.wavePass[i] = (var.wavePass[i] or 0) + 1
		end
	end 
	sendActorGuildfbInfo(actor)
	SendActorDayAward(actor)
end
actorevent.reg(aeJoinGuild, onJoninGuild)

--玩家离开公会
local function onLeaveGuild(actor, guildId)
	local guild  = LGuild.getGuildById(guildId)
	if not guild then return end

	local var     = getGuildfbVar(guild)
	local actorId = LActor.getActorId(actor) 
	--移除通关排名
	local rank = getGuildfbRank(guild)
	if not rank then return end 
	local oldrank = Ranking.getItemIndexFromId(rank, actorId)
	Ranking.removeId(rank, actorId)
	if oldrank >= 0 and oldrank < guildfbconfig.rankShowMax then
		noticeGuildfbInfoChange(guild, 1)
	end
	--减少每关通关人数
	local Info = getActorGuildfbVar(actor)
	if Info.wave then
		for i = 1, Info.wave do
			if var.wavePass[i] then
				var.wavePass[i] = var.wavePass[i] - 1
			end
		end
	end
	--移除昨天最高通关人
	if var.dayTop.actorId == actorId then
		var.dayTop = {}
		noticeGuildfbInfoChange(guild, 2)
	end
end
actorevent.reg(aeLeftGuild, onLeaveGuild)

--公会每天清空
function clearGuildfbVar(guild)
	local var = getGuildfbVar(guild)
		
	--获取昨日最高通关
	var.dayTop = {}
	local topWave = var.dayTopWave
	local topList = var.daywavePass[topWave]
	if topList then
		for i = 1, #topList do
			if LGuild.getMemberInfo(guild, topList[i].actorId) then
				var.dayTop.actorId = topList[i].actorId
				var.dayTop.wave    = topWave
				break
			end
		end
	end
	--重置每天数据
	var.daywavePass   = {}
	var.dayAward      = {}
	var.cheerNum      = 0
	var.dayTopWave    = 0
	noticeGuildfbInfoChange(guild, 2)
	noticeGuildfbDayAward(guild)
end

--玩家每天清空
local function onDayActorClean(actor)
	local Info = getActorGuildfbVar(actor)
	Info.sweep   = 0
	Info.welfare = 0
	Info.daywave = 0
 	Info.cheer   = 0
 	Info.finishsweep  = 0
 	sendActorGuildfbInfo(actor)
end
actorevent.reg(aeNewDayArrive, onDayActorClean)

--玩家改名
function ChangeNameOnGuildfb(actor, name)
	local guild = LActor.getGuildPtr(actor)
	if not guild then return end
	local rank = getGuildfbRank(guild)
	if not rank then return end

	local actorId = LActor.getActorId(actor)
	local Index = Ranking.getItemIndexFromId(rank, actorId)

	if Index < guildfbconfig.rankShowMax then
		noticeGuildfbInfoChange(guild, 1)
	end 

	local var = getGuildfbVar(guild)
	if var.dayTop and var.dayTop.actorId == acotrId then
		noticeGuildfbInfoChange(guild, 2)
	end
end

-------------------gm命令-------------------------
local gmsystem      = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.clearguildfb = function(actor, args)
	local Info   = getActorGuildfbVar(actor)
	Info.wave    = 0
	Info.daywave = 0    
	Info.sweep   = 0
	Info.finishsweep = 0
	Info.welfare = 0
	Info.cheer   = 0
	sendActorGuildfbInfo(actor)
end

gmCmdHandlers.clearSweep = function(actor, args)
	local Info   = getActorGuildfbVar(actor)
	Info.sweep   = 0
	Info.finishsweep = 0
	sendActorGuildfbInfo(actor)
end

gmCmdHandlers.guildfbday = function(actor)
	local guild = LActor.getGuildPtr(actor)
	if not guild then return end
	clearGuildfbVar(guild)
end

gmCmdHandlers.guildfb = function(actor, args)
	onChallenge(actor)
end

gmCmdHandlers.guildfbrank = function(actor, args)
	onQueryRank(actor)
end
gmCmdHandlers.guildfTop = function(actor, args)
	onQueryTop(actor)
end
gmCmdHandlers.guildfbSweep = function(actor, args)
	onSweep(actor)
end
gmCmdHandlers.guildfbCheer= function(actor, args)
	onCheer(actor)
end
gmCmdHandlers.guildfbWelfare = function(actor, args)
	onGetWelfare(actor)
end

gmCmdHandlers.sendInfo = function(actor, args)
	sendActorGuildfbInfo(actor)
end

