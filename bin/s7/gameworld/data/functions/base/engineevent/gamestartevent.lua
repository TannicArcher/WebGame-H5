module("base.engineevent.gamestartevent", package.seeall)
setfenv(1, base.engineevent.gamestartevent)

local pTimer      	= require("base.scripttimer.postscripttimer")
local modSysVar 	= require("utils.systemfunc")

local System = System
local LActor = LActor

local SAVE_SYSVAR_TIME = 3600 * 1000 * 2 -- 保存系统数据的时间间隔

function GameStartInitActivity()
	-- local sysVar = System.getStaticVar()
	-- if sysVar.openfcm == 1 then
	-- 5s检测一次
	System.start5sScripte(true)
	-- end
	-- 设置服务器定期GC的在线人数
	System.setEngineGcActorCnt(1500)

	-- -- 二次充值活动已经结束
	-- if sysVar.round2PayClose == 0 and sysVar.round2PayEndTime ~= nil and
	-- 	System.getNowTime() > sysVar.round2PayEndTime then
	-- 	sysVar.round2PayClose = 1
	-- end

	-- if sysVar.round2PayClose == nil then sysVar.round2PayClose = 1 end
end

function sendOnlineCount( ... )
	System.logOnline()
end

function sendOnlineInit()
	-- 每隔1分钟发送一次在线人数到日志系统 --后台让改成10了
	local min_1 = 60 * 1000
	pTimer.postScriptEvent(nil, min_1, function ( ... )
		sendOnlineCount()
	end, min_1, -1)

	pTimer.postScriptEvent(nil, SAVE_SYSVAR_TIME, function(...) modSysVar.saveAll() end, SAVE_SYSVAR_TIME, -1)
end

engineevent.regGameStartEvent(GameStartInitActivity)
engineevent.regGameStartEvent(sendOnlineInit)
