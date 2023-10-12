module("base.engineevent.gametimer", package.seeall)
setfenv(1, base.engineevent.gametimer)

 

local System = System

function setupSystemOption()
	-- 定期执行的函数，在新开服的1日内不发送日志
	local now = System.getNowTime()
	local open = System.getOpenServerTime()
	local stop = false
	local saveTime = 1800
	if (now - open) < 24 * 3600 then
		stop = true
		saveTime = 3600
	end
	-- System.stopCounterLog(stop)
	-- System.stopEconomyLog(stop)
	-- System.setActorDbSaveTime(saveTime)
end

function checkDoubleExpAct()
	-- 检查双倍经验活动是否结束
	local now = System.getNowTime()
	local var_sys = System.getStaticVar()
	if var_sys.doubleexpend ~= nil and now >= var_sys.doubleexpend then
		var_sys.doubleexpend = nil

	--	System.setDoublePracticeExp(false)
	end
end

function fixCrossWarTeamBug()
	--WarFun.clearDeleteTeam()
end

--engineevent.regGameTimer(setupSystemOption)
--engineevent.regGameTimer(checkDoubleExpAct)
--engineevent.regGameTimer(fixCrossWarTeamBug)

