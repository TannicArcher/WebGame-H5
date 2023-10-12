--公会boss
module("guildboss", package.seeall)

--获取玩家静态变量
local function getData(actor)
    local var = LActor.getStaticVar(actor)
    if nil == var.guildboss then
        var.guildboss = {}
    end
    return var.guildboss
	--[[玩家变量结构定义
		{
			enter_times = 0, --挑战次数
			refresh_time = 0,--最近一次记录的活动刷新时间
			rec_pass_award = {}, --已经领取通关奖励 [关卡ID]=true
		}
	]]
end

--获取全局静态变量
local function getGlobalData()
	local var = System.getStaticVar()
	if var == nil then 
		return nil
	end
	if var.guild_boss == nil then 
		var.guild_boss = {}
	end
	return var.guild_boss
	--[[ 结构定义 gvar = 全局数据
		refresh_time = 0,--活动刷新时间
		monday_time = 0, 周一的时间戳
		g[工会ID] = { var = 公会数据
			match_gid = 0,--匹配到的对手公会ID
			match_bid = 1, --匹配对手的时候,所在的关卡id
			winGuildId = 0, --于对手PK,赢的一方的公会id
			
			pass_id = 0, --通关到第几个关卡
			fbHandle = 0, --当前副本句柄
			change_level_time = 0,--更换关卡的时间
			rank_reward_level = 0,--排名奖励发放到第几关
			list[关卡ID] = { gdata = 关卡数据
				boss_hurt = 0, --boss已经受到的伤害
				update_time = 0,--最近一次的更新时间
				hprand_reward = {--血量对应的随机奖励,配置索引对应剩余次数
					[idx]=>times
				}
				damagelist = { --伤害列表
					[actorid] = {name, damage}
				},
				damagerank = { --伤害排名
					{id, name,damage}[]
				}
			}
		}
		gr[关卡ID] = { grd = 每个关卡的公会排名
			{id=公会ID, name=公会名, damage=伤害, update_time=最近一次的更新时间}
		}
	]]
end

--获取公会的全局变量
local function getGuildGlobalData(guild_id)
	--if type(guild_id) == "userdata" then --先判断一段时间
	--	print(debug.traceback("getGuildGlobalData,Stack trace"))
	--	assert(false)
	--end
	local var = getGlobalData()
	if var == nil then
		return nil
	end
	if var.g == nil then
		var.g = {}
	end
	if var.g[guild_id] == nil then
		var.g[guild_id] = {}
	end
	if var.g[guild_id].list == nil then
		var.g[guild_id].list = {}
	end
	return var.g[guild_id]
end

