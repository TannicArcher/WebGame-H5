--副本定时器
module("base.scripttimer.fubenscripttimer", package.seeall)
setfenv(1, base.scripttimer.fubenscripttimer)

local fubenevent = require("actorevent.fubenevent")

_G.fubenScripttimerData = _G.fubenScripttimerData or {}
local fubenScripttimerData = _G.fubenScripttimerData
fubenScripttimerData.eventList = fubenScripttimerData.eventList or {}
local eventList = fubenScripttimerData.eventList

if not fubenScripttimerData.fid then fubenScripttimerData.fid = 0 end
local INT_MAX_NUM = INT_MAX_NUM

function getFid()
	fubenScripttimerData.fid = fubenScripttimerData.fid + 1
	return fubenScripttimerData.fid
end

function getVarList(scene)
	local idx = Fuben.getSceneHandleByPtr(scene)

	eventList[idx] = eventList[idx] or {}
	return eventList[idx]
end

function cleanSceneList(scene)
	if not scene then return end
	local idx = Fuben.getSceneHandleByPtr(scene)

	eventList[idx] = nil
	return true
end

function onTimeEvent(scene, fid)
	if not scene then return end

	local sceneList = getVarList(scene)
	if not sceneList then return end

	local event = sceneList[fid]
	if not event then return end

	if event.times <= 0 then
		sceneList[fid] = nil
		return
	end

	if event.func then
		event.func(scene, unpack(event.arg))
	end
	--WARN:这里需要再次判空的原因是如果在func中删除了定时器自身，则event会为nil
	if event then
		event.times = event.times - 1
		--不需再调用后移除
		if event.times <= 0 then
			sceneList[fid] = nil
		end
	end
end

_G.MY_Fuben_ScriptOnTimeEvent = onTimeEvent

--封装一个用于PostScriptEvent的方法
--该方法接受可以接受func, table等作为参数
--需要定时的方法不再需要进行_G全局化
function postScriptEvent(scene, delay, func, interval, times, ...)
	if not scene then return end

	if type(func) ~= "function" then
		func = _G[func]
		if not func then return end
	end

	local event = {}
	event.func = func
	event.arg = arg
	event.times = times == -1 and INT_MAX_NUM or times

	--次数不足直接不处理
	if event.times < 1 then return end

	local sceneList = getVarList(scene)
	if not sceneList then return end

	local fid = getFid()
	event.fid = Fuben.postScriptEventCore(scene, delay, "MY_Fuben_ScriptOnTimeEvent", interval, event.times, fid)
	sceneList[fid] = event
	return fid
end

function postOnceScriptEvent(scene, delay, func, ...)
	return postScriptEvent(scene, delay, func, 0, 1, ...)
end

function cancelScriptTimer(scene, eid)
	if not scene or not eid then return end

	local sceneList = getVarList(scene)
	if not sceneList then return end

	local event = sceneList[eid]
	if not event then return end

	if event.fid then
		Fuben.cancelScriptTimer(scene, event.fid)
		sceneList[eid] = nil
	end
end

Fuben.postScriptEvent = postScriptEvent

_G.OnSceneReset = cleanSceneList

