module("guildbattlefb", package.seeall)

guild_battle_fb =  guild_battle_fb or {}
local gate_id = 1 --城门的关卡id
local city_within = 2 --城内的关卡id
local qian_dian = 3 --前殿
local imperial_palace = 4 --皇宫id

--结束类型
local UNDEFINED_END = 0
local TIME_END = 1
local GATHER_END = 2

enter_next_fb_error_code = {
	ok = 0,
	gate_not_die = 1,
	not_next_fb = 2,
	switch_scene_cd = 3,
	scene_feats = 4,
}

--[[玩家静态变量
	结构定义={
		killCount=击杀的人数
	}
]]
local function getData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then 
		return nil
	end
	if var.guild_battle_fb == nil then 
		var.guild_battle_fb = {}
	end
	return var.guild_battle_fb
end

local function initData(actor) --初始化
	print(LActor.getActorId(actor).." guildbattlefb.initData")
	local var = getData(actor)
	if var.scene_feats == nil then 
		var.scene_feats = 0
		--场景功勋
	end
	if var.resurgence_cd == nil then 
		var.resurgence_cd = 0
		--复活cd
	end
	if var.switch_scene_cd == nil then 
		var.switch_scene_cd = 0
		--切换场景cd
	end
	if var.kill_role == nil then 
		var.kill_role = 0
		--杀死的玩家 
	end

	if var.was_killed == nil then 
		var.was_killed = 0
		--被杀次数
	end

	if var.multi_kill == nil then 
		var.multi_kill = 0 
		--连杀
	end
	if var.level_id == nil then 
		var.level_id = 0
		--当前关卡id
	end
	if var.open_size == nil then 
		var.open_size = 0
	end
end

function rsfData(actor) -- 刷新数据
	local var = getData(actor)
	if var.open_size ~= guildbattle.getOpenSize() then
		var.scene_feats     = 0
		var.resurgence_cd   = 0
		var.switch_scene_cd = 0
		var.kill_role       = 0
		var.multi_kill      = 0
		var.level_id        = 0
		var.was_killed      = 0
		var.open_size       = guildbattle.getOpenSize()
		var.killCount		= 0
		sendSceneFeats(actor)
	end
end

local function getGlobalData()
	local var = System.getStaticVar()
	if var == nil then 
		return nil
	end
	if var.guild_battle_fb == nil then 
		var.guild_battle_fb = {}
	end
	return var.guild_battle_fb
end


local function initOccupyData()
	local var = getOccupyData()
	if var.guild_id == nil then 
		var.guild_id = 0
	end
	if var.guild_name == nil then 
		var.guild_name = ""
	end
	if var.leader_name == nil then 
		var.leader_name = ""
	end
	if var.leader_actor_id == nil then 
		var.leader_actor_id = 0
	end
	if var.leader_job == nil then 
		var.leader_job = 0
	end
	if var.leader_sex == nil then 
		var.leader_sex = 0
	end
	if var.leader_coat == nil then 
		var.leader_coat = 0
	end
	if var.leader_weapon == nil then 
		var.leader_weapon = 0
	end
	if var.leader_wing_open_status == nil then 
		var.leader_wing_open_status = 0
	end
	if var.leader_wing_level == nil then 
		var.leader_wing_level = 0
	end
end


local function initGlobalData()
	local var = getGlobalData() 
	if guild_battle_fb.gate_die == nil then 
		guild_battle_fb.gate_die = false
	end
	if guild_battle_fb.is_open == nil then 
		guild_battle_fb.is_open = false
	end
	if guild_battle_fb.is_lottery == nil then 
		guild_battle_fb.is_lottery = false
	end
	if guild_battle_fb.join_lottery == nil then 
		guild_battle_fb.join_lottery = {}
	end
	if guild_battle_fb.gate_handle == nil then 
		guild_battle_fb.gate_handle = 0
	end
	if guild_battle_fb.gate_count_down == nil then 
		guild_battle_fb.gate_count_down = 0;
	end
	if guild_battle_fb.end_time == nil then
		guild_battle_fb.end_time = 0
	end
	if var.occupy == nil then 
		var.occupy = {}
	end
	initOccupyData()
	if var.distribution == nil then 
		var.distribution = {} --分配奖励的
		-- distribution_ids 
		--
	end
	local flags = getFlagsData()
	if flags.status == nil then 
		flags.status = 0
		-- 0 不可采集
		-- 1 可采集
		-- 2 采集中
	end
	if flags.wait_tick == nil then 
		flags.wait_tick = 0
		-- 等待采集的时间(秒)
	end
	if flags.gatherers_name == nil then 
		flags.gatherers_name = ""
		-- 采集者名字
	end
	if flags.gatherers_guild == nil then 
		flags.gatherers_guild = ""
		-- 采集者公会名字
	end
	if flags.gatherers_actor_id == nil then 
		flags.gatherers_actor_id = 0
		-- 采集者actor_id
	end
	if flags.gather_tick == nil then 
		flags.gather_tick = 0
		-- 采集时间
	end
end

function getDistributionData()
	local var = getGlobalData()
	return var.distribution
end

function getGateHandle()
	return guild_battle_fb.gate_handle
end

function setGateHandle(hdl)
	guild_battle_fb.gate_handle = hdl
end

function getJoinLottery()
	return guild_battle_fb.join_lottery
end

function joinLottery(actor)
	local var = getJoinLottery()

	for k, v in pairs(var or {}) do
		if actor then
			if v.actor_id == LActor.getActorId(actor) then return 0 end
		end
	end

	local index = #var + 1
	var[index] = {
		actor_id = LActor.getActorId(actor),
		num = math.random(1,100)
	}
	return var[index].num
end

function getLottery()
	return guild_battle_fb.is_lottery
end

function isOpen()
	return guild_battle_fb.is_open
end


function getDistributionDataById(guild_id)
	local var = getDistributionData()
	if var[guild_id] == nil then 
		var[guild_id] = {}
	end
	if var[guild_id].distribution_ids == nil then 
		var[guild_id].distribution_ids = {}
	end
	return var[guild_id]
end


function rsfDistributionData()
	local gvar = getGlobalData()
	gvar.distribution = {}
end

function rsfDistributionDataByGuildId(guild_id)
	local var = getDistributionDataById(guild_id)
	var.distribution_ids = {}
	broadcastDistributionDataForOnlineLeader()
end



function getOccupyData()
	local var = getGlobalData()
	return var.occupy
end



function getWinGuild()
	local var = getOccupyData()
	return var.guild_id
end


function getWinGuildName()
	local var = getOccupyData()
	return var.guild_name
end


function rsfOccupyData()
	local gvar = getGlobalData()
	gvar.occupy = {}
	initOccupyData()
end



function sendSettlement(actor) -- 发送结算数据
	local guild_id = LActor.getGuildId(actor) 
	if guild_id == 0 then 
		return
	end
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_Settlement)
	if npack == nil then 
		return
	end
	LDataPack.writeString(npack,getWinGuildName())
	LDataPack.writeInt(npack,guildbattlepersonalaward.getIntegral(actor))
	LDataPack.writeInt(npack,guildbattlepersonalaward.getTotalIntegral(guild_id))
	LDataPack.writeInt(npack,guildbattlepersonalaward.getRanking(guild_id))
	LDataPack.writeInt(npack,guildbattleintegralrank.getRank(actor))
	LDataPack.flush(npack)
