module("tianti", package.seeall)


local day_sec      = 24 * (60 * 60)
local week_sec     = 7 * day_sec
local end_time     = (22 * (60 * 60))
local refresh_time     = (22 * (60 * 60)) + (30 * 60)
local begin_time   = 10 * (60 * 60)
local end_week     = 7
local begin_week   = 1
--local tianti_init  = false
local tianti_openg = false


local function isOpenTime(t)
	local week = utils.getWeek(t)
	local after_sec = (t + System.getTimeZone()) % day_sec
	if week == end_week and after_sec >= end_time then 
		return false
	end
	if week == begin_week and after_sec < begin_time then 
		return false
	end
	return true
	
end

local function getData(actor)
	local var = LActor.getStaticVar(actor) 
	if var == nil then 
		return nil 
	end
	if var.tianti == nil then 
		var.tianti = {}
	end
	return var.tianti
end

local function isOpen(actor)
	local level = (LActor.getZhuanShengLevel(actor) * 1000) + LActor.getLevel(actor)
	if level >= TianTiConstConfig.openLevel then
		return true
	end
	return false
end

local function isDiamond(actor)
	local var = getData(actor)
	local conf = TianTiConstConfig.diamond
	return conf.level == var.level and conf.id == var.id
end

local function sendbuyChallengesCount(actor)
	if isOpen(actor) == false then 
		return
	end
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_Tianti,Protocol.sTiantiCmd_BuyChallengesCount)
	if npack == nil then
		return
	end

	local var = getData(actor)
	LDataPack.writeInt(npack,var.buy_challenges_count)
	LDataPack.flush(npack)
end

local function setChallengesCountCdTimer(actor, notSendData)
	if isOpen(actor) == false then
		return
	end
	local var = getData(actor)
	local curr_time = os.time()
	if var.challenges_count < TianTiConstConfig.maxRestoreChallengesCount then 
		local save_time = var.challenges_count_cd_time + var.challenges_count_cd
		if save_time > curr_time then 
			var.challenges_count_cd = save_time - curr_time
		else 
			local add = 1 
			add = add + math.floor((curr_time - save_time) / TianTiConstConfig.challengesCountCd)
			var.challenges_count_cd = math.floor(TianTiConstConfig.challengesCountCd - ((curr_time - save_time) % TianTiConstConfig.challengesCountCd))
			var.challenges_count = var.challenges_count + add
			if var.challenges_count >=  TianTiConstConfig.maxRestoreChallengesCount then 
				var.challenges_count = TianTiConstConfig.maxRestoreChallengesCount
				var.challenges_count_cd = 0
			end
		end
		if notSendData ~= true then
			sendTiantiData(actor)
		end
	end
	var.challenges_count_cd_time = curr_time
	if var.cdtimeid ~= nil then
		LActor.cancelScriptEvent(actor, var.cdtimeid)
		var.cdtimeid = nil
	end
	if var.challenges_count_cd ~= 0 then 
		var.cdtimeid = LActor.postScriptEventLite(actor,var.challenges_count_cd * 1000,setChallengesCountCdTimer,actor)
	--else 
	--	var.cdtimeid = LActor.postScriptEventLite(actor,TianTiConstConfig.challengesCountCd * 1000,setChallengesCountCdTimer, actor)
	end
end

function sendTiantiData(actor) 
	if isOpen(actor) == false then 
		return
	end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Tianti, Protocol.sTiantiCmd_TianData)
	if npack == nil then 
		return 
	end
	setChallengesCountCdTimer(actor, true)
	local open = isOpen(actor) and isOpenTime(os.time())
	LDataPack.writeByte(npack,open and 1 or 0)
	local var = getData(actor)
	LDataPack.writeInt(npack,var.level or 0)
	LDataPack.writeInt(npack,var.id or 0)
	LDataPack.writeInt(npack,var.challenges_count or 0)
	LDataPack.writeInt(npack,var.challenges_count_cd or 0)
	LDataPack.writeInt(npack,var.win_count or 0)
	LDataPack.writeByte(npack,var.winning_streak >= 2 and 1 or 0)
	local last_week_join = var.differ_week == 1
	LDataPack.writeByte(npack,last_week_join and 1 or 0)
	if last_week_join then
		LDataPack.writeByte(npack,var.get_last_week_award == 0 and 1 or 0)
		LDataPack.writeInt(npack,var.last_level or 0)
		LDataPack.writeInt(npack,var.last_id or 0)
		LDataPack.writeInt(npack,var.last_win_count or 0)
	end
	LDataPack.flush(npack)
