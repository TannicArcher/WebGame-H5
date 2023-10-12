--跨服竞技场
module("crossarenacommon", package.seeall)


--[[
	actor {
		worldCd  世界邀请 cd
		dayEnter 今天进入副本次数
		monEnter 本月进入副本次数
		historyEnter 历史进入副本次数
		multiWin 连胜
		historyWin  历史战绩 [胜负] = 次数
		monWin  本月战绩 [胜负] = 次数
		score 分数
		lastMetal 昨天的段位
		lastMetalAward   昨日的段位奖励是否已经领取
		metal 段位
		peakCount 巅峰令
	}
--]]

FightResult = {
	win = 1,	--胜利
	dogfall = 2, --平局
	lose = 3, 	--失败
}

function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var then return end

	if not var.crossArena then
		var.crossArena = {}
	end

	if not var.crossArena.base then
		var.crossArena.base = {}
	end

	return var.crossArena.base
end

local function getSysVar()
	local sysVar = System.getStaticVar()
	if not sysVar then return end

	if not sysVar.crossArena then
		sysVar.crossArena = {}
	end

	if not sysVar.crossArena.base then
		sysVar.crossArena.base = {}
	end

	return sysVar.crossArena.base
end

--获取玩家积分
function getScore(actor)
	local var = getActorVar(actor)
	if not var then return 0 end

	return var.score or 0
end

function getMultiWin(actor)
	local var = getActorVar(actor)
	if not var then return 0 end

	return var.multiWin or 0
end

--获取玩家段位
function getMetal(actor)
	local var = getActorVar(actor)
	if not var then return 0 end

	return var.metal or 1
end
--剩余挑战次数
function getFightCount(actor)
	local var = getActorVar(actor)
	if not var then return 0 end

	return CrossArenaBase.joinCount - (var.dayEnter or 0)
end

--胜率
function getWinRate(actor)
	local var = getActorVar(actor)
	if not var.monWin then return 0 end

	local totalCount = 0
	for i = FightResult.win, FightResult.lose do
		totalCount = var.monWin[i]
	end

	return math.floor(var.monWin[FightResult.win] / totalCount * 10000)
end

--本月战绩
function getNowWin(actor)
	local var = getActorVar(actor)
	if not var or not var.monWin then return 0, 0, 0 end

	return var.monWin[FightResult.win], var.monWin[FightResult.dogfall], var.monWin[FightResult.lose]
end

--历史战绩
function getHistoryWin(actor)
	local var = getActorVar(actor)
	if not var or not var.historyWin then return 0, 0, 0 end

	return var.historyWin[FightResult.win], var.historyWin[FightResult.dogfall], var.historyWin[FightResult.lose]
end

local function actor_log(actor, str)
	if not actor or not str then return end

	print("error crossarenacommon, actorId:"..LActor.getActorId(actor).."log:"..str)
end

local function getSysDymVar()
	local dymVar = System.getDyanmicVar()
	if not dymVar then return end

	if not dymVar.crossArena then
		dymVar.crossArena = {}
	end

	return dymVar.crossArena
end

local function setOpen(param)
	local dymVar = getSysDymVar()
	if not dymVar then return end

	dymVar.isOpen = param 	--是否已经开启 1开启
end

function isOpen()
	local dymVar = getSysDymVar()
	if not dymVar then return end

	return dymVar.isOpen
end

--开启前 预告
function noticeOpen(actor, leftTime)
	if not leftTime then
		local sysVar = getSysDymVar()
		if not sysVar or not sysVar.endTime then return end

		leftTime = sysVar.endTime - System.getNowTime()
	end

	local pack
	if actor then
		pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_NoticeOpen)
	else
		pack = LDataPack.allocPacket()
		LDataPack.writeByte(pack, Protocol.CMD_Cross3Vs3)
		LDataPack.writeByte(pack, Protocol.sCross3Vs3_NoticeOpen)
	end

	if not pack then return end

	LDataPack.writeInt(pack, isOpen() and 1 or 0)
	LDataPack.writeInt(pack, leftTime)

	if actor then
		LDataPack.flush(pack)
	else
		System.broadcastData(pack)
	end
end