end
local function getWinLeaderInfo(actor)
	if not guildbattle.isLeader(actor) then 
		return
	end
	local role                     = LActor.getRole(actor,0)
	local var                      = getOccupyData()
	local guild_ptr                = LActor.getGuildPtr(actor)
	local guild_id                 = LGuild.getGuildId(guild_ptr)
	var.guild_id                   = guild_id
	var.guild_name                 = LGuild.getGuildName(guild_ptr)
	var.leader_name                = LActor.getName(actor)
	var.leader_actor_id            = LActor.getActorId(actor)
	var.leader_job                 = LActor.getJob(actor)
	var.leader_sex                 = LActor.getSex(actor)
	var.leader_coat                = LActor.getEquipId(role,EquipSlotType_Coat)
	var.leader_weapon              = LActor.getEquipId(role,EquipSlotType_Weapon)
	local level, star, exp, status = LActor.getWingInfo(actor, 0)
	var.leader_wing_open_status    = status
	var.leader_wing_level          = level
	print(utils.t2s(var))
	guildbattleredpacket.addRedPacketYuanBao(guild_id,GuildBattleConst.redPacketYuanBao)
	guildbattleredpacket.updateOnlineActor(guild_id)
	guildbattledayaward.rsfOnlineActor()
	broadcastWinGuildInfo()
	titlesystem.addTitle(actor,GuildBattleConst.occupationTitle)
	LActor.saveDb(actor)

end

function makeWinGuidInfo(npack) 
	local var = getOccupyData()
	LDataPack.writeInt(npack,var.guild_id)
	LDataPack.writeString(npack,var.guild_name)
	LDataPack.writeString(npack,var.leader_name)
	LDataPack.writeInt(npack,var.leader_actor_id)
	LDataPack.writeByte(npack,var.leader_job)
	LDataPack.writeByte(npack,var.leader_sex)
	LDataPack.writeInt(npack,var.leader_coat)
	LDataPack.writeInt(npack,var.leader_weapon)
	LDataPack.writeInt(npack,var.leader_wing_open_status)
	LDataPack.writeInt(npack,var.leader_wing_level)
end

function broadcastWinGuildInfo()
	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_WinGuildInfo)
	if not npack then 
		return
	end
	makeWinGuidInfo(npack)
	System.broadcastData(npack)
end

function sendWinGuidInof(actor)
	--local guild_id = LActor.getGuildId(actor)
	--if guild_id == 0 then 
	--	return
	--end
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_WinGuildInfo)
	if npack == nil then 
		return
	end
	makeWinGuidInfo(npack)
	LDataPack.flush(npack)
end

function setGuildBattleWinGuildId(guild_id, endStat) 
	-- System.log("guildbattlefb", "setGuildBattleWinGuildId", "call", "guild_id:" .. (guild_id or ""))
	if isOpen()  == false then 
		System.log("guildbattlefb", "setGuildBattleWinGuildId", "not open")
		return 
	end
	-- System.log("guildbattlefb", "setGuildBattleWinGuildId", "mark1")
	local  function sendSettlementAll()
		for i,v in pairs(GuildBattleLevel) do 
			if i ~= city_within then 
				local actors = Fuben.getAllActor(guild_battle_fb[i].hfuben)
				if actors ~= nil then 
					for j = 1,#actors do 
						sendSettlement(actors[j])
					end
				end
			else
				for j,jv in pairs(guild_battle_fb[i].hfubens) do 
					local actors = Fuben.getAllActor(jv)
					if actors ~= nil then 
						for x = 1,#actors do 
							sendSettlement(actors[x])
						end
					end
				end
			end
		end

	end

	local guild_ptr
	local leader_actor_id
	if guild_id ~= 0 then
		guild_ptr = LGuild.getGuildById(guild_id)
		leader_actor_id = LGuild.getLeaderId(guild_ptr)
	end

	guildbattlepersonalaward.sendAllPersonalAward()
	guildbattleintegralrank.sendPersonalRankAward(leader_actor_id)

	local gvar = getOccupyData()
	if guild_id == 0 then 
		sendSettlementAll()
		noticemanager.broadCastNotice(GuildBattleConst.noOccupationNotice)
		gvar.guild_id = 0
		gvar.guild_name = ""
		gvar.endStat = 0
		close()
		broadcastDistributionDataForOnlineLeader()
		broadcastWinGuildInfo()
		return false
	end

	--设置结束类型
	gvar.endStat = endStat

	--主要是为了发结算数据
	gvar.guild_id          = guild_id
	gvar.guild_name        = LGuild.getGuildName(guild_ptr)
	System.log("guildbattlefb", "setGuildBattleWinGuildId", "mark2", "guild_id:" .. guild_id, "leader_actor_id:" .. leader_actor_id)
	asynevent.reg(leader_actor_id,getWinLeaderInfo)
	sendSettlementAll()
	local mail_data      = {}
	mail_data.head       = GuildBattleConst.occupationAwardHead
	mail_data.context    = GuildBattleConst.occupationAwardContext
	mail_data.tAwardList = GuildBattleConst.occupationAward
	mailsystem.sendMailById(leader_actor_id, mail_data)

	local hefuIdx = guildbattle.getHefuActivityIdx()
	if hefuIdx and GuildBattleConst.hefuAward.leader.award[hefuIdx] then
		local leaderConf = GuildBattleConst.hefuAward.leader
		local mail_data      = {}
		mail_data.head       = leaderConf.title
		mail_data.context    = leaderConf.context
		mail_data.tAwardList = leaderConf.award[hefuIdx]
		mailsystem.sendMailById(leader_actor_id, mail_data)

		--保存归属信息
		guildbattle.setHefuBelongInfo(gvar.guild_name)
	end

	noticemanager.broadCastNotice(GuildBattleConst.endNotice,gvar.guild_name)
	local id_list = LGuild.getMemberIdList(guild_ptr)

	local function sendTitle(actor)
		titlesystem.addTitle(actor,GuildBattleConst.memberOccupationAward)
		LActor.saveDb(actor)
	end
	for i,v in pairs(id_list) do 
		if v ~= leader_actor_id then 
			mail_data = {}
			mail_data.head       = GuildBattleConst.memberOccupationAwardHead
			mail_data.context    = GuildBattleConst.memberOccupationAwardContext
			mail_data.tAwardList = {}
			mailsystem.sendMailById(v,mail_data)
			asynevent.reg(v,sendTitle)
		end
	end
	close()
--	subactivitytype13.sendReward()
	broadcastDistributionDataForOnlineLeader()
end

function setGuildBattleWinGuild(actor) -- 攻沙成功的工会
	if isOpen()  == false then 
		LActor.log(actor, "guildbattlefb.setGuildBattleWinGuild", "gameIsEnd")
		return
	end
	local guild_id = LActor.getGuildId(actor)
	setGuildBattleWinGuildId(guild_id, GATHER_END)
end

function isWinGuild(actor) 
	local guild_id = LActor.getGuildId(actor) 
	return isWinGuildId(guild_id)
end

function isWinGuildId(guild_id)
	local win_guild = getWinGuild()
	if guild_id == 0 then 
		return false
	end
	if win_guild == 0 then 
		return false
	end
	return guild_id == win_guild
end

function getWinGuildLeaderId()
	local var = getOccupyData()
	return var.leader_actor_id
end

function setFlagsStatus(status)
	local var = getFlagsData()
	var.status = status
end



function setFlagsWaitTick(tick)
	local var = getFlagsData()
	var.wait_tick = tick
end

function getFlagsWaitTick()
	local var = getFlagsData()
	return var.wait_tick
end


function setFlagsGatherTick(tick)
	local var = getFlagsData()
	var.gather_tick = tick
end

function getFlagsGatherTick(tick)
	local var = getFlagsData()
	return var.gather_tick 
end


function setFlagsGatherersName(name)
	local var = getFlagsData()
	var.gatherers_name = name
end

function setFlagsGatherersGulid(name)
	local var = getFlagsData()
	var.gatherers_guild = name
end



function setFlagsGatherersActorId(id)
	local var = getFlagsData()
	var.gatherers_actor_id = id