end

local function getGlobalData()
	local var = System.getStaticVar()
	if var == nil then 
		return nil 
	end
	if var.tianti == nil then 
		var.tianti = {}
	end
	if var.tianti_open == nil then
		var.tianti_open = 0
	end

	return var.tianti
end

local function OpenTianti(isNotice)
	print("OpenTianti,isNotice:"..tostring(isNotice))
	tianti_openg = true
	local actors = System.getOnlineActorList()
	if actors ~= nil then
		for i =1,#actors do
			sendTiantiData(actors[i])
		end
	end

	if isNotice then 
		-- 发公告
		local last = tiantirank.getLastWeekFirstActorName()
		if last ~= nil then
			noticemanager.broadCastNotice(TianTiConstConfig.openBroadcastNotice[1],last)
		else 
			noticemanager.broadCastNotice(TianTiConstConfig.openBroadcastNotice[2])
		end
	end
end

local function CloseTianti()
	print("CloseTianti")
	tiantirank.refreshWeek()
	LActor.tiantiRefreshWeek()

	local  actors = System.getOnlineActorList()
	if actors ~= nil then
		for i =1,#actors do
			refreshWeek(actors[i])
			getDanAwardMail(actors[i])
			sendTiantiData(actors[i])
		end
	end

	--print("发公告")
	-- 发公告
	local last = tiantirank.getLastWeekFirstActorName()
	if last ~= nil then
		noticemanager.broadCastNotice(TianTiConstConfig.closeBroadcastNotice[1],last)
	else 
		noticemanager.broadCastNotice(TianTiConstConfig.closeBroadcastNotice[2])
	end
	tianti_openg = false
end

--服务器启动时,检测是否需要开启天梯
local function CheckTianti()
	print("tianti,CheckTianti")
	if (isOpenTime(os.time())) then
		OpenTianti(false)
		local  actors = System.getOnlineActorList()
		if actors ~= nil then
			for i =1,#actors do
				sendTiantiData(actors[i])
			end
		end
	end
end

--这里是给scripttimer用的
_G.OpenTianti = OpenTianti 
_G.CloseTianti = CloseTianti
--服务器事件
engineevent.regGameStartEvent(CheckTianti)

--更新数据到C++玩家基础数据
local function updateBasicData(actor)
	local basic_data = LActor.getActorData(actor) 
	local var = getData(actor)
	basic_data.tianti_level = var.level
	basic_data.tianti_dan = TianTiDanConfig[var.level][var.id].showDan
	basic_data.tianti_win_count = var.win_count
	basic_data.tianti_week_refres = var.week_time;
end