--开启预告
_G.NoticeOpenCrossArena = function(now, openLeftTime)
	local sysVar = getSysDymVar()
	if not sysVar then
		print("crossarenacommon NoticeOpenCrossArena getSysDymVar is nil")
		return
	end

	setOpen()
	sysVar.endTime = now + openLeftTime
	noticeOpen(nil, openLeftTime)

	LActor.postScriptEventEx(nil, 0, function ()
		local sysVar = getSysDymVar()
		if not sysVar or not sysVar.endTime then
			print("crossarenacommon NoticeOpenCrossArena getSysDymVar postScriptEventEx is nil")
			return
		end
		local leftTime = sysVar.endTime - System.getNowTime()
		local minute = math.floor(leftTime / 60)
		if minute < 1 then return end

		broadCastNotice(CrossArenaBase.advanceNoticeId, minute)
	end, 60000, math.floor(openLeftTime / 60))
end

--开启
_G.OpenCrossArenaFb = function(now, leftTime)
	print("crossArena open")

	local sysVar = getSysDymVar()
	if not sysVar.endTime then
		print("crossarenacommon OpenCrossArenaFb not has endTime NoticeOpenCrossArena")
	end

	sysVar.endTime = System.getNowTime() + leftTime
	setOpen(1)
	noticeOpen(nil, leftTime)

	broadCastNotice(CrossArenaBase.openNoticeId)

	LActor.postScriptEventLite(nil, leftTime * 1000, function ()
		local sysVar = getSysDymVar()
		if not sysVar.endTime then
			print("crossarenacommon OpenCrossArenaFb not has endTime NoticeOpenCrossArena")
		end

		print("crossArena close")
		setOpen()
		sysVar.endTime = nil
		noticeOpen(nil, 0)
	end)
end

local function onLogin(actor)
	noticeOpen(actor)

	local sysVar = getSysVar()
	local var = getActorVar(actor)
	if not sysVar or not var then return end

	local actorId = LActor.getActorId(actor)
	if not sysVar[actorId] then return end

	local data = sysVar[actorId]
	var.dayEnter = (var.dayEnter or 0) + 1
	var.monEnter = (var.monEnter or 0) + 1
	var.historyEnter = (var.historyEnter or 0) + 1

	if not var.historyWin then
		var.historyWin = {}
	end
	if not var.monWin then
		var.monWin = {}
	end

	if data.win < FightResult.win or data.win > data.lose then
		actor_log(actor, "onLogin, the idx is error "..data.win)
		return
	end

	var.historyWin[data.win] = (var.historyWin[data.win] or 0) + 1
	var.monWin[data.win] = (var.monWin[data.win] or 0) + 1

	if data.win == 1 then
		var.multiWin = (var.multiWin or 0) + 1
	else
		var.multiWin = 0
	end

	var.score = (var.score or 0) + data.score
	var.peakCount = (var.peakCount or 0) + data.peakCount

	sysVar[actorId] = nil

	for k, v in ipairs(CrossArenaBase.scoreMetal) do
		if var.score >= v then
			var.metal = k 	--段位
		else
			break
		end
	end
end

local function onNewDay(actor)
	local var = getActorVar(actor)
	if not var then return end

	var.dayEnter = 0
	var.lastMetal = var.metal or 1
	var.lastMetalAward = nil

	--看下是否有发这个月的段位奖励
	local year, mon, _ = System.getDate()
	if var.year == year and var.mon == mon then
		return
	end

	--不同月
	var.year = year
	var.mon = mon

	--段位奖励
	if var.metal then
		local awardConf
		for _, v in pairs(CrossArenaBase.finalAward) do
			if v.metal == var.metal then
				awardConf = v
			end
		end
		if awardConf and awardConf.mail then
			mailsystem.sendMailById(LActor.getActorId(actorId), awardConf.mail)
		end
	end

	--积分等数据 重置
	var.score = 1000
	var.metal = 1
	var.winCount = 0
	var.multiWin = 0
	var.enterCount = 0
	var.peakCount = 0
	var.peakAward = 0
end






actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeUserLogin, onLogin)


local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.corssA = function(actor, args)
	local tmp = tonumber(args[1])
	if tmp == 1 then
		local var = getActorVar(actor)
		if not var then return end

		var.score = tonumber(args[2])
		var.peakCount = tonumber(args[3])
		-- var.metal = tonumber(args[3])
		-- var.score = tonumber(args[4])
		-- var.score = tonumber(args[5])
		-- var.score = tonumber(args[6])

		for k, v in ipairs(CrossArenaBase.scoreMetal) do
			if var.score >= v then
				var.metal = k 	--段位
			else
				break
			end
		end
	elseif tmp == 2 then
		local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_NoticeOpen)
		if not pack then return end

		LDataPack.writeInt(pack, 1)
		LDataPack.writeInt(pack, 250)

		LDataPack.flush(pack)
	end
end