end

function getFlagsGatherersActorId()
	local var = getFlagsData()
	return var.gatherers_actor_id
end




function getFlagsData()
	if guild_battle_fb.flags == nil then 
		guild_battle_fb.flags = {}
	end
	return guild_battle_fb.flags
end

local function rsfGlobalData()
	local var = getGlobalData()
	guild_battle_fb = {}
	initGlobalData()
end


function getMultikill(actor)
	local var = getData(actor)
	return var.multi_kill
end


function addKillRole(actor,num)
	local var = getData(actor) 
	var.kill_role = var.kill_role + num
	if var.kill_role < 0 then 
		var.kill_role = 0
	end
	if num > 0 then 
		var.multi_kill = var.multi_kill + 1
	else 
		var.multi_kill = 0
	end
	if var.multi_kill ~= 0 and var.multi_kill ~= 1 then 
		local conf = GuildBattleMultiKill[var.multi_kill]
		if conf == nil then 
			conf = GuildBattleMultiKill[#GuildBattleMultiKill]
		end
		if conf == nil then 
			LActor.log(actor, "guildbattlefb.addKillRole", "not conf", var.multi_kill)
			return
		end
		guildbattlepersonalaward.addIntegral(actor,conf.integral)
		noticemanager.broadCastNotice(conf.notice,LActor.getName(actor),var.multi_kill)
	end

	LActor.log(actor, "guildbattlefb.addKillRole", "mark", var.multi_kill, var.kill_role, num)
end

function addSceneFeats(actor,num) -- 加功勋
	local var = getData(actor)
	var.scene_feats = var.scene_feats + num
	if var.scene_feats < 0 then 
		return
	end

	sendSceneFeats(actor)
	--updateGuildInfo(actor)
end

function getSceneFeats(actor)
	local var = getData(actor)
	return var.scene_feats
end

function getIntegralPhase(percentage) 
	local ret = nil
	for i = 1,#GuildBattleIntegralPhase do 
		local v = GuildBattleIntegralPhase[i]
		if percentage < v.percentagePhase then 
			ret = v
			break
		end
	end
	return ret  and ret or GuildBattleIntegralPhase[#GuildBattleIntegralPhase] 
end

function isAddWasKilledIntegral(actor)
	local var = getData(actor)
	if var.was_killed >= GuildBattleConst.wasKilledCount then 
		return false
	end
	return true
end

function addWasKilledIntegral(actor,num) 
	local var = getData(actor)
	var.was_killed = var.was_killed + num
	if var.was_killed >= GuildBattleConst.wasKilledCount then 
		var.was_killed = GuildBattleConst.wasKilledCount
	end
	if var.was_killed < 0 then 
		var.was_killed = 0
	end
end

function killRole(actor,was_killed,level_id) --杀死了角色
	local conf = GuildBattleLevel[level_id]
	if conf == nil then 
		return
	end
	local percentage = guildbattlepersonalaward.getIntegral(actor) / guildbattlepersonalaward.getIntegral(was_killed) * 100
	local pconf = getIntegralPhase(percentage)
	local add_percentage = pconf.addPercentage / 100

	guildbattlepersonalaward.addIntegral(actor,math.floor(GuildBattleConst.killRoleIntegral * add_percentage))
	if isAddWasKilledIntegral(was_killed) then 
		guildbattlepersonalaward.addIntegral(was_killed,math.floor(GuildBattleConst.wasKilledRoleIntegral))
	end
	if level_id == city_within then --第二个场景有功勋
		addSceneFeats(actor,math.floor(GuildBattleConst.killRolefeats * add_percentage))
		if isAddWasKilledIntegral(was_killed) then 
			addSceneFeats(was_killed,math.floor(GuildBattleConst.wasKilledRolefeats))
		end
	end
	addWasKilledIntegral(was_killed,1)
	addKillRole(actor,1)
end

function clearSwitchSceneCd(actor) --清空切换场景cd
	local var = getData(actor)
	var.switch_scene_cd = 0 
end


--检查是否可分配(所有的)
local function checkDistribution(guild_id)
	if guild_id == 0 then 
		return false
	end
	local var  = getDistributionDataById(guild_id)
	local rank = guildbattlepersonalaward.getRanking(guild_id)
	local conf = GuildBattleDistributionAward[rank]
	if conf == nil then 
		-- 检查是不是有这个奖励
		return  false
	end
	for i,v in pairs(conf) do 
		if var.distribution_ids[i] == nil then
			if not v.rewardFlag or v.rewardFlag == guildbattle.getActType() then
				return false
			end
		end
	end
	return true
end

local function sendDistributionData(actor) --发送分配奖励数据
	local guild_id = LActor.getGuildId(actor)
	if guild_id == 0 then 
		return
	end
	if not guildbattle.isLeader(actor) then 
		print(LActor.getActorId(actor) .. " not Leader")
		return 
	end
	local rank = guildbattlepersonalaward.getRanking(guild_id)
	local conf = GuildBattleDistributionAward[rank]
	if conf == nil then 
		-- 检查是不是有这个奖励
		return 
	end
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_DistributionData)
	if npack == nil then 
		return
	end
	LDataPack.writeInt(npack,rank)
	if isOpen() then 
		LDataPack.writeByte(npack,0)
	else
		LDataPack.writeByte(npack,checkDistribution(guild_id) and 0 or 1)
	end

	local actType = guildbattle.getActType()
	LDataPack.writeByte(npack, actType)
	LDataPack.flush(npack)

end

function broadcastDistributionDataForOnlineLeader() --广播数据到所有在线 leader

	local rank = guildbattlepersonalaward.gerRankingTbl()
	for i,v in pairs(rank) do 
		local guild_ptr = LGuild.getGuildById(v)
		local leader = LGuild.getOnlineLeaderActor(guild_ptr)
		if leader ~= nil then 
			sendDistributionData(leader)
		end
	end
end

function broadcastRsfDistributionDataForOnlineLeader()

	local rank = guildbattlepersonalaward.gerRankingTbl()
	for i,v in pairs(rank) do 
		local guild_ptr = LGuild.getGuildById(v)
		local leader = LGuild.getOnlineLeaderActor(guild_ptr)
		if leader ~= nil then 
			local npack = LDataPack.allocPacket(leader,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_DistributionData)
			if npack == nil then 
				return
			end
			LDataPack.writeInt(npack,i)
			LDataPack.writeByte(npack,0)

			local actType = guildbattle.getActType()
			LDataPack.writeByte(npack, actType)
			LDataPack.flush(npack)
		end
	end

end


function enterFb(actor,id) --进入场景
	if not guildbattle.checkOpen(actor) then 
		print(LActor.getActorId(actor).." guildbattlefb.enterFb guildbattle not open")
		return false
	end
	if not isOpen()  then 
		print(LActor.getActorId(actor).." guildbattlefb.enterFb not open")
		return false
	end
	local x = 0
	local y = 0
	local fb_id = 0
	local conf = GuildBattleLevel[id]
	local role_count = LActor.getRoleCount(actor)
	if conf == nil then 
		print(LActor.getActorId(actor).." guildbattlefb.enterFb conf is nil")
		return false
	end
	fb_id = conf.fbId

	local index = math.random(1,#conf.birthPoint)
	x = conf.birthPoint[index].x
	y = conf.birthPoint[index].y
	local var = getData(actor)
	if var.id == id then 
		LActor.sendTipmsg(actor, "已经在相同场景了", ttScreenCenter)
		return false
	end
	local now = os.time()
	if now < var.switch_scene_cd then 
		LActor.sendTipmsg(actor, "进入场景cd时间不够", ttScreenCenter)
		return false
	end
	local conf = GuildBattleLevel[id] 
	if guild_battle_fb[id] == nil or conf == nil then 
		return false
	end
	if var.id ~= imperial_palace and id ~= qian_dian then 
		if conf.feats > getSceneFeats(actor) then 
			LActor.sendTipmsg(actor, "进关功勋不够", ttScreenCenter)
			return false
		end
		--
	end
	local guild_id = LActor.getGuildId(actor)
	LActor.setCamp(actor,CampType_Player)
	if id ~= city_within then
		LActor.enterFuBen(actor, guild_battle_fb[id].hfuben,0,x,y)
	else 
		local hfuben = nil 
		local tmp_size = 0
		local data = guild_battle_fb[id].hfubens
		for i = 1,#data do 
			local ins = instancesystem.getInsByHdl(data[i])
			if ins ~= nil then 
				local actor_size = #(ins:getActorList())
				local member_size = 0
				for j,jv in pairs(ins:getActorList()) do 
					if LActor.getGuildId(jv) == guild_id then 
						member_size = member_size + 1
					end
				end
				if actor_size < GuildBattleConst.cityWithinActorSize and member_size < 5 then 
					if actor_size >= tmp_size then 
						hfuben = data[i]
						tmp_size = actor_size
					end
				end
			end
		end
		if hfuben == nil then 
			hfuben = Fuben.createFuBen(fb_id)
			if hfuben ~= 0 then
				local ins = instancesystem.getInsByHdl(hfuben)
				if ins ~= nil then
					ins.data.level_id = id
				end
				table.insert(data,hfuben)
				--[[
				for i,v in pairs(conf.monsters) do 
					Fuben.createMonster(ins.scene_list[1],jv.monsterId,jv.x,jv.y)
				end
				]]
			end
		end
		if hfuben ~= nil then 
			LActor.enterFuBen(actor,hfuben,0,x,y)
		end
	end
	if conf.pvp == 1 then 
		LActor.setCamp(actor,guild_id)
	end

	var.level_id = id
	var.switch_scene_cd = now + conf.switchSceneCd

	if id == imperial_palace then 
		guildbattlepersonalaward.enterImperialPalace(actor)
	end
	sendImperialPalaceAttribution(actor)
	guildbattlepersonalaward.updateSceneName(actor,InstanceConfig[fb_id].name)
	if conf.pvp == 1 then 
		for i = 0,role_count do
			local role = LActor.getRole(actor,i)
			LActor.setAIPassivity(role,true)
		end
	end
	sendFlagsData(actor)
	guildbattlepersonalaward.sendGuildRankingGtopThree(actor)
	guildbattlepersonalaward.sendPersonalAwardData(actor)
	if id == gate_id then 
		sendGateCountDown(actor)
	end
	return true
end

function enterNextFb(actor, enter_id) --进入下一下关卡
	-- LActor.log(actor, "guildbattlefb.enterFb", "call")
	local var = getData(actor)
	local is_city_within = false
	local conf = GuildBattleLevel[var.level_id]
	-- LActor.log(actor, "guildbattlefb.enterFb", "mark1", var.level_id)
	if conf == nil then 
		return enter_next_fb_error_code.ok
	end
	local next_level_id = 0
	for _,v in ipairs(conf.nextLevel or {}) do
		if v == enter_id then
			next_level_id = v
		end
	end
	-- LActor.log(actor, "guildbattlefb.enterFb", "mark2", next_level_id)
	if next_level_id == 0 then 
		return enter_next_fb_error_code.not_next_fb
	end
	if var.level_id == gate_id then 
		if not guild_battle_fb.gate_die  then 
			LActor.log(actor, "guildbattlefb.enterFb", "mark3")
			return enter_next_fb_error_code.gate_not_die
		end
	end
	local next_config = GuildBattleLevel[next_level_id]
	if next_config == nil then 
		LActor.log(actor, "guildbattlefb.enterFb", "mark4")
		return enter_next_fb_error_code.ok
	end

	if var.level_id == city_within then 
			is_city_within = true
	end
	local ret = enterFb(actor,next_level_id)
	--这样有可能有坑
	if ret then 
		if is_city_within then
			LActor.exitFuben(actor)
			clearSwitchSceneCd(actor)
			enterFb(actor,next_level_id)
			--
			--如果是城内进前殿

			var.scene_feats = 0
			LActor.log(actor, "guildbattlefb.enterFb", "mark5")
			sendSceneFeats(actor)
		end
		return enter_next_fb_error_code.ok
	end
	local now = os.time()
	if now < var.switch_scene_cd then 
		return enter_next_fb_error_code.switch_scene_cd
	end
	if getSceneFeats(actor) <= next_config.feats then 
		return enter_next_fb_error_code.scene_feats
	end
	return enter_next_fb_error_code.ok
end

function sendGateAward(ins) --发送城门奖励
	print(LActor.getActorId(actor).." guildbattlefb.sendGateAward")
	local rank = bossinfo.getDdamageRank(ins)
	if rank == nil or not next(rank) then 
		return
	end
	for i = 2,#rank do 
		local mail_data = {}
		mail_data.head       = GuildBattleConst.gateAwardHead
		mail_data.context    = string.format(GuildBattleConst.gateAwardContext,i)
		mail_data.tAwardList = GuildBattleConst.gateCommonAward
		mailsystem.sendMailById(rank[i].id,mail_data)
		print(rank[i].id.." guildbattlefb.sendGateAward on rank mail")
		asynevent.reg(rank[i].id,
		function(tag)
			guildbattlepersonalaward.addIntegral(tag,GuildBattleConst.gateCommonIntegral)
			LActor.saveDb(tag)
		end
		)
	end
	if rank[1] ~= nil then 
		local mail_data = {}
		mail_data.head       = GuildBattleConst.gateAwardHead
		mail_data.context    = string.format(GuildBattleConst.gateAwardContext,1)
		mail_data.tAwardList = GuildBattleConst.gateFirstAward
		mailsystem.sendMailById(rank[1].id,mail_data)
		print(rank[1].id.." guildbattlefb.sendGateAward on rank[1] mail")
		asynevent.reg(rank[1].id,
		function(tag)
			guildbattlepersonalaward.addIntegral(tag,GuildBattleConst.gateFirstIntegral)
			LActor.saveDb(tag)
		end
		)
		noticemanager.broadCastNotice(GuildBattleConst.gateDieNotice,rank[1].name)
	end
end


local function closeCallBack()
	if isOpen()  then
		local gId = guildbattlepersonalaward.getImperialPalaceAttributionGuildId()
		setGuildBattleWinGuildId(gId, TIME_END)
	end
end
---
--


function rsfAllData()
	local actors = System.getOnlineActorList() or {}
	for i=1,#actors do 
		rsfData(actors[i])
	end

end


local function autoAddIntegral(id)
	if not isOpen() then 
		return
	end
	local conf = GuildBattleLevel[id] 
	if conf == nil then 
		return
	end
	local var = guild_battle_fb[id]
	if id ~= city_within then 
		local actors = Fuben.getAllActor(var.hfuben)
		if actors ~= nil then
			for i = 1,#actors do 
				guildbattlepersonalaward.addIntegral(actors[i],conf.addIntegral)
			end
		end
	else 
		for i,v in pairs(var.hfubens) do 
			local actors = Fuben.getAllActor(v)
			if actors ~= nil then
				for j = 1,#actors  do 
					guildbattlepersonalaward.addIntegral(actors[j],conf.addIntegral)
				end
			end
		end
	end
	if conf.addIntegralSec ~= 0 then
		LActor.postScriptEventLite(nil,conf.addIntegralSec  * 1000,function() autoAddIntegral(id) end)
	end

end

function killGate()
	LActor.KillMonster(getGateHandle())
	setGateHandle(0)
end

function killGateCallBack()
	if not isOpen() then
		return
	end
	killGate()
end

function sendGateCountDown(actor)
	local curr = os.time()
	local num = guild_battle_fb.gate_count_down - curr
	if num < 0 then 
		num = 0
	end
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_GateCountDown)
	if npack == nil then 
		return
	end
	LDataPack.writeInt(npack,num)
	LDataPack.flush(npack)

end

function sendJoinLotteryCallBack()
	if not isOpen() then 
		return
	end
	guild_battle_fb.is_lottery = true
	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_JoinLottery)
	if npack == nil then 
		return
	end
	LDataPack.writeInt(npack,GuildBattleConst.gateLotteryItem.id)
	LDataPack.writeInt(npack,GuildBattleConst.gateLotteryCountDown)
	LActor.postScriptEventLite(nil,(GuildBattleConst.gateLotteryCountDown)  * 1000,function() joinLotteryCallBack() end)
	sendDataForSceneById(npack,gate_id)

