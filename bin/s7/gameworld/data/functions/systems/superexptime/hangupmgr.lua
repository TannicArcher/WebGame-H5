--[[
	author = 'Roson'
	time   = 03.18.2015
	name   = 挂机管理
	mod    = 管理所在的场景
	ver    = 0.1
]]

module("systems.superexptime.hangupmgr" , package.seeall)
setfenv(1, systems.superexptime.hangupmgr)

local sbase         = require("systems.superexptime.sbase")
local fubenevent    = require("actorevent.fubenevent")
local teamsystem    = require("systems.team.teamsystem")
local fubensystem   = require("systems.fubensystem.fubensystem")
local fubenevent    = require("actorevent.fubenevent")
local actorexp      = require("systems.actorsystem.actorexp")
local lianfumanager = require("systems.lianfu.lianfumanager")
local lianfuutils   = require("systems.lianfu.lianfuutils")
local easyjoin      = require("systems.corssjoinactivity.easyjoin")

local SuperExpTimeConf = sbase.SuperExpTimeConf
local playerPos        = SuperExpTimeConf.playerPos
local MAX_PLAYER_COUNT = SuperExpTimeConf.maxPlayerCount
local FUBEN_ID         = SuperExpTimeConf.fubenId
local playerLevelRange = SuperExpTimeConf.playerLevelRange

local FUBEN_DURATION = 3600 * 24 * 30 -- 一个月(大于维护周期)

local HANG_UP_ID = easyjoin.ACT_TYPE.HANG_UP_ID

local BEG_INDX, END_INDX, SCENE_INDX = 1, 2, 3
local X, Y = 1, 2

local CampBattleLang = Lang.CampBattleLang
local ScriptTips = Lang.ScriptTips

function getSysDyanmicVar( ... )
	local var = sbase.getSysDyanmicVar()
	if not var then return end

	var.hangup = var.hangup or {}
	local hangup = var.hangup
	hangup.full = hangup.full or {}
	hangup.wait = hangup.wait or {}

	return hangup
end

function getDyanmicVar(actor)
	local var = sbase.getDyanmicVar(actor)
	if not var then return end

	var.hangup = var.hangup or {}
	return var.hangup
end

function createFuBenToList(sceneId)
	print(string.format("[TIMESMGR][IN][SCENEID][%s]-->createFuBenToList", sceneId))
	local var = getSysDyanmicVar()
	if not var or not var.wait then return end

	local data = {}
	data.num = 0
	data.pos = {}	--初始化标记
	data.sceneId = sceneId

	local hFuben = Fuben.createFuBen(FUBEN_ID)

	--这里要设置一下副本时间
	local timeNow = System.getNowTime()
	Fuben.SetFubenTime(hFuben, FUBEN_DURATION)
	Fuben.setReserveTime(hFuben, timeNow + FUBEN_DURATION)
	Fuben.SetFubenGameTime(hFuben, FUBEN_DURATION)

	var.wait[hFuben] = data
	print(string.format("[TIMESMGR][OUT][SCENEID][%s]-->createFuBenToList", sceneId))
	return hFuben, sceneId, data
end

function getCanInitFubenScene(lv)
	for _,data in ipairs(playerLevelRange) do
		if data[BEG_INDX] <= lv and data[END_INDX] >= lv then
			return data[SCENE_INDX]
		end
	end

	return 0
end

function getActorIds(actorList)
	local actorIds = {}
	if not actorList then return actorIds end

	local insert = table.insert
	for _,player in ipairs(actorList) do
		insert(actorIds, LActor.getActorId(player))
	end

	return actorIds
end