--下发基本信息
local function sendBaseInfo(actor)
	local avar = getData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBoss, Protocol.sGuildBossCmd_BaseInfo)
	if nil == npack then return end
	local left_times = GuildBossConfig.dayTimes - (avar.enter_times or 0)
	if left_times < 0 then left_times = 0 end
	LDataPack.writeInt(npack, left_times)
	LDataPack.writeByte(npack, #GuildBossInfoConfig)
	for _,v in pairs(GuildBossInfoConfig) do
		--获取状态
		local rec_status = 0 --默认不可令
		local guild_id = LActor.getGuildId(actor)
		if guild_id ~= 0 then
			--获取公会变量
			local var = getGuildGlobalData(guild_id)
			--判断是否通关
			if (var.pass_id or 0) >= v.id then
				rec_status = 1 --可领
			end
			if avar.rec_pass_award and avar.rec_pass_award[v.id] then
				rec_status = 2 --已经领取
			end
		end
		--写包
		LDataPack.writeByte(npack, v.id)
		LDataPack.writeByte(npack, rec_status)
	end
	if System.getDayOfWeek() == GuildBossConfig.notOpenDayOfWeek then
		LDataPack.writeChar(npack, 0)
	else
		LDataPack.writeChar(npack, 1)
	end
	LDataPack.flush(npack)
end

--公会BOSS的扫荡血量 =  三职业攻击力总和*1.1 * 30 / 0.8 
local function getRadisSubHp(actor)
	local allAtk = LActor.getAtkSum(actor)
	return math.floor(allAtk * 1.1 * 30 / 0.8)
end

--检测并创建副本
local function checkEnterAndCreateFuBen(actor, enter_type)
	--判断活动是否开启
	if System.getDayOfWeek() == GuildBossConfig.notOpenDayOfWeek then
		print("reqEnterGuildBoss: actor("..LActor.getActorId(actor)..") guild is not open")
		return 1
	end
	--获取公会ID
	local guild_id = LActor.getGuildId(actor)
	if guild_id == 0 then
		print("reqEnterGuildBoss: actor("..LActor.getActorId(actor)..") is not have guild")
		return 2
	end
	local guild = LGuild.getGuildById(guild_id)
	if guild == nil then
		print("reqEnterGuildBoss: actor("..LActor.getActorId(actor)..") is not have guild ptr")
		return 2
	end
	--获取挑战次数是否用完
	local avar = getData(actor)
	if (avar.enter_times or 0) >= GuildBossConfig.dayTimes then
		print("reqEnterGuildBoss: actor("..LActor.getActorId(actor)..") not have enter times")
		return 3
	end
	--获取公会变量
	local var = getGuildGlobalData(guild_id)
	--判断是否全部通关
	if (var.pass_id or 0) >= #GuildBossInfoConfig then
		print("reqEnterGuildBoss: actor("..LActor.getActorId(actor)..")guild_id("..guild_id..") is over")
		return 4
	end
	--判断是否有人正在挑战
	if var.fbHandle and var.fbHandle > 0 then
		print("reqEnterGuildBoss: actor("..LActor.getActorId(actor)..")guild_id("..guild_id..") is have fbHandle")
		return 5
	end
	--获取当前要打关卡的配置
	local gid = (var.pass_id or 0)+1 --当次要打的关卡ID
	local conf = GuildBossInfoConfig[gid]
	if not conf then
		print("reqEnterGuildBoss: actor("..LActor.getActorId(actor)..")guild_id("..guild_id..") gid("..gid..") is not have config")
		return 6
	end
	local data = {conf=conf, guild_id=guild_id}

	--公会达到指定等级,直接扫荡 start
	if GuildBossConfig.radisLv and guildcommon.getGuildLevel(guild) >= GuildBossConfig.radisLv and (enter_type or 0) == 1 then 
		if not var.list[conf.id] then var.list[conf.id] = {} end
		local gdata = var.list[conf.id]
		--增加挑战次数
		avar.enter_times = (avar.enter_times or 0) + 1
		--减少所有的特殊奖励次数
		if gdata and gdata.hprand_reward then
			local hpAwardCfg = GuildBossHpAwardsConfig[conf.id]
			for idx,val in pairs(hpAwardCfg or {}) do
				if gdata.hprand_reward[idx] and gdata.hprand_reward[idx] > 0 then
					gdata.hprand_reward[idx] = gdata.hprand_reward[idx] - 1
				end
			end
		end
		--扣血
		--公会BOSS的扫荡血量 =  三职业攻击力总和*1.1 * 30 / 0.8 
		local sub_hp = getRadisSubHp(actor)
		local hurt = (var.list[conf.id].boss_hurt or 0) + sub_hp
		var.list[conf.id].boss_hurt = hurt
		--判断boss是否死了
		local mon_hp = MonstersConfig[conf.boss.monId] and MonstersConfig[conf.boss.monId].hp or 0
		--伤害列表更新
		if not gdata.damagelist then gdata.damagelist = {} end
		local aid = LActor.getActorId(actor)
		if not gdata.damagelist[aid] then gdata.damagelist[aid] = {} end
		gdata.damagelist[aid].name = LActor.getName(actor)
		gdata.damagelist[aid].damage = (gdata.damagelist[aid].damage or 0) + sub_hp
		if gdata.damagelist[aid].damage > mon_hp then gdata.damagelist[aid].damage = mon_hp end
		--更新一下伤害排名
		updateRank(data)
		--发放奖励
		sendGuldBossFbReward(data, actor, gdata.damagelist[aid].damage >= mon_hp)
		if mon_hp <= hurt then --怪物死亡后
			var.pass_id = conf.id --记录通关的副本
			var.fbHandle = nil --重设正在挑战的副本handle
			var.change_level_time = System.getNowTime() --记录更换关卡的时间
			--设置公会输赢
			if var.match_gid and not var.winGuildId and var.match_bid == var.pass_id then
				local m_var = getGuildGlobalData(var.match_gid)
				m_var.winGuildId = guild_id --对方设置为我赢
				var.winGuildId = guild_id --我方也设置为我赢
			end
		end
		--广播基本消息到公会成员
		local actors = LGuild.getOnlineActor(guild_id) or {}
		for i = 1,#actors  do
			print("checkEnterAndCreateFuBen Raids sendBaseInfo to aid:"..LActor.getActorId(actors[i]))
			sendBaseInfo(actors[i])
		end
		actorevent.onEvent(actor, aeEnterFuben, conf.fbId, false)
		return 99
	end
	--公会达到指定等级,直接扫荡 end

	--创建一个副本;让他进去
	var.fbHandle = Fuben.createFuBen(conf.fbId)
	local ins = instancesystem.getInsByHdl(var.fbHandle)
	if ins then
		ins.data = data
	else
		print("reqEnterGuildBoss: actor("..LActor.getActorId(actor)..")guild_id("..guild_id..") gid("..gid..") is createFuBen failure")
		var.fbHandle = nil
		return 7
	end
	--刷boss出来
	local monster = Fuben.createMonster(ins.scene_list[1], conf.boss.monId, conf.boss.posX, conf.boss.posY, conf.boss.liveTime or 0)
	if monster then
		--更新血量
		if var.list[conf.id] and var.list[conf.id].boss_hurt then
			local hp = LActor.getHpMax(monster)
			hp = hp - var.list[conf.id].boss_hurt
			if hp <= 0 then hp = 1 end
			LActor.setHp(monster, hp)
		end
	else
		return 8
	end
	return 0,var,avar,conf
end

--请求挑战公会boss
local function reqEnterGuildBoss(actor, packet)
	local enter_type = LDataPack.readChar(packet)
	local ret,var,avar,conf = checkEnterAndCreateFuBen(actor, enter_type) --进入成功
	if ret == 0 then
		--进入副本
		LActor.enterFuBen(actor, var.fbHandle)
		--增加挑战次数
		avar.enter_times = (avar.enter_times or 0) + 1
		--减少所有的特殊奖励次数
		local gdata = var.list[conf.id]
		if gdata and gdata.hprand_reward then
			local hpAwardCfg = GuildBossHpAwardsConfig[conf.id]
			for idx,val in pairs(hpAwardCfg or {}) do
				if gdata.hprand_reward[idx] and gdata.hprand_reward[idx] > 0 then
					gdata.hprand_reward[idx] = gdata.hprand_reward[idx] - 1
				end
			end
		end
		--判断是否需要添加特殊效果
		if GuildBossConfig.effid then
			local gvar = getGlobalData()
			local last_time = var.change_level_time or gvar.monday_time
			if last_time and not System.isSameDay(last_time, System.getNowTime()) then
				for roleId = 0,LActor.getRoleCount(actor) - 1 do
					local role = LActor.getRole(actor, roleId)
					LActor.addSkillEffect(role, GuildBossConfig.effid)
				end
			end
		end
	end
	--给客户端回应进入副本结果
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBoss, Protocol.sGuildBossCmd_EnterRet)
	if nil == npack then return end
	LDataPack.writeInt(npack, ret)
	LDataPack.flush(npack)