end


function getEndTime()
	if not isOpen() then 
		return 0
	end
	if guild_battle_fb.end_time == 0 then
		return 0
	end
	local curr = os.time()
	local sub = guild_battle_fb.end_time - curr
	if sub < 0 then 
		sub = 0
	end
	return sub
end


function open()
	print("guildbattlefb.open")
	
	if isOpen()  then
		print("guildbattlefb.open isopened")
		return
	end


	for i,v in pairs(GuildBattleLevel) do 
		if guild_battle_fb[i] == nil and i ~= city_within then 
			guild_battle_fb[i] = {}
			if guild_battle_fb[i].hfuben == nil then
				guild_battle_fb[i].hfuben  = Fuben.createFuBen(v.fbId)
				if guild_battle_fb[i].hfuben == 0 then 
					System.log("guildbattlefb", "open", "createFB error", v.fbId)
				end
			end
			local ins = instancesystem.getInsByHdl(guild_battle_fb[i].hfuben)
			if ins ~= nil then
				ins.data.level_id = i
				if i == imperial_palace then 
					if guild_battle_fb[i].flags_hdl == nil then 
						local flags = Fuben.createMonster(ins.scene_list[1],GuildBattleConst.flags.id,GuildBattleConst.flags.x,GuildBattleConst.flags.y)
						if  flags ~= nil then 
							guild_battle_fb[i].flags_hdl = LActor.getHandle(flags)
						else
							print("guildbattlefb.open is not flags")
						end
					end
				end
				if i == gate_id then
					--手动刷一下怪
					local gate = Fuben.createMonster(ins.scene_list[1],GuildBattleConst.gate.id,GuildBattleConst.gate.x,GuildBattleConst.gate.y)
					if gate ~= nil then 
						setGateHandle(LActor.getHandle(gate))
					end
				end

			end

		end
		if guild_battle_fb[i] == nil and i == city_within then 
			guild_battle_fb[i] = {}
			guild_battle_fb[i].hfubens = {}
		end
	end
	guild_battle_fb.is_open = true
	guildbattle.addOpenSize(1)

	--保存开启时间
	prestigesystem.saveActivityOpenDay(prestigesystem.ActivityEvent.guildbattle)

	-- 刷新以前的公会红包
	guildbattleredpacket.rsfRedPacket(getWinGuild())
	guildbattleredpacket.updateOnlineActor(getWinGuild())
	broadcastRsfDistributionDataForOnlineLeader()
	rsfOccupyData()
	rsfDistributionData()
	LActor.postScriptEventLite(nil,(GuildBattleConst.continueTime)  * 1000,function() closeCallBack() end)
	guild_battle_fb.end_time = os.time() + GuildBattleConst.continueTime
	LActor.postScriptEventLite(nil,(GuildBattleConst.gateLiveTime)  * 1000,function() killGateCallBack() end)
	LActor.postScriptEventLite(nil,(GuildBattleConst.gateLotteryWaitTime)  * 1000,function() sendJoinLotteryCallBack() end)
	guild_battle_fb.gate_count_down = os.time() + GuildBattleConst.gateLiveTime
	guildbattle.broadcastOpen()
	guildbattlepersonalaward.rsfGlobalData()
	guildbattlepersonalaward.rsfAllData()
	rsfAllData()
	noticemanager.broadCastNotice(GuildBattleConst.openNotice)


	for i,v in pairs(GuildBattleLevel) do 
		if v.addIntegralSec ~= 0 then
			LActor.postScriptEventLite(nil,v.addIntegralSec  * 1000,function() autoAddIntegral(i) end)
		end
	end
	guildsystem.setShielding(true)
	guildbattlepersonalaward.autoBroadcastGuildRankingGtopThree()
	broadcastWinGuildInfo()
	guildbattledayaward.rsfOnlineActor()

