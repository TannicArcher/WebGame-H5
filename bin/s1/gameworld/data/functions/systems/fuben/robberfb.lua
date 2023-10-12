
--[[
--保存在系统动态变量中
robberwave: 0 活动未开启， >0 第几轮

--保存在个人
robber = {
	times,  --今日已经挑战的次数
}

--保存在公会中
robber = {	
	total,           --强盗总数
	kill,            --被击杀的强盗
	list = {         --强盗列表      
		[1] = {
			state,  --0 可挑战, 1 战斗中, 2 已击杀
			class,   --强盗类型
		},   
	} 
} 
]]--




module("robberfb", package.seeall)

require("systems.guild.guildchat")

--获取玩家的公会副本信息
local function getActorRobberVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var.robber then
		var.robber = {}
	end
	if not var.robber.times then
		var.robber.times = 0
	end
	return var.robber
end

--获取公会副本信息
local function getRobberfbVar(guild)
	local var = LGuild.getStaticVar(guild, true)
	if not var.robber then
		var.robber = {}
	end
	if not var.robber.total then
		var.robber.total = 0
	end
	if not var.robber.kill then
		var.robber.kill = 0
	end
	if not var.robber.list then  
		var.robber.list = {}
	end
	return var.robber
end

--获取今天活动的开启和结束时间
--[[local function getRobberStartandEnd()
	local year, month, day = System.getDate()
	local startTime = System.timeEncode(year, month, day, robberfbconfig.startTime.h, robberfbconfig.startTime.m, robberfbconfig.startTime.s)
	local endTime   = System.timeEncode(year, month, day, robberfbconfig.endTime.h, robberfbconfig.endTime.m, robberfbconfig.endTime.s)
	return startTime, endTime
end]]--

--获取第几轮
local function getRobberWave()
	local var = System.getDyanmicVar()
	return var.robberwave or 0
end

--设置第几轮
local function setRobberWave(wave)
	local var = System.getDyanmicVar()
	var.robberwave = wave
end

--发送个人的挑战次数
local function SendRobberTimes(actor, times)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_GuildRobber, Protocol.sGuildRobberCmd_times)
	if not pack then return end
	LDataPack.writeByte(pack, times)
	LDataPack.flush(pack)
end

--发送强盗列表
local function SendRobberList(guild, actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_GuildRobber, Protocol.sGuildRobberCmd_list)
	if not pack then return end
	local robberwave = getRobberWave()

	--[[
		判断是否刷新了强盗：防止出现在活动中，新建的公会
	]]--
	local var = getRobberfbVar(guild) 
	if var.total <= 0 then
		robberwave = 0
	end

	LDataPack.writeByte(pack, robberwave)
	print("robberwave:"..robberwave)
	if robberwave > 0 then
		local var = getRobberfbVar(guild)
		LDataPack.writeByte(pack, var.total)
		LDataPack.writeByte(pack, var.kill)
		for i = 1, var.total do
			local state, class = 0, 1
			if var.list[i] then
				if var.list[i].state then
					state = var.list[i].state
				end
				if var.list[i].class then
					class = var.list[i].class
				end
			end 
			LDataPack.writeByte(pack, state)
			LDataPack.writeByte(pack, class)
		end 
	end
	LDataPack.flush(pack)
	print("SendRobberList")
end

--广播：某个强盗状态改变
local function RobberChange(guild, pos, state, kill)
	print("robber pos:"..pos.." state:"..state.." kill:"..kill)
	local pack = LDataPack.allocPacket()
	if not pack then return end
	LDataPack.writeByte(pack, Protocol.CMD_GuildRobber)
	LDataPack.writeByte(pack, Protocol.sGuildRobberCmd_change)
	LDataPack.writeByte(pack, pos)
	LDataPack.writeByte(pack, state)
	LDataPack.writeByte(pack, kill)
	LGuild.broadcastData(guild, pack)
end

--广播：强盗刷新
local function SendRobberRefresh(guild)
	local pack = LDataPack.allocPacket()
	if not pack then return end
	LDataPack.writeByte(pack, Protocol.CMD_GuildRobber)
	LDataPack.writeByte(pack, Protocol.sGuildRobberCmd_refresh)
	local robberwave = getRobberWave()
	LDataPack.writeByte(pack, robberwave)
	LGuild.broadcastData(guild, pack)

	if robberwave > 0 then
		--print("SendRobberRefresh:"..robberfbconfig.refreshNotice)
		--guildchat.sendNoticeEx(guild, robberfbconfig.refreshNotice or "robber is refresh")
	end