end

--请求领取通关奖励
local function reqReceivePassReward(actor, packet)
	local idx = LDataPack.readInt(packet) --获取第几关的奖励
	if idx <= 0 or idx > #GuildBossInfoConfig then
		return
	end
	--获取公会ID
	local guild_id = LActor.getGuildId(actor)
	if guild_id == 0 then
		print("reqReceivePassReward: actor("..LActor.getActorId(actor)..") is not have guild")
		return
	end
	--获取配置
	local conf = GuildBossInfoConfig[idx]
	if not conf then 
		print("reqReceivePassReward: actor("..LActor.getActorId(actor)..") idx("..tostring(idx)..") is not have config")
		return 
	end
	--获取玩家静态变量
	local avar = getData(actor)
	--判断是否已经领取过奖励
	if avar.rec_pass_award and avar.rec_pass_award[idx] then
		print("reqReceivePassReward: actor("..LActor.getActorId(actor)..") idx("..tostring(idx)..") is has rec")
		return
	end
	--获取公会变量
	local var = getGuildGlobalData(guild_id)
	--判断公会是否已经通关这个
	if (var.pass_id or 0) < conf.id then
		print("reqReceivePassReward: actor("..LActor.getActorId(actor)..") idx("..tostring(idx)..") not pass("..tostring(var.pass_id)..")")
		return
	end
	--发放奖励
	if LActor.canGiveAwards(actor, conf.passAwards) then
		LActor.giveAwards(actor, conf.passAwards, "guildboss pass reward")
		--记录已经领取奖励
		if not avar.rec_pass_award then
			avar.rec_pass_award = {}
		end
		avar.rec_pass_award[idx] = true
	end
	sendBaseInfo(actor)