end

function close()
	print("guildbattlefb.close")
	if isOpen() == false then 
		print("guildbattlefb.close is not open")
		return
	end
	for i,v in pairs(GuildBattleLevel) do 
		if guild_battle_fb[i] ~= nil then
			if i ~= city_within then 
				local ins = instancesystem.getInsByHdl(guild_battle_fb[i].hfuben)
				if ins ~= nil then 
					ins:release()
				end
			else
				for j,jv in pairs(guild_battle_fb[i].hfubens) do 
					local ins = instancesystem.getInsByHdl(jv)
					if ins ~= nil then 
						ins:release()
					end
				end
			end
		end
	end
	guild_battle_fb = {}
	guild_battle_fb.is_open = false
	rsfGlobalData()
	guildbattle.broadcastOpen()
	guildsystem.setShielding(false)

	--把数据更新到跨服服务器
	-- csguildwarmgr.rzPlayer()
end

function resurgenceCallBack(actor) -- 复活回调
	local var = getData(actor)
	if var.level_id ~= 0 then
		LActor.recover(actor)
		enterFb(actor,gate_id)
		clearSwitchSceneCd(actor)
	end
end

function setResurgence(actor,level_id)
	local cd = getResurgenceCd(actor)
	LActor.postScriptEventLite(actor,(cd)  * 1000,function() resurgenceCallBack(actor) end)
	
end

function switchTarget(actor,et_hdl)
	-- LActor.log(actor, "guildbattlefb.switchTarget", "call")
	if LActor.getLiveByJob(actor) == nil then 
		-- print(LActor.getActorId(actor) .. " 自己所有子角色死了 不能切换目标 ")
		LActor.log(actor, "guildbattlefb.switchTarget", "mark1")
	end
	local et = LActor.getEntity(et_hdl)
	if et == nil then
		LActor.log(actor, "guildbattlefb.switchTarget", "mark2", et_hdl)
		return
	end
	if et == actor then 
		-- print(LActor.getActorId(actor) .. " 不能自己打自己 ")
		LActor.log(actor, "guildbattlefb.switchTarget", "mark4")
		return 
	end
	local role_count = LActor.getRoleCount(actor)
	for i = 0,role_count do
		local role = LActor.getRole(actor,i)
		if role == et then
			-- print(LActor.getActorId(actor) .. " 不能自己打自己 ")
			LActor.log(actor, "guildbattlefb.switchTarget", "mark5")
			return
		end
	end

	LActor.log(actor, "guildbattlefb.switchTarget", "mark6", et_hdl, LActor.getEntityType(et))
	for i = 0,role_count do
		local role = LActor.getRole(actor,i)
		if role ~= nil then
			LActor.setAITarget(role,et)
			-- local pet = LActor.getBattlePet(role) 
			-- if pet ~= nil then
			-- 	LActor.setAITarget(pet,et)
			-- end
		end
	end
end

function gotoFlags(actor) -- 去棋子那里
	if not isOpen() then 
		return false
	end
	switchTarget(actor,guild_battle_fb[imperial_palace].flags_hdl)
end