end

--给予奖励
local function giveRobberAward(ins, actor)
	local class = ins:onGetCustomVariable("class")
	if class <= 0 then return end 

	local level    = LActor.getLevel(actor)
	local zs_level = LActor.getZhuanShengLevel(actor)

	if zs_level ~= 0 then
		level = zs_level * 1000
	end
	print("robber level:"..level)

	local awards
    if not robberAwardconfig[level] then return end
	if class == 1 then
		awards = robberAwardconfig[level].award_low
	elseif class == 2 then
		awards = robberAwardconfig[level].award_middle
	elseif class == 3 then
		awards = robberAwardconfig[level].award_high
	end

	instancesystem.setInsRewards(ins, actor, awards)

	-- if not awards then return end
	-- if not LActor.canGiveAwards(actor, awards) then --发邮件
	-- 	local Title   = robberfbconfig.title   or "robberfb award"
	-- 	local context = robberfbconfig.context or "robberfb award"
	-- 	local mailData = {
	-- 			head      = Title, 
	-- 			context   = context, 
	-- 			tAwardList= awards
	-- 		}
	-- 	mailsystem.sendMailById(LActor.getActorId(actor), mailData)
	-- else                                             --直接给奖励
	-- 	LActor.giveAwards(actor, awards, "robberfb award")
    -- end
end

--------------------副本逻辑----------------------
--副本胜利
local function onRobberfbWin(ins)
	local actor = ins:getActorList()[1]
	if actor then 
		local info = getActorRobberVar(actor)
		info.times = info.times + 1
		SendRobberTimes(actor, info.times)
		giveRobberAward(ins, actor)
	end

	local wave = ins:onGetCustomVariable("wave")
	if wave ~= getRobberWave() then return end

	local guildId = ins:onGetCustomVariable("guildId")
	local guild = LGuild.getGuildById(guildId)
	if not guild then return end

	local pos = ins:onGetCustomVariable("pos")
	local var = getRobberfbVar(guild)
	if not var.list[pos] then return end

	local var = getRobberfbVar(guild)
	var.list[pos].state = 2
	var.kill = var.kill + 1

	--广播某强盗状态变更
	RobberChange(guild, pos, var.list[pos].state, var.kill)

	--广播击杀公告
	if actor and robberfbconfig.killoneNotice then
		local str = string.format(robberfbconfig.killoneNotice, LActor.getName(actor))
		guildchat.sendNotice(guild, str)
	end

	--判断是否强盗都被杀死
	if var.total == var.kill then
		guildchat.sendNotice(guild, robberfbconfig.killallNotice or "kill all robber")
		LGuild.addGuildLog(guild, 10);  --杀死所有强盗的公会事件
	end
end

--副本失败
local function onRobberfbLose(ins)
	local actor = ins:getActorList()[1]
	if actor then 
		instancesystem.setInsRewards(ins, actor, nil)
	end

	local wave = ins:onGetCustomVariable("wave")
	if wave ~= getRobberWave() then return end

	local guildId = ins:onGetCustomVariable("guildId")
	local guild = LGuild.getGuildById(guildId)
	if not guild then return end

	local pos = ins:onGetCustomVariable("pos")
	local var = getRobberfbVar(guild)
	if not var.list[pos] then return end
	var.list[pos].state = 0
	
	--广播某强盗状态变更
	RobberChange(guild, pos, var.list[pos].state, var.kill)
end

--离开副本
local function onRobberLeave(ins, actor)
	if ins.is_win then return end  --胜利不用发

	ins:lose()
	
	-- local wave = ins:onGetCustomVariable("wave")
	-- if wave ~= getRobberWave() then return end
	
	-- local guildId = ins:onGetCustomVariable("guildId")
	-- local guild = LGuild.getGuildById(guildId)
	-- if not guild then return end
	
	-- local pos = ins:onGetCustomVariable("pos")
	-- local var = getRobberfbVar(guild)
	-- if not var.list[pos] then return end
	-- if var.list[pos].state == 0 then return end --失败不用发
	
	-- --广播某强盗状态变更
	-- var.list[pos].state = 0
	-- RobberChange(guild, pos, var.list[pos].state, var.kill)