end

--发放奖励
function sendGuldBossFbReward(data, actor, isWin)
	--判断活动是否开启
	if System.getDayOfWeek() == GuildBossConfig.notOpenDayOfWeek then
		return
	end
	--获取公会ID
	local guild_id = LActor.getGuildId(actor)
	if guild_id == 0 then
		print("sendGuldBossFbReward: actor("..LActor.getActorId(actor)..") is not have guild")
		return
	end
	--是否在副本中退出公会
	if guild_id ~= data.guild_id then
		return
	end
	local conf = GuildBossInfoConfig[data.conf.id]
	if not conf then
		return
	end
	--获取公会变量
	local var = getGuildGlobalData(guild_id)
	local reward = {} --收集奖励
	--参与奖励
	for _,v in ipairs(drop.dropGroup(conf.enterAwards) or {}) do
		table.insert(reward, v)
	end
	--特殊奖励
	local gdata = var.list and var.list[conf.id]
	if gdata and gdata.hprand_reward then
		local hpAwardCfg = GuildBossHpAwardsConfig[conf.id]
		for idx,val in pairs(hpAwardCfg or {}) do
			--有数据,并且还没领取过
			if gdata.hprand_reward[idx] and gdata.hprand_reward[idx] ~= -1 then
				if gdata.hprand_reward[idx] == 0 or isWin then --到达可领状态,或者已经赢了
					gdata.hprand_reward[idx] = -1 --已经领取过
					for _,v in ipairs(val.awards) do
						table.insert(reward, v)
					end
				end
			end
		end
	end
	--击杀奖励
	if isWin and isWin == true then
		for _,v in ipairs(conf.killerAwards) do
			table.insert(reward, v)
		end		
	end
	--发放奖励
	LActor.giveAwards(actor, reward, "guildboss reward")
	data.isRecAwards = true
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBoss, Protocol.sGuildBossCmd_Result)
	if nil == npack then return end
	LDataPack.writeChar(npack, isWin and 1 or 0)
	LDataPack.writeInt(npack, #reward)
	for k,v in ipairs(reward) do
		--写入奖励
		LDataPack.writeData(npack, 3,
			dtInt, v.type or 0,
			dtInt, v.id or 0,
			dtInt, v.count or 0
		)
	end
	LDataPack.flush(npack)
end

local function updateGuildRank(cid)
	local gvar = getGlobalData()
	if not gvar.gr then gvar.gr = {} end
	gvar.gr[cid] = {}
	local grd = gvar.gr[cid]
	if gvar.g then
		for guildId,var in pairs(gvar.g) do
			local gdata = var.list[cid]
			if gdata then
				if gdata.boss_hurt and gdata.boss_hurt > 0 and gdata.update_time and gdata.update_time > 0 then
					table.insert(grd, {
						id=guildId, 
						name=LGuild.getGuildName(LGuild.getGuildById(guildId)), 
						damage=gdata.boss_hurt,
						update_time=gdata.update_time
					})
				end
			end
		end
	end
    table.sort(grd, function(a,b)
		if a.damage == b.damage then
			return a.update_time < b.update_time
		end
        return a.damage > b.damage
    end)	
end

function updateRank(data)
	--获取公会变量
	local var = getGuildGlobalData(data.guild_id)
	if not var.list[data.conf.id] then
		var.list[data.conf.id] = {}
	end
	--关卡数据
	local gdata = var.list[data.conf.id]
	if not gdata.damagelist then return end
	gdata.damagerank = {}
	for aid, v in pairs(gdata.damagelist) do
        table.insert(gdata.damagerank, {id=aid,name=v.name,damage=v.damage})
    end
    table.sort(gdata.damagerank, function(a,b)
        return a.damage > b.damage
    end)
	--公会排名
	updateGuildRank(data.conf.id)
end

--退出副本的时候
local function onExitFb(ins, actor)
	--更新伤害排行榜
	updateRank(ins.data)
	--发放奖励
	if not ins.data.isRecAwards then
		sendGuldBossFbReward(ins.data, actor, false)
	end
	--获取公会变量
	local var = getGuildGlobalData(ins.data.guild_id)
	var.fbHandle = nil
end

--副本输了
local function onLose(ins)
	--获取公会变量
	local var = getGuildGlobalData(ins.data.guild_id)
	var.fbHandle = nil
end

--公会解散的时候
function onDeleteGuild(guild)
	local gvar = getGlobalData()
	if not gvar.g then return end
	--解散的公会ID
	local dgid = LGuild.getGuildId(guild)
	--获取公会的数据
	local var = gvar.g[dgid]
	if var then
		--遍历所有公会,如果对手是要解散的公会,直接设置掉
		for guildId,var in pairs(gvar.g) do
			if var.match_gid and var.match_gid == dgid then
				var.match_gid = nil
			end
		end
		--需要刷新排行榜的关卡ID
		local needUpdateRankCid = {}
		if var.list then
			for cid,_ in pairs(var.list) do
				table.insert(needUpdateRankCid, cid)
			end
		end
		gvar.g[dgid] = nil
		for _,cid in ipairs(needUpdateRankCid) do
			updateGuildRank(cid)
		end
	end
end

--boss受到伤害的时候
local function onBossDamage(ins, monster, value, attacker, res) 
	--获取公会变量
	local var = getGuildGlobalData(ins.data.guild_id)
	if not var.list[ins.data.conf.id] then
		var.list[ins.data.conf.id] = {}
	end
	--关卡数据
	local gdata = var.list[ins.data.conf.id]
	--累加伤害
	gdata.boss_hurt = (gdata.boss_hurt or 0) + value
	if gdata.boss_hurt > LActor.getHpMax(monster) then
		gdata.boss_hurt = LActor.getHpMax(monster)
	end
	gdata.update_time = System.getNowTime()
	--伤害列表更新
	if not gdata.damagelist then
		gdata.damagelist = {}
	end
	local attacker_actor = LActor.getActor(attacker)
	if attacker_actor then
		local aid = LActor.getActorId(attacker_actor)
		if not gdata.damagelist[aid] then
			gdata.damagelist[aid] = {}
		end
		gdata.damagelist[aid].name = LActor.getName(attacker_actor)
		--print("onBossDamage, attacker name:"..LActor.getName(attacker_actor))
		gdata.damagelist[aid].damage = (gdata.damagelist[aid].damage or 0) + value
		if gdata.damagelist[aid].damage > LActor.getHpMax(monster) then
			gdata.damagelist[aid].damage = LActor.getHpMax(monster)
		end
	end
	--求剩余血量百分比
	local hp_per = LActor.getHp(monster)/LActor.getHpMax(monster)*100
	local hpAwardCfg = GuildBossHpAwardsConfig[ins.data.conf.id]
	if gdata.hprand_reward == nil then
		gdata.hprand_reward = {}
	end
	for idx,val in pairs(hpAwardCfg or {}) do
		if val.hpPer >= hp_per  then
			if gdata.hprand_reward[idx] ~= -1 then
				gdata.hprand_reward[idx] = math.random(val.randTimes[1],val.randTimes[2])
			end
		end
	end
end

--怪物死亡的时候
local function onMonsterDie(ins, mon, killerHdl)
	local monid = Fuben.getMonsterId(mon)
	if ins.data.conf.boss.monId ~= monid then
		print("guildboss.onMonsterDie:monid("..tostring(monid)..") ~= bossId("..tostring(ins.data.conf.boss.monId).."), id:"..(ins.data.conf.id))
		return
	end
	--获取公会变量
	local var = getGuildGlobalData(ins.data.guild_id)
	var.pass_id = ins.data.conf.id --记录通关的副本
	var.fbHandle = nil --重设正在挑战的副本handle
	var.change_level_time = System.getNowTime() --记录更换关卡的时间
	--发放奖励
	local et = LActor.getEntity(killerHdl)
	local actor = LActor.getActor(et)
	sendGuldBossFbReward(ins.data, actor, true)
	--更新一下伤害排名
	updateRank(ins.data)
	--设置公会输赢
	if var.match_gid and not var.winGuildId and var.match_bid == var.pass_id then
		local m_var = getGuildGlobalData(var.match_gid)
		m_var.winGuildId = ins.data.guild_id --对方设置为我赢
		var.winGuildId = ins.data.guild_id --我方也设置为我赢
	end
	ins:win()
	--广播基本消息到公会成员
	local actors = LGuild.getOnlineActor(ins.data.guild_id) or {}
	for i = 1,#actors  do
		print("onMonsterDie sendBaseInfo to aid:"..LActor.getActorId(actors[i]))
		sendBaseInfo(actors[i])
	end
end

--尝试重置领取通关奖励
local function clearPassAwardRec(actor)
	local avar = getData(actor)
	local gvar = getGlobalData()
	if avar.refresh_time ~= gvar.monday_time then
		avar.refresh_time = gvar.monday_time
		avar.rec_pass_award = nil
		sendBaseInfo(actor)
	end
end

--新的一天到来
local function onNewDay(actor)
	--清空挑战次数
	local avar = getData(actor)
	avar.enter_times = nil
	clearPassAwardRec(actor)
	sendBaseInfo(actor)
end

--登陆的时候
local function onLogin(actor)
	clearPassAwardRec(actor)
	sendBaseInfo(actor)
end

--发放排名邮件奖励
local function SendGuildBossRankMailReward(rank_data, conf)
	if not rank_data then return end
	if not conf.awards then return end
	local mailData = {head=conf.mail_head, context=conf.mail_content, tAwardList=conf.awards }
	mailsystem.sendMailById(rank_data.id, mailData)
end

--发放排名奖励通过关卡数据
local function SendGuildBossRankRewardByLevel(gdata)
	if not gdata then return end
	if not gdata.damagerank then return end
	local BottomCfg = nil
	local maxRank = 0
	for _,cfg in ipairs(GuildBossRankConfig or {}) do
		if cfg.srank == 0 and cfg.erank == 0 then
			BottomCfg = cfg
		else
			for rank = cfg.srank, cfg.erank do
				if maxRank < rank then maxRank = rank end
				if rank > #gdata.damagerank then break end
				local rank_data = gdata.damagerank[rank]
				--发送邮件奖励
				SendGuildBossRankMailReward(rank_data, cfg)
			end
		end
	end
	if BottomCfg and maxRank < #gdata.damagerank then
		for rank = maxRank+1,#gdata.damagerank do
			local rank_data = gdata.damagerank[rank]
			SendGuildBossRankMailReward(rank_data, BottomCfg)
		end
	end
end

--发放所有公会的排名奖励
local function SendGuildBossRankReward()
	local gvar = getGlobalData()
	if not gvar.g then return end
	for guild_id, var in pairs(gvar.g) do
		--判断通关的关卡要比已经领取的关卡大
		if var.pass_id and var.pass_id > (var.rank_reward_level or 0) then
			local start = (var.rank_reward_level or 0)+1
			for level = start,var.pass_id do --发放所有通关的排名
				local gdata = var.list[level]
				SendGuildBossRankRewardByLevel(gdata)
				var.rank_reward_level = level --记录奖励排名已经发放关卡
			end
		end
	end
end

--根据公会匹配到对手
local function MatchGuildPkGuildOne(guildList, guild, start_i)
	local guild_id = LGuild.getGuildId(guild)
	local var = getGuildGlobalData(guild_id) --公会的变量
	
	for i=start_i,#guildList do
		local mguild = guildList[i] --匹配的公会
		local mguild_id = LGuild.getGuildId(mguild) --匹配的公会ID
		local v = getGuildGlobalData(mguild_id) --公会的变量
		--不要匹配到自己
		if mguild_id ~= guild_id then
			--还没比配到公会的
			if v.match_gid == nil or v.match_gid == 0 then 
				--在同一个关卡的
				if (v.pass_id or 0) == (var.pass_id or 0) then
					--把v和var进行匹配
					v.match_gid = guild_id
					var.match_gid = k
					v.match_bid = (v.pass_id or 0) + 1
					var.match_bid = (v.pass_id or 0) + 1
				end
			end
		end
	end
end

--匹配所有公会对手
local function MatchGuildPkGuild()
	local guildList = LGuild.getGuildList()
	if guildList == nil then return end
	for i=1,#guildList do
		local guild = guildList[i]
		MatchGuildPkGuildOne(guildList, guild, i+1)
	end
end

--公会boss关闭
local function RefreshGuildBoss()
	local gvar = getGlobalData()
	gvar.refresh_time = System.getNowTime()
	--获取是星期几
	local week = System.getDayOfWeek()
	--发放排名奖励
	SendGuildBossRankReward()
	if week == GuildBossConfig.notOpenDayOfWeek then --周日清空记录
		--清空所有记录
		gvar.g = nil
		gvar.gr = nil
	elseif week == 1 then --周一记录第一关的时间
		gvar.monday_time = System.getNowTime()
	else --3,5恢复血量
		--恢复血量
		if gvar.g then
			for k,v in pairs(gvar.g) do
				gdata = v.list[(v.pass_id or 0)+1]
				if gdata then
					gdata.boss_hurt = nil
				end
				v.match_gid = nil --清空匹配到的对手
			end
		end
	end
	--匹配对手,周天就不用匹配了
	if week ~= GuildBossConfig.notOpenDayOfWeek then
		MatchGuildPkGuild()
	end
end
_G.RefreshGuildBoss = RefreshGuildBoss

--请求获取公会BOSS详细信息
local function reqGetAllInfo(actor, packet)
	local gvar = getGlobalData() --全局变量
	--获取公会ID
	local guild_id = LActor.getGuildId(actor)
	if guild_id == 0 then
		print("reqGetAllInfo: actor("..LActor.getActorId(actor)..") is not have guild")
		return
	end
	--获取公会变量
	local var = getGuildGlobalData(guild_id)
	--发包
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBoss, Protocol.sGuildBossCmd_AllInfo)
	if nil == npack then return end
	LDataPack.writeInt(npack, var.pass_id or 0) --当前通关ID
	local ins = var.fbHandle and instancesystem.getInsByHdl(var.fbHandle) or nil
	LDataPack.writeInt(npack, ins and (ins.end_time-System.getNowTime()) or 0) --是否正在有人挑战
	local gdata = var.list[(var.pass_id or 0)+1]
	LDataPack.writeInt(npack, gdata and gdata.boss_hurt or 0) --boss收到的伤害
	local match_gid = var.match_gid or 0 --对手的公会ID
	LDataPack.writeInt(npack, match_gid)
	local match_gname = "" --对手的公会名
	local match_gboss_hurt = 0 --对手的boss伤害
	if match_gid ~= 0 then
		local mvar = getGuildGlobalData(match_gid)
		local guild = LGuild.getGuildById(match_gid)
		if guild then
			match_gname = LGuild.getGuildName(guild)
		end
		local mgdata = mvar.list[var.match_bid]
		if mgdata then
			match_gboss_hurt = mgdata.boss_hurt or 0
		end
	end
	LDataPack.writeString(npack, match_gname)
	LDataPack.writeInt(npack, match_gboss_hurt)
	LDataPack.writeInt(npack, var.winGuildId or 0)
	LDataPack.flush(npack)