------------------
local function onExitFb(ins,actor)  
	-- LActor.log(actor, "guildbattlefb.onExitFb", "call")
	local level_id = ins.data.level_id
	sendActorDie(actor,level_id)

	local conf = GuildBattleLevel[level_id]
	if conf == nil then 
		return
	end
	LActor.setCamp(actor,CampType_Player)
	local var = getData(actor) 
	if var.level_id == level_id then 
		if level_id == imperial_palace then 
			guildbattlepersonalaward.exitImperialPalace(actor)
		end
		var.level_id = 0
		var.switch_scene_cd = os.time()  + GuildBattleConst.exitAndOfflineSwitchSceneCd
	end

	guildbattlepersonalaward.updateSceneName(actor,"")
	if conf.pvp == 1 then 
		local role_count = LActor.getRoleCount(actor)
		for i = 0,role_count do
			local role = LActor.getRole(actor,i)
			LActor.setAIPassivity(role,false)
		end
	end
end

local function onOffline(ins,actor)
	local level_id = ins.data.level_id
	sendActorDie(actor,level_id)
	LActor.setCamp(actor,CampType_Player)
	local var = getData(actor) 
	local conf = GuildBattleLevel[level_id]
	if conf == nil then 
		return
	end
	if var.level_id == level_id then 
		var.level_id = 0
		if level_id == imperial_palace then 
			guildbattlepersonalaward.exitImperialPalace(actor)
		end
		var.switch_scene_cd = os.time()  + GuildBattleConst.exitAndOfflineSwitchSceneCd
	end
	LActor.exitFuben(actor)

	guildbattlepersonalaward.updateSceneName(actor,"")
end

local function onRoleDie(ins,role,killer_hdl)
	local level_id = ins.data.level_id
	local conf = GuildBattleLevel[level_id]
	local actor = LActor.getActor(role)
	if conf == nil then
		return
	end
	local et = LActor.getEntity(killer_hdl)
	if LActor.getEntityType(et) ~= EntityType_Role then
		return
	end
	local killer_actor = LActor.getActor(et)
	if conf.pvp == 1 then 
		if killer_actor ~= nil then
			killRole(killer_actor,actor,level_id)
		end
	end
 
	local jobs = {"战士","法师","道士"}
	local str = "你击杀了" .. LActor.getName(actor) .. "的" .. jobs[LActor.getJob(role)]
	chat.sendSystemTips(killer_actor,1,2,str)
end

function sendActorDie(actor,level_id) 
	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_ActorDie)
	if not npack then 
		return
	end
	local i = 0
	local count = LActor.getRoleCount(actor)
	while(i < count) do 

		local role = LActor.getRole(actor,i)
		if role ~= nil then 
			LDataPack.writeUint64(npack,LActor.getMasterHdl(role))
			print(LActor.getMasterHdl(role))
			break
		end
		i = i + 1
	end
	sendDataForSceneById(npack,level_id)
end


function getResurgenceConfig(integral)
	local ret = nil
	for i = 1,#GuildBattleResurgence do 
		local v = GuildBattleResurgence[i]
		if integral < v.integral then 
			ret = v
			break
		end
	end
	return ret  and ret or GuildBattleResurgence[#GuildBattleResurgence] 
end

function getResurgenceCd(actor) 
	local conf = getResurgenceConfig( guildbattlepersonalaward.getIntegral(actor) )
	return conf.cd
end

--通知当前击杀人数变化
local function SendKillCount(actor)
	local var = getData(actor)
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_SendKillCount)
	if npack == nil then 
		return
	end
	LDataPack.writeInt(npack, var.killCount or 0)
	LDataPack.flush(npack)
end

--清除击杀人数
local function ClearKillCount(actor)
	local var = getData(actor) 
	var.killCount = nil
	SendKillCount(actor)
end

--增加击杀人数
local function AddKillCount(killer_actor)
	if not killer_actor then return end
	local var = getData(killer_actor)
	var.killCount = (var.killCount or 0) + 1
	SendKillCount(killer_actor)
end

local function onActorDie(ins,actor,killer_hdl)
	local level_id = ins.data.level_id
	local var = getData(actor) 
	sendActorDie(actor,level_id)
	--[[
	if var.level_id == level_id then 
	end
	]]
	setResurgence(actor,level_id)
	if level_id == imperial_palace then 
		guildbattlepersonalaward.exitImperialPalace(actor)
	end
	local et = LActor.getEntity(killer_hdl)
	local killer_actor = LActor.getActor(et)
	--记录连续击杀人数
	ClearKillCount(actor)
	AddKillCount(killer_actor)

	local et_name = LActor.getName(killer_actor) or ""
	local et_guild_name = LGuild.getGuildName(LActor.getGuildPtr(killer_actor)) or ""
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_ResurgenceInfo)
	if npack == nil then 
		return
	end
	LDataPack.writeInt(npack,getResurgenceCd(actor))
	LDataPack.writeString(npack,et_name)
	LDataPack.writeString(npack,et_guild_name)
	LDataPack.flush(npack)
	local last_kille = getMultikill(actor)
	if last_kille >= GuildBattleConst.finalMultikillCount then 
		noticemanager.broadCastNotice(GuildBattleConst.finalMultikillNotice,et_name,LActor.getName(actor),last_kille)
	else 
		LActor.log(actor, "guildbattlefb.onActorDie", "mark1")
	end
	var.multi_kill = 0
	var.kill_role = 0
end

local function onMonsterDie(ins,mon,killer_hdl)
	local level_id = ins.data.level_id
	if level_id == gate_id and not guild_battle_fb.gate_die then 
		System.log("guildbattlefb", "onMonsterDie", "mark1", Fuben.getMonsterId(mon), level_id, ins.id)
		sendGateAward(ins)
		guild_battle_fb.gate_die = true
		---//城门挂了要广播一次
		local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_Enter)
		if npack == nil then 
			return
		end
		LDataPack.writeByte(npack,0)
		LDataPack.writeByte(npack,guild_battle_fb.gate_die and 1 or 0)
		local actType = guildbattle.getActType()
		LDataPack.writeByte(npack, actType)
		sendDataForSceneById(npack,gate_id)
	end
	local et = LActor.getEntity(killer_hdl)
	local killer_et = LActor.getActor(et)
	if killer_et ~= nil then
		if LActor.getBattlePet(LActor.getMaster(mon)) == mon then 
			System.log("guildbattlefb", "onMonsterDie", "mark2")
			return
		end
		if level_id == city_within then 
			addSceneFeats(killer_et,GuildBattleConst.killMonsterfeats)
		end
		if level_id ~= gate_id then 
			guildbattlepersonalaward.addIntegral(killer_et,GuildBattleConst.killMonsterIntegral)
		end
	end
end

function getLotteryWin()
	local var = getJoinLottery()
	if not next(var) then 
		return {}
	end
	local tbl = {}
	for i = 1,#var do 
		if not next(tbl) then 
			tbl = var[i]
			if tbl.num == 100 then 
				break
			end
		else 
			if var[i].num == 100 then 
				tbl = var[i]
				break
			end
			if var[i].num >= tbl.num then 
				tbl = var[i]
			end
		end
	end
	return tbl;
end

function sendLotteryWin()
	local tbl = getLotteryWin()
	if not next(tbl) then 
		System.log("guildbattlefb", "sendLotteryWin", "mark1")
		return 
	end
	local actor_id = tbl.actor_id
	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_ReturnJoinLotteryBigNum)
	if npack == nil then 
		return false
	end
	LDataPack.writeInt(npack,tbl.num)
	LDataPack.writeString(npack,LActor.getActorName(actor_id))
	sendDataForSceneById(npack,gate_id)
end