--初始化数据
local function initData(actor)
	if isOpen(actor) == false then 
		return
	end
	local var = getData(actor)
	if var.level == nil then 
		var.level = 1
	end
	if var.id == nil  then 
		var.id = 0
	end
	if var.last_level == nil then
		var.last_level = 0
	end
	if var.last_id == nil then 
		var.last_id = 0
	end
	if var.challenges_count == nil then 
		var.challenges_count = TianTiConstConfig.maxRestoreChallengesCount 
		-- 挑战次数
	end
	if var.challenges_count_cd_time == nil then 
		var.challenges_count_cd_time = os.time()
		-- 挑战次数的cd的开始时间
	end
	if var.challenges_count_cd == nil then 
		var.challenges_count_cd = 0
		-- 挑战次数的cd  
	end
	if var.win_count == nil then 
		var.win_count = 0 
		-- 本周净胜场 
	end
	if var.last_win_count == nil then 
		var.last_win_count = 0
		-- 上周净胜场
	end
	if var.winning_streak == nil then 
		var.winning_streak = 0
		-- 是否连胜
	end
	if var.buy_challenges_count == nil then 
		var.buy_challenges_count = 0
		-- 购买挑战次数的次数
	end
	if var.differ_week == nil then 
		var.differ_week = 0
		-- 跟开始时间相差多少周(结计算领取奖励用的)
	end
	if var.get_last_week_award == nil then 
		var.get_last_week_award = 0
		-- 是否得到上周奖励
	end
	if var.time == nil then 
		var.time = os.time()
	end
	if var.week_time == nil then 
		var.week_time = 0
	end

	while(TianTiDanConfig[var.level][var.id] == nil ) do 
		var.id = var.id - 1
	end

	if var.last_level ~= 0  then
		while(TianTiDanConfig[var.last_level][var.last_id] == nil ) do 
			var.last_id = var.last_id - 1
		end
	end
	if var.enter_fuben == nil then 
		var.enter_fuben = 0
	end
	updateBasicData(actor)
end

local function refreshDay(actor)
	if isOpen(actor) == false then 
		return
	end
	print("tianti.refreshDay,actor_id:"..LActor.getActorId(actor))
	local var = getData(actor)  
	local curr_time = os.time()
	if utils.getDay(var.time) == utils.getDay(curr_time) then 
		return
	end
	var.buy_challenges_count = 0
	var.time = curr_time
end

function refreshWeek(actor) 
	if isOpen(actor) == false then 
		return
	end
	local var = getData(actor)  
	local curr_time = os.time() 
	if curr_time < var.week_time then 
		return 
	end
	var.differ_week = math.floor((curr_time - var.week_time) / week_sec) == 0 and 1 or 0
	if var.week_time == 0 then 
		var.differ_week = 0
		var.level       = 0
		var.id          = 0
	end
	var.buy_challenges_count     = 0
	var.last_level               = var.level
	var.last_id                  = var.id
	var.last_win_count           = var.win_count
	var.level                    = 1
	var.id                       = 0
	var.winning_streak           = 0
	var.win_count                = 0
	--var.challenges_count         = TianTiConstConfig.maxRestoreChallengesCount
	--var.challenges_count_cd      = 0
	var.get_last_week_award      = 0
	--var.challenges_count_cd_time = os.time()
	local time   = utils.getWeeks(curr_time) * week_sec -- 取整周的秒数
	time = time + ((end_week - 1) * day_sec) + refresh_time -- 算出刷新时间
	time = time - (System.getTimeZone() + (3 * day_sec)) -- 时差
	if var.week_time == time then 
		time = time + week_sec
	end
	var.week_time = time
	--print("refresh week " .. LActor.getActorId(actor))
--	var.time = curr_time
	updateBasicData(actor)
	sendTiantiData(actor)
end

function gmResetTianti(actor)
	System.getStaticVar().tianti_gm = System.getStaticVar().tianti_gm or {}
	local sysvar = System.getStaticVar().tianti_gm
	local var = getData(actor)
	if sysvar.gm_reset_time ~= nil and (var.gm_reset_time == nil or var.gm_reset_time ~= sysvar.gm_reset_time)  then 
		var.gm_reset_time = sysvar.gm_reset_time
		var.win_count     = 0
		var.level         = 1
		var.id            = 0
		updateBasicData(actor)
		sendTiantiData(actor)
		print(LActor.getActorId(actor) .. " gmResetTianti")
	end
end

local function buyChallengesCount(actor)
	if isOpen(actor) == false then 
		return false
	end
	local var = getData(actor) 
	if var.buy_challenges_count > TianTiConstConfig.maxBuyChallengesCount then 
		return false
	end
	local need_money = TianTiConstConfig.buyChallengesCountYuanBao
	if need_money > LActor.getCurrency(actor, NumericType_YuanBao) then
		print("not yuanBao")
		return false
	end
	LActor.changeYuanBao(actor,-need_money, "tianti buy challenges count")
	var.buy_challenges_count = var.buy_challenges_count + 1
	var.challenges_count     = var.challenges_count + 1
	if var.challenges_count   >= TianTiConstConfig.maxRestoreChallengesCount then 
		var.challenges_count_cd = 0
		var.challenges_count_cd_time = os.time()
	end
	return true
