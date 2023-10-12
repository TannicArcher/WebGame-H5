--重新包装C++定时器
--提供一个可以传递任何参数的postscripttimer
module("base.scripttimer.postscripttimer", package.seeall)
setfenv(1, base.scripttimer.postscripttimer)

_G.postscripttimerData = _G.postscripttimerData or {}
local postscripttimerData = _G.postscripttimerData
postscripttimerData.eventList = postscripttimerData.eventList or {}
local eventList = postscripttimerData.eventList

if not postscripttimerData.eid then postscripttimerData.eid = 0 end
local INT_MAX_NUM = INT_MAX_NUM

function getEid()
	postscripttimerData.eid = postscripttimerData.eid + 1
	return postscripttimerData.eid
end

function getVarList(entity)
	local idx = LActor.getHandle(entity)

	eventList[idx] = eventList[idx] or {}
	return eventList[idx]
end

function cleanActorList(actor)
	if not actor then
		actor = System.getGlobalNpc()
	end
	local idx = LActor.getHandle(actor)
	
    print("clear ActorList idx:"..idx)
    if eventList[idx] then
        for eid,_ in pairs(eventList[idx]) do
            cancelScriptTimer(actor, eid)
        end
    end
	eventList[idx] = nil
end

function onTimeEvent(actor, eid)
	if not actor then
		actor = System.getGlobalNpc()
	end
	-- if actor == System.getGlobalNpc() then
	-- 	print(string.format("ontimer:%d", eid))
	-- end

	local actList = getVarList(actor)
	if not actList then return end

	local event = actList[eid]
	if not event then return end

	if event.times <= 0 then
		actList[eid] = nil
		return
	end

	if event.func then
		event.func(actor, unpack(event.arg))
		-- if actor == System.getGlobalNpc() then
		-- 	print("ontimer func")
		-- 	print(event.func)
		-- end
	end
	--WARN:这里需要再次判空的原因是如果在func中删除了定时器自身，则event会为nil
	if event then
		event.times = event.times - 1
		--不需再调用后移除
		if event.times <= 0 then
			actList[eid] = nil
		end
	end
end

_G.MY_PostScriptOnTimeEvent = onTimeEvent

--封装一个用于PostScriptEvent的方法
--该方法接受可以接受func, table等作为参数
--需要定时的方法不再需要进行_G全局化
--需要刷新的方法可以将传入的func进行闭包处理，eg. function (...) proc(...) end
function postScriptEvent(entity, delay, func, interval, times, ...)
	-- local et = entity

	if not entity then
		entity = System.getGlobalNpc()
	end

	local event = {}
	event.func = func
	event.arg = arg
	event.times = times == -1 and INT_MAX_NUM or times
	--次数不足直接不处理
	if event.times < 1 then return end

	local actList = getVarList(entity)
	if not actList then return end

	local eid = getEid()
	-- if et == nil then
	-- 	print(string.format("posttimer:eid=%d,times=%d,delay=%d,interval=%d", eid, event.times, delay, interval))
	-- 	print(event.func)
	-- 	print(debug.traceback())
	-- end
	actList[eid] = event

	event.pid = LActor.postScriptEvent(entity, delay, "MY_PostScriptOnTimeEvent", interval, event.times, eid)
	return eid
end

function postOnceScriptEvent(entity, delay, func, ...)
	return postScriptEvent(entity, delay, func, 0, 1, ...)
end

function cancelScriptTimer(entity, eid)
	if not entity then
		entity = System.getGlobalNpc()
	end

	if not eid then return end

	local actList = getVarList(entity)
	if not actList then return end

	local event = actList[eid]
	if not event then return end

	if event.pid then
		LActor.cancelScriptTimer(entity, event.pid)
		actList[eid] = nil
	end
end
function onGameStop()
    cleanActorList()
end

LActor.postScriptEventEx = postScriptEvent
LActor.postScriptEventLite = postOnceScriptEvent
LActor.cancelScriptEvent = cancelScriptTimer
actorevent.reg(aeUserLogout, cleanActorList)

 
engineevent.regGameStopEvent(onGameStop)