function joinLotteryCallBack()
	local tbl = getLotteryWin()
	if not next(tbl) then 
		System.log("guildbattlefb", "joinLotteryCallBack", "mark1")
		return 
	end
	local actor_id = tbl.actor_id
	local mail_data = {}
	mail_data.head       = GuildBattleConst.gateLotteryHead
	mail_data.context    = GuildBattleConst.gateLotteryContext
	mail_data.tAwardList = {GuildBattleConst.gateLotteryItem}
	mailsystem.sendMailById(actor_id,mail_data)
	noticemanager.broadCastNotice(GuildBattleConst.gateLotteryNotice,LActor.getActorName(actor_id),ItemConfig[GuildBattleConst.gateLotteryItem.id].name)
end

local function onMonsterDamage(ins,monster,value,attacker,res)
	--[[
	local level_id = ins.data.level_id
	if level_id ~= gate_id then 
		return
	end
	local oldhp = LActor.getHp(monster)
	if oldhp <= 0 then 
		return
	end
	local hp = res.ret
	hp = hp / LActor.getHpMax(monster) * 100
	local percentage1 =  math.floor(LActor.getHpMax(monster) / 100)
	local max_hp = math.floor(percentage1 * GuildBattleConst.gateShieldPercentage)
	if ins.data.shield == nil  and hp  <= GuildBattleConst.gateShieldPercentage then 
		ins.data.shield = GuildBattleConst.gateShield
	end
	if hp < GuildBattleConst.gateShieldPercentage and ins.data.shield ~= 0 then 
		local curr_hp = res.ret
		local sub_hp = max_hp - curr_hp
		ins.data.shield = ins.data.shield - sub_hp
		if ins.data.shield <= 0 then 
			res.ret = max_hp + ins.data.shield
			ins.data.shield = 0
			-- 给奖励
		else 
			res.ret = max_hp
		end
		local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_GateShield)
		if not npack then 
			return
		end
		LDataPack.writeInt(npack,(ins.data.shield /  GuildBattleConst.gateShield) * 100 )
		sendDataForSceneById(npack,gate_id)
	end
	]]
end

local function onGateCreate(ins,mon)
	local hdl = LActor.getHandle(mon)
	setGateHandle(hdl)
end


local function initFbCallBack()
	for i,v in pairs(GuildBattleLevel) do 
		insevent.registerInstanceExit(
		v.fbId, 
		onExitFb
		)
        insevent.registerInstanceMonsterDamage(
		v.fbId, 
		onMonsterDamage
		)
		insevent.registerInstanceOffline(
		v.fbId, 
		onOffline
		)
        insevent.registerInstanceActorDie(
		v.fbId, 
		onActorDie
		)
	    insevent.registerInstanceMonsterDie(
		v.fbId, 
		onMonsterDie
		)
	    insevent.regRoleDie(
		v.fbId, 
		onRoleDie
		)
	end
	--gate
	local conf = GuildBattleLevel[gate_id]
	insevent.registerInstanceMonsterCreate(conf.fbId,onGateCreate)
end
-------------------
--
--

local function onEnter(actor,pack)
	clearSwitchSceneCd(actor) --进入场景不会在有cd
	local ret = enterFb(actor,gate_id)
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_Enter)
	if npack == nil then 
		return
	end
	LDataPack.writeByte(npack,ret and 1 or 0)
	LDataPack.writeByte(npack,guild_battle_fb.gate_die and 1 or 0)
	local actType = guildbattle.getActType()
	LDataPack.writeByte(npack, actType)
	LDataPack.flush(npack)
end
--[[
local function onSwitchTarget(actor,pack)
	LActor.log(actor, "guildbattlefb.onSwitchTarget", "call")
	local et_hdl = LDataPack.readInt64(pack)
	if et_hdl == 0 then 
		LActor.setAIAttackMonster(actor)
	else
		local et_acotr = LActor.getEntity(et_hdl)
		if et_acotr == nil then 
			LActor.log(actor, "guildbattlefb.onSwitchTarget", "mark1", et_hdl)
			return 
		end
		switchTarget(actor,LActor.getHandle(LActor.getLiveByPower(et_acotr)))

	end
end
]]
local function onEnterNext(actor, pack)	
	local enter_id = LDataPack.readByte(pack)
	local ret = enterNextFb(actor, enter_id)
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_EnterNext)
	if npack == nil then 
		return
	end
	LDataPack.writeInt(npack,ret)
	LDataPack.flush(npack)
end

local function onJoinLottery(actor,pack)
	local ret = joinLottery(actor)

	--不能重复摇骰子
	if 0 == ret then return end

	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_ReturnJoinLottery)
	if npack == nil then 
		return
	end
	LDataPack.writeInt(npack,ret)
	LDataPack.flush(npack)
	sendLotteryWin()
end

local function checkDistributionById(guild_id,distribution_id,actors)
	if guild_id == 0 then 
		return false
	end
	local guild_ptr = LGuild.getGuildById(guild_id)
	local var       = getDistributionDataById(guild_id)
	local rank      = guildbattlepersonalaward.getRanking(guild_id)
	if GuildBattleDistributionAward[rank] == nil then 
		return false
	end
	local conf = GuildBattleDistributionAward[rank][distribution_id]
	if conf == nil then 
		return false
	end

	--判断奖励类型是否跟活动类型一致
	if conf.rewardFlag then
		local actType = guildbattle.getActType()
		if conf.rewardFlag ~= actType then
			print("guildbattlefb.checkDistributionById: type not same, rewardFlag:"..tostring(conf.rewardFlag)..", actType:"..tostring(actType))
			return false
		end
	end

	if conf.count ~= #actors then 
		System.log("guildbattlefb", "checkDistributionById", "mark1", guild_id, #actors, conf.count)
		return false
	end
	for i,v in pairs(actors) do 
		if not LGuild.isMember(guild_ptr,v) then 
			print(guild_id .. "  没有成员 " .. v )
			System.log("guildbattlefb", "checkDistributionById", "mark2", guild_id, v)
			return false
		end
	end
	if var.distribution_ids[distribution_id] ~= nil then 
		System.log("guildbattlefb", "checkDistributionById", "mark3", guild_id, distribution_id)
		return false
	end
	return true
end

local function getDistributionAward(guild_id,distribution_id,actors) --得到分配奖励
	if not checkDistributionById(guild_id,distribution_id,actors) then
		System.log("guildbattlefb", "getDistributionAward", "mark1")
		return false
	end
	local guild_ptr = LGuild.getGuildById(guild_id)
	local var       = getDistributionDataById(guild_id)
	local rank      = guildbattlepersonalaward.getRanking(guild_id)
	if GuildBattleDistributionAward[rank] == nil then 
		System.log("guildbattlefb", "getDistributionAward", "mark2")
		return false
	end
	local conf = GuildBattleDistributionAward[rank][distribution_id]
	if conf == nil then 
		System.log("guildbattlefb", "getDistributionAward", "mark3")
		return false
	end
	var.distribution_ids[distribution_id] = true

	local a_var = {}
	for i,v in pairs(actors) do 
		if a_var[v] == nil then 
			a_var[v] = 1
		else 
			a_var[v] = a_var[v] + 1
		end
	end

	for i,v in pairs(a_var) do 
		local mail_data = {}
		mail_data.head       = GuildBattleConst.distributionAwardHead
		mail_data.context    = GuildBattleConst.distributionAwardContext
		mail_data.tAwardList = {}
		--conf.award
		for j = 1,v do 
			for z,zv in pairs(conf.award) do 
				table.insert(mail_data.tAwardList,zv)
			end
		end
		LActor.log(i, "guildbattlefb.getDistributionAward", "sendMail")
		mailsystem.sendMailById(i,mail_data)

	end
	local str = "会长分配了" .. ItemConfig[conf.award[1].id].name .. ":  "
	for i,v in pairs(a_var) do 
		local basic_data = LActor.getActorDataById(i)
		if basic_data ~= nil then
			str = str .. basic_data.actor_name .. v .. "份 "
		end
	end
	guildchat.sendNotice(LGuild.getGuildById(guild_id),str)

	return true
end

local function onDistributionAward(actor,pack)
	local guild_id = LActor.getGuildId(actor)
	if guild_id == 0 then 
		return
	end
	if not guildbattle.isLeader(actor) then 
		return
	end

	local function sendRet(ok)
		local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_DistributionAward)
		if npack == nil then 
			return
		end
		LDataPack.writeByte(npack,ok and 1 or 0)
		LDataPack.flush(npack)
	end
	if isOpen() then 
		sendRet(false) 
		sendDistributionData(actor)
		return
	end
	if checkDistribution(guild_id) then 
		sendRet(false)
		return
	end
	local count = LDataPack.readInt(pack)
	local rank = guildbattlepersonalaward.getRanking(guild_id)
	local conf  = GuildBattleDistributionAward[rank]
	if conf == nil then 
		sendRet(false)
		sendDistributionData(actor)
		return
	end
	
	local i   = 0
	local arr = {}
	local arr_text_id = {}
	while (i < count) do 
		local id        = LDataPack.readInt(pack)
		local actors    = {}
		local count_arr = LDataPack.readInt(pack)
		local j         = 0

		while (j < count_arr) do
			local actor_id = LDataPack.readInt(pack)
			local z              = 0
			local count_acotr_id = LDataPack.readInt(pack)
			while (z < count_acotr_id) do 
				table.insert(actors,actor_id)
				z = z + 1
			end
			j = j + 1
		end
		if arr_text_id[id] ~= nil then 
			log_print(" guildbattlefb.onDistributionAward: repeat_id  " .. id)
			sendRet(false)
			sendDistributionData(actor)
			return 
		end
		arr_text_id[id] = true
		arr[id] = actors
		i = i + 1
	end
	for i,v in pairs(arr) do 
		if not checkDistributionById(guild_id,i,v) then 
			sendRet(false)
			sendDistributionData(actor)
			return
		end
	end
	for i,v in pairs(arr) do 
		getDistributionAward(guild_id,i,v)
	end
	sendRet(true)
	sendDistributionData(actor)
