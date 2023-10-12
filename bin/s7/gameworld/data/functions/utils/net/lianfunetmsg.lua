module("utils.actornetmsg", package.seeall)
setfenv(1, utils.actornetmsg)

local dispatcher = {}

function reg(sysId, cmd, func)
	if sysId > 256 or cmd > 256 then 
		print("lf netmsg sysId or cmd error")
		return
	end

	dispatcher[sysId] = dispatcher[sysId] or {}

	dispatcher[sysId][cmd] = func

	LianfuFun.registerNetMsg(sysId, cmd)
end

function OnLFNetmsg(sysId, cmdId, dp, sActorId)
	if not dispatcher[sysId] then return end

	local func = dispatcher[sysId][cmdId]
	if func then
		func(sActorId, dp, srcActor)
	end
end

_G.OnLFNetmsg = OnLFNetmsg
