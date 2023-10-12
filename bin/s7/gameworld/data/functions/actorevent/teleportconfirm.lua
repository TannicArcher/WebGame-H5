module("actorevent.teleportconfirm", package.seeall)
setfenv(1, actorevent.teleportconfirm)

local tip = Lang.ScriptTips

-- 传送确认的功能，但目前只用于副本退出的确认
local function TeleportComfirm(actor, ...)
	if arg[1] == nil then return end
	local fbid = arg[1]
	local fbdata = FuBen[fbid]
	if fbdata == nil then
		print( "fbdata is nil:"..fbid )
		return 
	end

	local enterCount, addCount = Fuben.getEnterFubenInfo( actor, fbid )
	if addCount == nil	then
		addCount = 0
	end
	if enterCount == nil then
		enterCount = 0
	end

	local daycount = fbdata.daycount			

	if daycount == 0 or daycount + addCount - enterCount >= 1 then
		-- 再打一次副本
		LActor.messageBox(actor,0,0,tip.f00018,tip.f00056,string.format("%s,%d", tip.f00075, fbid),NULL,0,0,"",0,0,1)
	else	
		LActor.messageBox(actor,0,0,tip.f00018,tip.f00056,tip.f00057,NULL,0,0,"",0,0,1)
	end
end

actorevent.reg(aeTeleportComfirm, TeleportComfirm)