end

--获取指定关卡ID的排行榜信息(公会排名和伤害排名)
local function reqGetRankInfo(actor, packet)
	local guild_id = LActor.getGuildId(actor) --获取公会ID
	if guild_id == 0 then
		print("reqGetRankInfo: actor("..LActor.getActorId(actor)..") is not have guild")
		return
	end
	--获取第几关的信息
	local idx = LDataPack.readInt(packet) 
	--获取全局数据
	local gvar = getGlobalData()
	--发包
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBoss, Protocol.sGuildBossCmd_RankInfo)
	if nil == npack then return end 
	LDataPack.writeInt(npack, idx)
	--写入公会排名
	local gcount = 0 --公会排名个数
	if gvar.gr and gvar.gr[idx] then 
		gcount = math.min(#(gvar.gr[idx]), 3)
	end
	LDataPack.writeByte(npack, gcount)
	if gcount > 0 then
		local grd = gvar.gr[idx]
		for i = 1,gcount do
			LDataPack.writeString(npack, grd[i].name)
			LDataPack.writeInt(npack, grd[i].damage)
		end
	end
	--写入个人排名数据
	local pdrank = nil
	local var = gvar.g[guild_id]
	if var then
		local gdata = var.list[idx]
		if gdata and gdata.damagerank then
			pdrank = gdata.damagerank
		end
	end
	if pdrank then
		local guild = LGuild.getGuildById(guild_id)
		LDataPack.writeInt(npack, #pdrank)
		for k,rank_data in ipairs(pdrank) do
			LDataPack.writeString(npack, rank_data.name)
			LDataPack.writeInt(npack, rank_data.damage)
			LDataPack.writeInt(npack, LGuild.GetMemberTotalGx(guild, rank_data.id))
		end		
	else
		LDataPack.writeInt(npack, 0)
	end
	LDataPack.flush(npack)
end

local function onActorDie(ins, actor, killerHdl)
	LActor.exitFuben(actor)
end

--系统初始化函数
local function init()
	--注册玩家事件
	actorevent.reg(aeNewDayArrive, onNewDay)
	actorevent.reg(aeUserLogin, onLogin)
	--副本事件
    for _, conf in pairs(GuildBossInfoConfig) do
        insevent.registerInstanceLose(conf.fbId, onLose)
        insevent.registerInstanceMonsterDamage(conf.fbId, onBossDamage)
        insevent.registerInstanceExit(conf.fbId, onExitFb)
		insevent.registerInstanceMonsterDie(conf.fbId, onMonsterDie)
		insevent.registerInstanceActorDie(conf.fbId, onActorDie)
    end
	--注册消息处理
    netmsgdispatcher.reg(Protocol.CMD_GuildBoss, Protocol.cGuildBossCmd_Enter, reqEnterGuildBoss)
    netmsgdispatcher.reg(Protocol.CMD_GuildBoss, Protocol.cGuildBossCmd_RecPassAward , reqReceivePassReward)
    netmsgdispatcher.reg(Protocol.CMD_GuildBoss, Protocol.cGuildBossCmd_GetAllInfo, reqGetAllInfo)
	netmsgdispatcher.reg(Protocol.CMD_GuildBoss, Protocol.cGuildBossCmd_GetRankInfo, reqGetRankInfo)
end
table.insert(InitFnTable, init)


engineevent.regGameStartEvent(function()
	print("guildboss: On GameServerStart...")
	local gvar = getGlobalData()
	if gvar.g then
		for k,v in pairs(gvar.g) do
			v.fbHandle = nil
		end
	end
end)

function gmhandle(actor, arg)
	local param = arg[1]
    if param == 'enter' then
		reqEnterGuildBoss(actor, nil)
    elseif param == 'refres' then
		local gvar = getGlobalData()
		gvar.g = nil
		gvar.gr = nil
		MatchGuildPkGuild()
	elseif param == 'clear' then
		local var = getGlobalData()
		var.g = nil
    end
end