end

local function addId(actor,size)
	if isOpen(actor) == false then 
		return
	end
	local var = getData(actor)
	if size == 0 then 
		return 0
	end
	if size > 0 then 
		if TianTiDanConfig[var.level][var.id + 1] == nil and var.id ~= 0 then
			if TianTiDanConfig[var.level + 1] ~= nil then
				var.level = var.level + 1
				var.id = 0
				local conf = TianTiDanConfig[var.level][var.id]
				noticemanager.broadCastNotice(conf.notice,LActor.getActorName(LActor.getActorId(actor)))
			end
		elseif TianTiDanConfig[var.level][var.id + 1] ~= nil then
			var.id = var.id + 1
			local conf = TianTiDanConfig[var.level][var.id]
			noticemanager.broadCastNotice(conf.notice,LActor.getActorName(LActor.getActorId(actor)))
		else 
			return 0
		end
		return addId(actor,size - 1) + 1
	else
		if TianTiDanConfig[var.level][var.id].isDropStar == 1 and var.id ~= 0 then 
			var.id = var.id - 1
			return addId(actor,size + 1) - 1
		else 
			return 0
		end
	end
end

function sendAwardNotice(actor,awards)
	for i,v in pairs(awards) do 
    	if v.type == AwardType_Item and ItemConfig[v.id] and ItemConfig[v.id].needNotice == 1 then
            noticemanager.broadCastNotice(TianTiConstConfig.awardNotice,
            LActor.getName(actor), ItemConfig[v.id].name)
        end
	end
end

