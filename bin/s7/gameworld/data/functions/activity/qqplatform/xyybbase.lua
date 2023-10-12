module("activity.qqplatform.xyybbase" , package.seeall)
setfenv(1, activity.qqplatform.xyybbase)

local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local mailsystem = require("systems.mail.mailsystem")
local postscripttimer = require("base.scripttimer.postscripttimer")
local abase = require("systems.awards.abase")
local monevent  = require("monevent.monevent")
local operations = require("systems.activity.operations")
local actorevent = require("actorevent.actorevent")
local gmsystem    = require("systems.gm.gmsystem")


require("activity.operationsconf")
require("protocol")

local postOnce = postscripttimer.postOnceScriptEvent
local DAY_LENGTH = 24 * 3600
local subActId = SubActConf.XY_YUEBING

local ActivityConfig = operations.getSubActivitys(subActId)

function getSysVard(actId)
	if not actId then return end

	local var = System.getDyanmicVar()
	if not var then return end

	if not var.yyyb then
		var.yyyb = {}
	end

	if not var.yyyb[actId] then
		var.yyyb[actId] = {}
	end
	return var.yyyb[actId]
end

function getXyybVar(actor, actId)
	if not actor or not actId then return end

	local var = LActor.getSysVar(actor)
	if not var then return end

	if not var.yyyb then
		var.yyyb = {}
	end

	if not var.yyyb[actId] then
		var.yyyb[actId] = {}
	end
	return var.yyyb[actId]
end

function getMonsterVar(handle)
	local var = System.getDyanmicVar()
	if not var then return end

	if not var.xyMonHandle then
		var.xyMonHandle = {}
	end

	if not handle then
		var.xyMonHandle[handle] = nil
		return
	end

	if not var.xyMonHandle[handle] then
		var.xyMonHandle[handle] = {}
	end
	return var.xyMonHandle[handle]
end

function clearMonsterVar(handle)
	if not handle then return end

	local var = System.getDyanmicVar()
	if not var or not var.xyMonHandle then return end

	var.xyMonHandle[handle] = nil
end

function getStepTime(time, now)
	if not time or not now then return end

	local delay = time - now
	if delay < 0 then
		delay = delay + DAY_LENGTH
	end
	return delay
end

function marchInit(actId, begintime, endtime)
	local config = ActivityConfig[actId].config
	if not config then return end

	local sysvard = getSysVard(actId)
	if not sysvard or sysvard.timefresh then return end

	print("march init actId:" .. actId)

	if sysvard.timer and #sysvard.timer > 0 then
		marchClose(actId)
	end

	sysvard.timer = {}

	local now, delay = System.getNowTime() % DAY_LENGTH
	for idx, time in ipairs(config.time) do
		delay = getStepTime(time, now)
		local eid = postOnce(nil, delay * 1000, function(...) checkNewStage(...) end, actId, idx)
		table.insert(sysvard.timer, eid)
	end

	sysvard.timefresh = true
end

function marchClose(actId)
	print("march close actId:" .. actId)
	local sysvard = getSysVard(actId)
	if not sysvard or not sysvard.timer then return end
	if #sysvard.timer > 0 then
		for _, eid in ipairs(sysvard.timer) do
			postscripttimer.cancelScriptTimer(nil, eid)
		end
	end

	sysvard.timer = nil
	sysvard.timefresh = nil
end

function resetMarchInfo(var)
	if not var then return end

	var.step = nil
	var.flags = nil			--每个怪物执行表示
	var.monsters = {}
	var.leader = nil
	var.moving = nil
end

function checkNewStage(target, actId, stage)
	if not actId then return end

	local config = ActivityConfig[actId].config
	if not config then return end

	local hScene = Fuben.getSceneHandleById(config.showSceneId, 0)
	if hScene == 0 then return end

	--检测是否有这个怪
	if Fuben.getMyMonsterCount(hScene, config.monId) > 0 then return end

	local sysvar = getSysVard(actId)
	if not sysvar then return end

	if not sysvar.timer then sysvar.timer = {} end

	if stage then
		local closetime = operations.isInTime(actId)
		if not closetime then return end

		local now = System.getNowTime()
		if closetime > now + DAY_LENGTH then
			local eid = postOnce(nil, DAY_LENGTH * 1000, function(...) checkNewStage(...) end, actId, stage)
			table.insert(sysvar.timer, eid)
		end
	end

	--初始化玩家信息新
	resetMarchInfo(sysvar)

	local px, py, handle, x, y, point

	for idx, info in ipairs(config.createPoint) do

		px, py = (info.x + 0.5) * 64, (info.y + 0.5) * 64
		local monster = Fuben.createMonsterPix(hScene, config.monId, 
			info.x, info.y, px, py, 0, info.x - 1, info.y - 1)

		handle = LActor.getHandle(monster)

		local monvar = getMonsterVar(handle)
		if monvar then
			monvar.index = idx
			monvar.activityId = actId
		end

		if not sysvar.leader then
			sysvar.step = 1
			sysvar.leader = handle 
		end
		table.insert(sysvar.monsters, handle)
	end

	System.broadcastTipmsg(config.createTips, ttChatWindow)
end