end


local function onGotoFlags(actor,pack)
	gotoFlags(actor)
end

local function onWinGuildInfo(actor,pack)
	sendWinGuidInof(actor)
end

function sendSceneFeats(actor)
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_SceneFeats)
	if npack == nil then 
		return
	end
	LDataPack.writeInt(npack,getSceneFeats(actor))
	LDataPack.flush(npack)
end

function sendDataForScene(pack) -- 广播数据到所有活动场景
	if not isOpen() then 
		return
	end
	for i,v in pairs(GuildBattleLevel) do 
		if i ~= city_within then 
			Fuben.sendData(guild_battle_fb[i].hfuben,pack)
		else
			for j,jv in pairs(guild_battle_fb[i].hfubens) do 
				Fuben.sendData(jv,pack)
			end
		end

	end
end

function sendDataForSceneById(pack,id) -- 广播数据到指定id的场景
	if not isOpen() then 
		return
	end
	if guild_battle_fb[id] == nil then
		return
	end
	local i = id
	if i ~= city_within then 
		Fuben.sendData(guild_battle_fb[i].hfuben,pack)
	else
		for j,jv in pairs(guild_battle_fb[i].hfubens) do 
			Fuben.sendData(jv,pack)
		end
	end
end

function makeSendFlagsData(npack)  -- 生成flags data 的数据包
	local var = getFlagsData()   
	local now_t = System.getGameTick() 
	LDataPack.writeShort(npack,var.status)
	if var.status == 0 then  -- 不可采集
		local sec = 0
		if var.wait_tick > now_t then 
			sec = var.wait_tick - now_t
			sec = sec / 1000
		end
		LDataPack.writeInt(npack,sec)
	elseif var.status == 2 then --采集中
		local sec = 0

		if var.gather_tick > now_t then 
			sec = var.gather_tick - now_t 
			sec = sec / 1000
		end
		LDataPack.writeString(npack,var.gatherers_name)
		LDataPack.writeInt(npack,var.gatherers_actor_id)
		LDataPack.writeInt(npack,sec)
		LDataPack.writeString(npack,var.gatherers_guild)
	end
end

function sendFlagsData(actor)
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_FlagsData)
	if npack == nil then 
		return false
	end
	makeSendFlagsData(npack)
	LDataPack.flush(npack)
end

function broadcastFlagsData()
	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_FlagsData)
	if npack == nil then 
		return false
	end
	makeSendFlagsData(npack)
	sendDataForScene(npack)
end

function broadcastFlagsGather()
	noticemanager.broadCastNotice(GuildBattleConst.flagsGatherNotice)
end

function broadcastImperialPalaceAttributionData()
	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_ImperialPalaceAttribution)
	if not npack then 
		return
	end
	LDataPack.writeString(npack,guildbattlepersonalaward.getImperialPalaceAttribution())
	sendDataForScene(npack)
end

function broadcastShield(hp,max)
	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_ShieldData)
	if npack == nil then 
		return
	end
	LDataPack.writeInt(npack,hp)
	LDataPack.writeInt(npack,max)
	sendDataForSceneById(npack,imperial_palace)
end

function currGatherFlagsNotice()
	local var = getFlagsData()
	local actor = LActor.getActorById(var.gatherers_actor_id)
	if actor == nil then 
		return
	end
	local guild_id = LActor.getGuildId(actor) 
	if guild_id == 0 then 
		return
	end
	local guild_ptr = LActor.getGuildPtr(actor) 
	local guild_name  = LGuild.getGuildName(guild_ptr)
	noticemanager.broadCastNotice(GuildBattleConst.flagsCurrGatherNotice,guild_name,LActor.getName(actor))
end

function sendImperialPalaceAttribution(actor)
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_ImperialPalaceAttribution)
	if npack == nil then 
		return
	end
	LDataPack.writeString(npack,guildbattlepersonalaward.getImperialPalaceAttribution())
	LDataPack.flush(npack)

end
--------------
-------------
function onInit(actor)
	initData(actor)
	rsfData(actor)
end

function onLogin(actor)
	sendSceneFeats(actor)
	sendDistributionData(actor)
	sendWinGuidInof(actor)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit,onInit)
netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_Enter, onEnter)
netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_EnterNext, onEnterNext)
netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_GotoFlags, onGotoFlags)
--netmsgdispatcher.reg(Protocol.CMD_Base, Protocol.cBaseCmd_SwitchTarget,onSwitchTarget)
netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_DistributionAward, onDistributionAward)
netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_WinGuildInfo, onWinGuildInfo)
netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_RequestJoinLottery, onJoinLottery)
_G.setGuildBattleFlagsStatus           = setFlagsStatus
_G.setGuildBattleFlagsWaitTick         = setFlagsWaitTick
_G.setGuildBattleFlagsGatherersName    = setFlagsGatherersName
_G.setGuildBattleFlagsGatherersGuild    = setFlagsGatherersGulid
_G.setGuildBattleFlagsGatherTick       = setFlagsGatherTick
_G.setGuildBattleFlagsGatherersActorId = setFlagsGatherersActorId
_G.broadcastGuildBattleFlagsData       = broadcastFlagsData
_G.setGuildBattleWinGuild              = setGuildBattleWinGuild
_G.broadcastGuildBattleShield          = broadcastShield
_G.broadcastGuildBattleFlagsGather     = broadcastFlagsGather
_G.guildBattleCurrGatherFlagsNotice    = currGatherFlagsNotice

initGlobalData()
initFbCallBack()