function challengesResult(actor,win)
	if isOpen(actor) == false then 
		return
	end
	local var = getData(actor) 
	if win then 
		var.win_count = var.win_count + 1
	else 
		var.win_count = var.win_count - 1
	end
	if var.win_count < 0 then 
		var.win_count = 0
	end

	--第一次打用特殊掉落组
	local dropId = TianTiDanConfig[var.level][var.id].winAward
	if not var.firstReward and TianTiConstConfig.firstReward then
		dropId = TianTiConstConfig.firstReward
		var.firstReward = 1
	end

	local win_award        = drop.dropGroup(dropId)
	local last_id          = var.id
	local last_level       = var.level
	local add              = 0
	local WinningStreakAdd = TianTiDanConfig[var.level][var.id].WinningStreak
	sendAwardNotice(actor,win_award)

	LActor.giveAwards(actor,win_award,"tianti win award")

	if win then
		if var.winning_streak >= 2 then
			add = addId(actor,WinningStreakAdd)
		else 
			add = addId(actor,1)
		end
		var.winning_streak = var.winning_streak + 1
	else 
		var.winning_streak = 0
		add = addId(actor,-1)
	end
	updateBasicData(actor)
	--if isDiamond(actor) then 
		tiantirank.updateRankingList(actor,var.win_count)
	--end
	sendTiantiData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Tianti, Protocol.sTiantiCmd_EndChallenges)
	if npack == nil then 
		return 
	end
	LDataPack.writeByte(npack,win and 1 or 0)
	LDataPack.writeShort(npack,#win_award)
	for i,v in pairs(win_award) do
		LDataPack.writeInt(npack,v.type)
		LDataPack.writeInt(npack,v.id)
		LDataPack.writeInt(npack,v.count)
	end
	LDataPack.writeInt(npack,last_level)
	LDataPack.writeInt(npack,last_id)
	LDataPack.writeInt(npack,math.abs(add))
	LDataPack.flush(npack)

	actorevent.onEvent(actor, aeTianTiLevel, var.level, var.id)
end

local function getDanAward(actor) 
	if isOpen(actor) == false then
		return 
	end
	local var = getData(actor)
	if var.differ_week == 1 and var.get_last_week_award == 0 then 
		local danAward = TianTiDanConfig[var.last_level][var.last_id].danAward
		LActor.giveAwards(actor,danAward,"tianti dan award")
		--print("getDanAward")
		var.get_last_week_award = 1
	end
	sendTiantiData(actor)
end

function getDanAwardMail(actor)
	if isOpen(actor) == false then
		return 
	end
	
	local var = getData(actor)
	if var.differ_week == 1 and var.get_last_week_award == 0 and var.last_level ~= 0 then 
		local danAward = TianTiDanConfig[var.last_level][var.last_id].danAward
		--LActor.giveAwards(actor,danAward,"tianti dan award")
		--print("getDanAward")
		--邮件内容
		local mailData = {head=TianTiConstConfig.danMailHead, context=TianTiConstConfig.danMailContext, tAwardList=danAward}
		--发邮件
		mailsystem.sendMailById(LActor.getActorId(actor), mailData)
		var.get_last_week_award = 1
	end
end

local function matchingActor(actor)
	if isOpen(actor) == false then 
		return 0
	end
	if tianti_openg == false then 
		return 0
	end
	return LActor.findTiantiActor(actor)
end

local function CreateFb(actor,actor_id)
	if isOpen(actor) == false then 
		return false
	end
	if tianti_openg == false then 
		return false
	end
	if actor_id == 0 then 
		return false
	end
	if LActor.isInFuben(actor) then
		print(LActor.getActorId(actor).." tianti CreateFb, isInFuben")
		return false
	end
	local var = getData(actor)
	local conf = TianTiConstConfig.fuBen
	local hfuben = Fuben.createFuBen(conf.fuBen)
	if hfuben == 0 then return end
	local ins = instancesystem.getInsByHdl(hfuben)
	if ins == nil then return end
	var.enter_fuben = 1
	LActor.enterFuBen(actor, hfuben,0,conf.self_x,conf.self_y)
	LActor.createRoldClone(actor_id,ins.scene_list[1],conf.target_x,conf.target_y)
	--天梯成就
	actorevent.onEvent(actor, aeHegemony,1)
	return true
end

local function CreateFbByRobot(actor,root_id)
	if isOpen(actor) == false then 
		return false
	end
	if tianti_openg == false then 
		return false
	end
	if root_id == 0 then 
		return false
	end
	local rconf = TianTiRobotConfig[root_id]
	if rconf == nil then 
		return false
	end
	if LActor.isInFuben(actor) then
		print(LActor.getActorId(actor) .. " 已经在副本中了 ")
		return false
	end
	local var = getData(actor)
	local conf = TianTiConstConfig.fuBen
	local hfuben = Fuben.createFuBen(conf.fuBen)
	if hfuben == 0 then return end
	local ins = instancesystem.getInsByHdl(hfuben)
	if ins == nil then return end
	var.enter_fuben = 1
	LActor.enterFuBen(actor, hfuben,0,conf.self_x,conf.self_y)
	for i ,v in pairs(rconf) do
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
		LActor.createRobot(d,ins.scene_list[1],conf.target_x,conf.target_y)
	end
	return true
end

local function onInit(actor)
	initData(actor)
	refreshWeek(actor);
	refreshDay(actor)
end


local function onLogin(actor)
	getDanAwardMail(actor)
	gmResetTianti(actor)
	initData(actor)	
	local var = getData(actor)
	var.cdtimeid = nil
	sendTiantiData(actor)
	sendbuyChallengesCount(actor)
end



local function onLevel(actor)
	initData(actor)
	refreshWeek(actor);
	refreshDay(actor)

	sendbuyChallengesCount(actor)
	sendTiantiData(actor)
end

local function onNewDay(actor) 
	initData(actor)
	refreshWeek(actor);
	refreshDay(actor)
	sendTiantiData(actor)
	sendbuyChallengesCount(actor)
end 

-- net 
local function onMatchingActor(actor,packet)
	if isOpen(actor) == false then 
		print("actor not open")
		return
	end
	if tianti_openg == false then
		print("tianti not open")
		return 
	end
	local var = getData(actor)
	local actor_id = matchingActor(actor)
	if (var.challenges_count - 1) < 0 then 
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Tianti, Protocol.sTiantiCmd_MatchingActor)
		if npack == nil then 
			return 
		end
		LDataPack.writeInt(npack,0)
		LDataPack.writeInt(npack,0)
		var.matching_type = nil
		LDataPack.flush(npack)
		return 
	end
	
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Tianti, Protocol.sTiantiCmd_MatchingActor)
	if npack == nil then 
		return 
	end
	
	var.is_matching = nil
	if LActor.isInFuben(actor) then 
		LDataPack.writeInt(npack,0)
		LDataPack.writeInt(npack,0)
	elseif actor_id ~= 0 then --匹配玩家成功
		LDataPack.writeInt(npack,0)
		LDataPack.writeInt(npack,actor_id)
		local basic_data = LActor.getActorDataById(actor_id)
		LDataPack.writeString(npack,basic_data.actor_name)
		LDataPack.writeByte(npack,basic_data.job)
		LDataPack.writeByte(npack,basic_data.sex)
		LDataPack.writeInt(npack,basic_data.tianti_level)
		LDataPack.writeInt(npack,basic_data.tianti_dan)
		var.is_matching = {}
		var.is_matching.type = 0
		var.is_matching.id = actor_id
	else
		local conf = TianTiDanConfig[var.level][var.id]
		if conf.MatchingRobot == 1 then
			local id = math.random(1,#TianTiRobotConfig)
			if TianTiRobotConfig[id] == nil then 
				print("tianti.onMatchingActor not has robot cfg " .. id)
				LDataPack.writeInt(npack,0)
				LDataPack.writeInt(npack,0)
			else 
				local rconf = TianTiRobotConfig[id][0]
				if rconf == nil then
					LDataPack.writeInt(npack,0)
					LDataPack.writeInt(npack,0)
				else --匹配机器人成功
					LDataPack.writeInt(npack,1)
					LDataPack.writeInt(npack,id)
					LDataPack.writeString(npack,rconf.name)
					LDataPack.writeByte(npack,rconf.job)
					LDataPack.writeByte(npack,rconf.sex)
					LDataPack.writeInt(npack,rconf.TianTiLevel)
					LDataPack.writeInt(npack,rconf.TianTiDan)
					var.is_matching = {}
					var.is_matching.type = 1
					var.is_matching.id = id
				end
			end
		else 
			LDataPack.writeInt(npack,0)
			LDataPack.writeInt(npack,0)
		end
	end
	LDataPack.flush(npack)
	if var.is_matching ~= nil then 
		var.challenges_count = var.challenges_count - 1
		if var.challenges_count < TianTiConstConfig.maxRestoreChallengesCount then 
			if var.challenges_count_cd == 0 then
				var.challenges_count_cd_time = os.time()
				var.challenges_count_cd = TianTiConstConfig.challengesCountCd
			end
		end
		sendTiantiData(actor)
	end
end

local function onBeginChallenges(actor,packet)
	local type = LDataPack.readInt(packet)
	local actor_id = LDataPack.readInt(packet)
	local var = getData(actor)
	if var.is_matching == nil then 
		print(LActor.getActorId(actor) .. " tianti.onBeginChallenges, not have match")
		return
	end
	if var.is_matching.type ~= type or var.is_matching.id ~= actor_id then
		print(LActor.getActorId(actor) .. " tianti.onBeginChallenges, match info err")
	end
	if var.is_matching.type == 1 then
		CreateFbByRobot(actor,var.is_matching.id)
	else
		CreateFb(actor,var.is_matching.id)
	end
	var.is_matching = nil
end

local function onGetLastWeekAward(actor,packet)
	getDanAward(actor)
end
local function onRankData(actor,packet)
	tiantirank.notifyRankingList(actor)
end

local function onbuyChallengesCount(actor,packet)
	buyChallengesCount(actor)
	sendbuyChallengesCount(actor)
	sendTiantiData(actor)
end

-- exern 
--

function getLevel(actor)
	if isOpen(actor) == false then 
		return 0
	end
	local var = getData(actor) 
	return var.level
end

function getId(actor)
	if isOpen(actor) == false then 
		return 0
	end
	local var = getData(actor) 
	return var.id
end

function getWinCount(actor)
	if isOpen(actor) == false then 
		return 0
	end
	local var = getData(actor) 
	return var.win_count
end

function getOpenLevel()
	return TianTiConstConfig.openLevel
end

function getBeginLevel()
	return TianTiConstConfig.beginLevel
end

function setTianti(actor,level,id)
	local var = getData(actor)
	var.level = level
	var.id    = id
	updateBasicData(actor)
	sendTiantiData(actor)
end


function getBeginShowDan()
	return TianTiConstConfig.beginShowDan
end

function getLastTiantiLevel(actor)
	if isOpen(actor) == false then 
		return 0
	end
	local var = getData(actor)
	return var.last_level or 0
end


_G.getTiantiBeginLevel = getBeginLevel
_G.getTiantiBeginShowDan = getBeginShowDan
_G.getTiantiOpenLevel = getOpenLevel
_G.tiantiRefreshWeek = refreshWeek

--net end
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)
actorevent.reg(aeLevel, onLevel)
actorevent.reg(aeNewDayArrive,onNewDay)
netmsgdispatcher.reg(Protocol.CMD_Tianti, Protocol.cTiantiCmd_MatchingActor, onMatchingActor)
netmsgdispatcher.reg(Protocol.CMD_Tianti, Protocol.cTiantiCmd_BeginChallenges, onBeginChallenges)
--netmsgdispatcher.reg(Protocol.CMD_Tianti, Protocol.cTinatiCmd_GetLastWeekAward, onGetLastWeekAward)
netmsgdispatcher.reg(Protocol.CMD_Tianti, Protocol.cTiantiCmd_RankData, onRankData)
netmsgdispatcher.reg(Protocol.CMD_Tianti, Protocol.cTiantiCmd_BuyChallengesCount, onbuyChallengesCount)