function searchFreeFubenHandle(level)
	local var = getSysDyanmicVar()
	if not var or not var.wait then return end
	local delHandleTab = {}
	local getFubenPtr = Fuben.getFubenPtr
	local insert = table.insert

	local retHFuben, fubenData = 0

	local tarScene = getCanInitFubenScene(level)
	print(string.format("[TIMESMGR][KEY_DATA][LEVEL][%s][%s]-->searchFreeFubenHandle", level, tarScene))

	local contains = table.contains

	for hFuben,v in pairs(var.wait) do
		local pFuben = getFubenPtr(hFuben)
		if not pFuben then
			insert(delHandleTab, hFuben)
		else
			local actorList = LuaHelp.getFbActorList(pFuben)
			if not actorList then
				v.num = 0
				v.pos = {}
			else
				v.num = #actorList

				--校验pos的位置标识
				local actorIds = getActorIds(actorList)
				local pos = v.pos
				for i=1, MAX_PLAYER_COUNT do
					local posActorId = pos[i]
					if posActorId and not contains(actorIds, posActorId) then
						pos[i] = nil
					end
				end
			end

			if v.num < MAX_PLAYER_COUNT and v.sceneId == tarScene then
				retHFuben = hFuben
				fubenData = v
				if v.num == 0 then
					fubenData.pos = {}
				end
				break
			end
		end
	end

	--清理失效的数据
	for _,hFuben in pairs(delHandleTab) do
		var[hFuben] = nil
	end
	print(string.format("[TIMESMGR][KEY_DATA][H_FUBEN][%s]-->searchFreeFubenHandle", retHFuben))

	if retHFuben > 0 then return retHFuben, tarScene, fubenData end

	return createFuBenToList(tarScene)
end

function checkEnterFuben(actor)
	if type(actor) == "table" then
		actor = actor[1]
	end

	if not actor then return end

	local actorId = LActor.getActorId(actor)
	print(string.format("[TIMESMGR][IN][%s]-->checkEnterFuben", actorId))

	if FUBEN_ID == LActor.getFubenId(actor) then
		return
	end

	if LActor.isInFuben(actor) then
    	LActor.sendTipmsg(actor, ScriptTips.sx019, ttMessage)
    	return
	end

    -- 检查护送任务状态
	if LActor.hasState(actor, esProtection) then
    	LActor.sendTipmsg(actor, ScriptTips.sx027, ttMessage)
    	return
  	end

	-- 战斗中无法进入
	if LActor.hasState(actor, esPkState) then
		LActor.sendTipmsg(actor, CampBattleLang.err003, ttMessage)
		return
	end
	-- return timesmgr.setSurplusTimeBegin(actor)
	print(string.format("[TIMESMGR][OUT][%s]-->checkEnterFuben", actorId))
	return true
end

function getCommFubenInfo(actorId, fbId, level)
	local hFuben, sceneId, fubenData = searchFreeFubenHandle(level)
	print(string.format("[TIMESMGR][CHECK][%s][%s]-->getCommFubenInfo.searchFreeFubenHandle", hFuben or 0, sceneId or 0))
	if hFuben == 0 or sceneId == 0 or not sceneId or not fubenData then return end
	print(string.format("[TIMESMGR][FLAG][%s]-->checkEnterFuben", 1))
	local var = getDyanmicVar(actorId)
	if not var then return end
	print(string.format("[TIMESMGR][FLAG][%s]-->checkEnterFuben", 2))

	local svar = getSysDyanmicVar()
	if not svar or not svar.wait or not svar.full then return end
	print(string.format("[TIMESMGR][FLAG][%s]-->checkEnterFuben", 3))

	local pFuben = Fuben.getFubenPtr(hFuben)
	if not pFuben then return end
	print(string.format("[TIMESMGR][FLAG][%s]-->checkEnterFuben", 4))

	local pos = fubenData.pos

	local posConf
	for i=1,MAX_PLAYER_COUNT do
		if not pos[i] then
			posConf = playerPos[i]
			if posConf then
				fubenData.num = fubenData.num + 1
				pos[i] = actorId

				var.posIndx = i
				var.hFuben = hFuben

				--如果副本已满移动到满人队列内
				if fubenData.num >= MAX_PLAYER_COUNT then
					svar.full[hFuben] = fubenData
					svar.wait[hFuben] = nil
				end

				break
			end
		end
	end

	print(string.format("[TIMESMGR][FLAG][%s]-->checkEnterFuben", 5))

	if not posConf then return end

	print(string.format("[TIMESMGR][FLAG][%s]-->checkEnterFuben", 6))

	return hFuben, sceneId, posConf[X], posConf[Y]

	-- var.isBefHangup = true
	-- LActor.enterFuBen(actor, hFuben, sceneId, posConf[X], posConf[Y])
end

function getCommParamInfo(actor)
	local level = LActor.getLevel(actor)
	return {dtChar, level}
end

