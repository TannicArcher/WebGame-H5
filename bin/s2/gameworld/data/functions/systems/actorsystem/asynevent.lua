--异步事件
module("asynevent", package.seeall)



asynEvents = asynEvents or {}


--[[异步处理函数格式
 -function (tarActor, ...)
    tarActor 要处理的角色
    args
 -end
--]]


--actor调用者
--tarId需要处理的玩家id
--func回调函数
--...自定义参数
function reg(tarid, func, ...)
    if asynEvents[tarid] == nil then
        asynEvents[tarid] = {}
        table.insert(asynEvents[tarid], {func, arg})
        LActor.regAsynEvent(tarid)
    else
	    table.insert(asynEvents[tarid], {func, arg})
    end
	print( tarid .. " asynevent.reg: ok")
end

--actor 触发者
local function onEvent(actor)
	local aid = LActor.getActorId(actor)
    if asynEvents[aid] == nil then return end
    for _, v in ipairs(asynEvents[aid]) do
        v[1](actor, unpack(v[2]))
    end
    asynEvents[aid] = nil
	print( aid .. " asynevent.onEvent: ok")
end

--c++ aev_list 超时，把lua对应asynEvents删除
local function onTimeOut(aid)
    asynEvents[aid] = nil
    print( aid .. " asynevent.onEvent.onTimeOut")
end


_G.onAsynEvent = onEvent
_G.onAsynEventTimeOut = onTimeOut