local function onFuBenFunc(ins,actor)
	if actor == nil then 
		actor = ins:getActorList()[1]
	end
	if actor == nil then 
		return
	end
	local var = getData(actor)
	if var.enter_fuben == 1 then
		if LActor.cloneRoleEmpty(ins.scene_list[1])  then 
			challengesResult(actor,true)
		else 
			challengesResult(actor,false)
		end
		var.enter_fuben = 0
	end
	ins:lose()
end

local function onCloneRoleDie(ins)
	local actor = ins:getActorList()[1]
	if actor == nil then 
		return
	end
	if LActor.cloneRoleEmpty(ins.scene_list[1])  then 
		ins:win()
	end
end

local function fuBenInit()
	local conf = TianTiConstConfig.fuBen
	insevent.registerInstanceWin(conf.fuBen, onFuBenFunc)
	insevent.registerInstanceExit(conf.fuBen,onFuBenFunc)
	insevent.registerInstanceOffline(conf.fuBen,onFuBenFunc)
	insevent.registerInstanceActorDie(conf.fuBen,onFuBenFunc)
	insevent.regCloneRoleDie(conf.fuBen,onCloneRoleDie)
	tianti_openg = isOpenTime(os.time())
end
table.insert(InitFnTable, fuBenInit)



function tiantiGmHandle(actor,args)
	if args[1] == 'open' then
		OpenTianti(true)
	elseif args[1] == 'close' then
		CloseTianti()
	elseif args[1] == 'res' then
		challengesResult(actor, tonumber(args[2]) == 1 and true or false)
	else
		LActor.sendTipmsg(actor, [[
			命令使用:
			@tianti open --开启天梯 
			@tianti close --关闭天梯
			@tianti res [1.赢,0.输] --天梯输赢一场
		]], ttScreenCenter)
	end
	return true
end