function recieveEnterFuben(actor, fbId, srvId, fbHandle, sceneId, x, y)
	if fbHandle <= 0 then return end
	--离开队伍
	LActor.exitTeam(actor)

	if srvId == System.getServerId() then
		LActor.enterFuBen(actor, fbHandle, sceneId, x, y)
	else
		LActor.loginOtherSrv(actor, srvId, fbHandle, sceneId, x, y, "fubensystem.defEnterFubenCallBack")
	end
end

function enterFuben(actor)
	local actorId = LActor.getActorId(actor)
	local level = LActor.getRealLevel(actor)

	local hFuben, sceneId, x, y = getCommFubenInfo(actorId, FUBEN_ID, level)
	if not hFuben then return end

	--离开队伍
	LActor.exitTeam(actor)

	local var = getDyanmicVar(actor)
	if not var then return end

	var.isBefHangup = true
	LActor.enterFuBen(actor, hFuben, sceneId, x, y)
end

function exitFuben(actor, hFuben, way, notClear)
	--离开队伍
	LActor.exitTeam(actor)
	print(string.format("[TIMESMGR][KEY_DATA][H_FUBEN][%s]-->exitFuben", hFuben  or 0))
	local var = getDyanmicVar(actor)
	if not var then return end

	local svar = getSysDyanmicVar()
	if not svar or not svar.wait or not svar.full then return end

	print(string.format("[TIMESMGR][KEY_DATA][VAR_H_FUBEN][%s]-->exitFuben", var.hFuben or "nil"))
	print(string.format("[TIMESMGR][KEY_DATA][VAR_POSINDX][%s]-->exitFuben", var.posIndx or "nil"))

	if not var.hFuben or var.hFuben == 0 then return end
	local hFuben = var.hFuben
	local posIndx = var.posIndx

	var.hFuben = nil
	var.posIndx = nil

	--移动到未满员的队列内，如果之前是满的话
	if svar.full[hFuben] then
		svar.wait[hFuben] = svar.full[hFuben]
		svar.full[hFuben] = nil
		print(string.format("[TIMESMGR][FLAG][%s]-->exitFuben", 1))

	end

	--清理玩家痕迹
	local fubenData = svar.wait[hFuben]
	if fubenData then
		fubenData.num = math.max(fubenData.num - 1, 0)
		fubenData.pos[posIndx] = nil
		print(string.format("[TIMESMGR][FLAG][%s]-->exitFuben", 2))
	end

	if notClear ~= true then
		var.isBefHangup = nil
	end

	--清理PK状态
	LActor.removeState(actor, esPkState)
end

function checkBefHangupState(actor)
	if LActor.getFubenId(actor) ~= 0 then return end
	gotoHangup(actor)
end

function gotoHangup(actor)
	local var = getDyanmicVar(actor)
	if not var then return end

	if var.isBefHangup then
		var.isBefHangup = nil
		enterFuben(actor)
	end
end

function jmpOutHangupFuben(actor, isClear)
	if FUBEN_ID ~= LActor.getFubenId(actor) then return end

	--标记不跳转
	if easyjoin.hasJumpFlag(actor) then
		easyjoin.setNullJumpFlagOnce(actor)		--不产生一次跳转
		easyjoin.noReflushJumpConfOnce(actor)	--不产生一次记录
	end

	LActor.exitFuben(actor)
	if isClear then return end

	local var = getDyanmicVar(actor)
	if not var then return end

	var.isBefHangup = true
	return true
end

function getDyanHangUp(actor)
	local var = getDyanmicVar(actor)
	if not var then return end

	if FUBEN_ID == LActor.getFubenId(actor) then
		var.isBefHangup = nil
		return true
	end

	return
end

function setDyanHangUp(actor)
	if FUBEN_ID ~= LActor.getFubenId(actor) then
		return end

	local var = getDyanmicVar(actor)
	if not var then return end

	var.isBefHangup = true
	return true
end

fubensystem.regCheck(FUBEN_ID, checkEnterFuben)
fubensystem.regEnter(FUBEN_ID, enterFuben)

easyjoin.reg(FUBEN_ID, HANG_UP_ID)

fubenevent.registerFubenExit(FUBEN_ID, exitFuben)

--去掉进入的判定
-- fubenevent.registerAllSceneEnter(checkBefHangupState)

_G.GotoHangupFubenFunc = enterFuben
_G.HangupFubenExitFunc = exitFuben
_G.JmpOutHangupFuben = jmpOutHangupFuben