function OnMarchTime(monster, time)
	if not monster then return end

	local handle = LActor.getHandle(monster)
	local monvar = getMonsterVar(handle)
	if not monvar or not monvar.activityId or not monvar.index then return end

	local actId = monvar.activityId
	local config = ActivityConfig[actId].config
	if not config then return end

	local sysvar = getSysVard(actId)
	if not sysvar or not sysvar.step then return end
	if not sysvar.leader or sysvar.flags then return end
	if sysvar.leader ~= handle then return end

	local point = config.movePoint[sysvar.step]
	if not point then return end

	sysvar.step = (sysvar.step or 1) + 1

	local hScene = LActor.getSceneHandle(monster)
	if hScene == 0 then return end

	if point.area then
		local r, k = config.radius, 0
		for i = point.area[1] - r, point.area[1] + r do
			for j = point.area[2] - r, point.area[2] + r do
				if Fuben.canMove(hScene, i, j) then
					Fuben.createMonster(hScene, config.boxId, i, j, config.boxLive)
					k = k + 1
					if k == config.boxNumPerTime then break end
				end
			end
			if k == config.boxNumPerTime then break end
		end
	end

	if point.time > 0 then
		sysvar.flags = true
		stopMove(actId)
		postOnce(nil, point.time * 1000, function(...) startMove(...) end, actId, hScene)
		return
	end

	startMove(nil, actId, hScene, true)
end

function stopMove(actId)
	local sysvar = getSysVard(actId)
	if not sysvar or not sysvar.monsters then return end

	for _, handle in ipairs(sysvar.monsters) do
		local monster = LActor.getEntity(handle)
		if monster then
			LActor.stopMonsterMarch(monster)
		end
	end
end

function startMove(target, actId, hScene, checkFlag)
	local sysvar = getSysVard(actId)
	if not sysvar or not sysvar.monsters then return end

	local config = ActivityConfig[actId].config
	if not config then return end

	local ret

	for _, handle in ipairs(sysvar.monsters) do
		ret = resetMonsterMove(handle, actId, hScene)
	end

	if not sysvar.moving then
		sysvar.moving = true
		System.broadcastTipmsg(config.moveTips, ttChatWindow)
	end

	if ret then
		Fuben.clearAllMonster(hScene, config.monId)
		System.broadcastTipmsg(config.endTips, ttChatWindow)
	end

	if not checkFlag then
		local sysvar = getSysVard(actId)
		if sysvar then sysvar.flags = nil end
	end
end

function resetMonsterMove(handle, actId, hScene)
	if not handle or not hScene then return end

	local monster = LActor.getEntity(handle)
	if not monster then return end

	local monvar = getMonsterVar(handle)
	if not monvar or not monvar.index then return end

	local config = ActivityConfig[actId].config
	if not config then return end

	local sysvar = getSysVard(actId)
	if not sysvar or not sysvar.step then return end

	local step = sysvar.step

	if step > #config.movePoint then
		clearMonsterVar(handle)
		return true
	end

	local point = config.movePoint[step]
	if not point.pos then return end
	local gx = point.pos[monvar.index][1]
	local gy = point.pos[monvar.index][2]
	local x = (gx + 0.5) * 64
	local y = (gy + 0.5) * 64
	--print("indirect move new pos:", gx, gy)
	LActor.setMonsterMarchPoint(monster, x, y)
end

function gatherCheck(monster, killer, monId)
	if not monster or not killer then return false end

	local actId
	for _, info in pairs(ActivityConfig) do
		if monId == info.config.boxId then
			actId = _
			break
		end
	end

	if not actId then return false end

	local avar = getXyybVar(killer, actId)
	if not avar then return false end

	local config = ActivityConfig[actId].config
	if not config then return false end

	if not avar.gatherTimes or avar.gatherTimes < config.dayGatherTime then
		return true
	end
	LActor.sendTipmsg(killer, config.gatherTips)
	return false
end

function gatherFinish(monster, killer, monId)
	if not monster or not killer then return end

	local actId
	for _, info in pairs(ActivityConfig) do
		if monId == info.config.boxId then
			actId = _
			break
		end
	end
	if not actId then return end

	local avar = getXyybVar(killer, actId)
	if not avar then return end
	avar.gatherTimes = (avar.gatherTimes or 0) + 1
end

function initOperations()
	for actId, info in pairs(ActivityConfig) do
		operations.regStartEvent(actId, marchInit)
		operations.regCloseEvent(actId, marchClose)
		
		local boxId = info.config.boxId
		monevent.regGatherCheck(boxId, gatherCheck)
		monevent.regGatherFinish(boxId, gatherFinish)
	end
end

function checkXyyb()
	postOnce(nil, 500, function(...) delayActivityCheck(...) end)
end

function delayActivityCheck()
	for actId, info in pairs(ActivityConfig) do
		if operations.isInTime(actId) then
			marchInit(actId)
		end
	end
end

function resetActorInfo(actor, actId)
	if not actId then return end

	local var = getXyybVar(actor, actId)
	if not var then return end
	var.gatherTimes = 0
end

function onNewDay(actor)
	for actId, info in pairs(ActivityConfig) do
		resetActorInfo(actor, actId)
	end
end

function closeMarch(actId)
	if not System.isCommSrv() then return end

	local config = ActivityConfig[actId].config
	if not config then return end

	local hScene = Fuben.getSceneHandleById(config.showSceneId, 0)
	if hScene == 0 then return end

	Fuben.clearAllMonster(hScene, config.monId)

	Fuben.clearAllGather(hScene, config.boxId)
end

actorevent.reg(aeNewDayArrive, onNewDay)

table.insert(InitFnTable, initOperations)

engineevent.regGameStartEvent(checkXyyb)

_G.OnMarchTime = OnMarchTime

---命令
local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.marchOpen = function(actor, args)
	if System.isCommSrv() then
		checkNewStage(nil, 7)
	end
end

gmCmdHandlers.marchClose = function(actor, args)
	closeMarch(7)
end