end
--------------------响应玩家请求------------------
--挑战强盗
local function onChallenge(actor, reader)
	print("robber onChallenge")
	local guild = LActor.getGuildPtr(actor)
	if not guild then print("robber not guild") return end

	local info = getActorRobberVar(actor)
	if info.times >= robberfbconfig.challengeMax then print("robber time empty") return end

	local robberwave = getRobberWave()
	if robberwave <= 0 then print("robber activity not open") return end

	local pos = LDataPack.readByte(reader)
	print("robber wave:"..robberwave.." pos:"..pos)
	
	local var = getRobberfbVar(guild)
	if var.total < pos then return end
	if not var.list[pos] then print("robber "..pos.." is not exist") return end
	if var.list[pos].state and var.list[pos].state > 0 then
		print("robber pos not free") 
		return 
	end
	
	local class = var.list[pos].class
	if not class then print("robber "..pos.." class not exist") return end

	local fbId = robberfbconfig.fbId[class]
	if not fbId then print("robber fbId is not nil") return end

	local hfuben = Fuben.createFuBen(fbId)
	if hfuben == 0 then 
		print("create robberfb failed. fbId:"..fbId)
		return 
	end
	print("robber challenge fbId:"..fbId.." class:"..class)

	local ins = instancesystem.getInsByHdl(hfuben)
	if not ins then return end
	ins.data.did     = robberfbconfig.id
	ins:onSetCustomVariable("guildId", LGuild.getGuildId(guild))
	ins:onSetCustomVariable("wave", robberwave)
	ins:onSetCustomVariable("pos", pos)
	ins:onSetCustomVariable("class", class)

	if not var.list[pos] then var.list[pos] = {} end 
	var.list[pos].state = 1
	LActor.enterFuBen(actor, hfuben)

	RobberChange(guild, pos, var.list[pos].state, var.kill)
end
netmsgdispatcher.reg(Protocol.CMD_GuildRobber, Protocol.cGuildRobberCmd_challenge, onChallenge)

--请求
local function onQueryRobber(actor)
	local guild = LActor.getGuildPtr(actor)
	if not guild then return end
	SendRobberList(guild, actor)
end
netmsgdispatcher.reg(Protocol.CMD_GuildRobber, Protocol.cGuildRobberCmd_querylist, onQueryRobber)

------------------玩家事件响应-------------------
--玩家登录
local function onLogin(actor)
	local info = getActorRobberVar(actor)
	SendRobberTimes(actor, info.times)

	local guild = LActor.getGuildPtr(actor)
	if not guild then return end
	SendRobberList(guild, actor)
end
actorevent.reg(aeUserLogin, onLogin)

--玩家加入公会
local function onJoninGuild(actor, guild)
	SendRobberList(guild, actor)
end
actorevent.reg(aeJoinGuild, onJoninGuild)

--玩家每天清空
local function onDayClean(actor)
	local Info = getActorRobberVar(actor)
	Info.times   = 0
	SendRobberTimes(actor, Info.times)
end
actorevent.reg(aeNewDayArrive, onDayClean)


-------------------定时函数-----------------------
--剩余强盗警示
function RobberWarn(guild)
	local var = getRobberfbVar(guild)
	if var.total ~= var.kill then
		--guildchat.sendNoticeEx(guild, robberfbconfig.warnText or "robber time is not  enough")
	end
end

function GuildRobberWarn()
    --开服x天前，活动不开启
	local openDay = System.getOpenServerDay() + 1
	--if openDay < robberfbconfig.openDay then return end
	if openDay < guildactivity.getOpenDay(robberfbconfig.activityId) then return end

	print("GuildRobberWarn")
	local guildList = LGuild.getGuildList()
	if guildList == nil then return end
	for i=1,#guildList do
		local guild = guildList[i]
		if guild then RobberWarn(guild) end
	end
end

--刷新强盗
function RefreshRobber(guild, wave)
	--print("RefreshRobber")
	local var = getRobberfbVar(guild)

	var.kill = 0
	var.list = {}

	if wave == 0 then
		var.total = 0
	else
		var.total = #robberfbconfig.robberList
		local len = var.total
		for i = 1, var.total do
			local random = System.getRandomNumber(len) + 1
			local class  = robberfbconfig.robberList[random]
			
			var.list[i] = {}
			var.list[i].class = class
			var.list[i].state  = 0

			robberfbconfig.robberList[random] = robberfbconfig.robberList[len]
			robberfbconfig.robberList[len]    = class

			len = len - 1
			if len <= 0 then break end
		end

		--调试信息
		-- for i = 1, var.total do
		-- 	print("pos:"..i.." class:"..var.list[i].class)
		-- end
	end
	SendRobberRefresh(guild)
end

function RefreshGuildRobber()
	--调试信息
	local h, m, s = System.getTime()
	print("RefreshGuildRobber_hour:"..h.." min:"..m.." sec:"..s)

	local now = System.getNowTime()
	--local startTime, endTime = getRobberStartandEnd()
	local startTime, endTime = guildactivity.getStartandEnd(robberfbconfig.activityId)
	if not startTime or not endTime then
		print("robber guildactivity config is nil")
		return 
	end

	local robberwave = getRobberWave()
	local nextTime, warnTime

	if now >= endTime then
		nextTime = startTime + 24*3600 - now
		warnTime = startTime + 24*3600 + robberfbconfig.interval - robberfbconfig.warnTime - now 
		robberwave = 0
	else 
		nextTime = robberfbconfig.interval
		warnTime = robberfbconfig.interval - robberfbconfig.warnTime
		robberwave = robberwave + 1
	end

	--开服x天前，活动不开启
	local openDay = System.getOpenServerDay() + 1
	--if openDay < robberfbconfig.openDay then
	if openDay < guildactivity.getOpenDay(robberfbconfig.activityId) then
		robberwave = 0
	end

	setRobberWave(robberwave)
	print("robberwave:"..robberwave.." nextTime:"..nextTime)
	
	-- --下一次刷新
	-- LActor.postScriptEventLite(nil, nextTime*1000, function ( ... )
	-- 		RefreshGuildRobber(...)
	-- 	end )
	-- --下一次警告
	-- LActor.postScriptEventLite(nil, warnTime*1000, function ( ... )
	-- 	GuildRobberWarn(...)
	-- 	end )

	--刷新行会波数（开服x天前活动不开启）
	--if openDay < robberfbconfig.openDay then return end
	if openDay < guildactivity.getOpenDay(robberfbconfig.activityId) then return end
	local guildList = LGuild.getGuildList()
	if guildList == nil then return end
	print("RefreshRobber")
	for i=1,#guildList do
		local guild = guildList[i]
		if guild then RefreshRobber(guild, robberwave) end
	end
end
_G.rsfGuildRobber = function()
	robberfb.RefreshGuildRobber()
end

_G.rsfGuildRobberWarn = function()
	robberfb.GuildRobberWarn()
end


function InitGuildRobberTime()
	print("+++++++++++++InitGuildRobberTime+++++++++++++")
	local now = System.getNowTime()
	--local startTime, endTime = getRobberStartandEnd()
	local startTime, endTime = guildactivity.getStartandEnd(robberfbconfig.activityId)
	if not startTime or not endTime then
		print("robber guildactivity config is nil")
		return 
	end
	
	local nextTime
	if now <= startTime then     --今天活动未开启
		nextTime = startTime - now
	elseif now > endTime then    --今天活动已结束
		nextTime  = startTime + 24*3600 - now
	else                         --今天活动开启中
		local wave = 0
		while startTime <= endTime do
			startTime = startTime + robberfbconfig.interval
			if startTime >= now then
				nextTime = startTime - now
				local var = System.getDyanmicVar()
				var.robberwave = wave
				break
			end
			wave = wave + 1 
		end
		local var = System.getDyanmicVar()
		var.robberwave = wave
	end

	-- print("GuildRobberTime nextTime:"..nextTime)
	-- LActor.postScriptEventLite(nil, nextTime*1000, function ( ... )
	-- 		RefreshGuildRobber(...)
	-- 	end )
end

for _, id in ipairs(robberfbconfig.fbId) do
	insevent.registerInstanceWin(id, onRobberfbWin)
	insevent.registerInstanceLose(id, onRobberfbLose)
	insevent.registerInstanceExit(id, onRobberLeave)
end


engineevent.regGameStartEvent(InitGuildRobberTime)


--------------------gm命令--------------------
local gmsystem      = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.robber = function (actor, args)
	onChallenge(actor, tonumber(args[1] or 1))
end

gmCmdHandlers.clearRobber = function (actor, args)
	local info = getActorRobberVar(actor)
	info.times = 0
	SendRobberTimes(actor, info.times)
end
