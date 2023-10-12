module("netmsgdispatcher", package.seeall)

local dispatcher = {}

-- 注册网络包的处理函数，sysid是系统id，pid是系统内的消息号，
-- 其中pid==0，表示把这个系统的所有消息都用proc函数处理
-- noBattle == true 跨服情况下不执行
function reg(sysid, cmd, func)
	if cmd == nil or sysid == nil then print( debug.traceback() ) end
	if sysid > 256 or cmd > 256 then
		print("net msg sysId or cmd error")
		return
	end

	dispatcher[sysid] = dispatcher[sysid] or {}
	dispatcher[sysid][cmd] = func

	System.regScriptNetMsg(sysid, cmd)
	return true
end

function OnNetMsg(sysId, cmdId, actor, pack)
	if not dispatcher[sysId] then return end

	local func = dispatcher[sysId][cmdId]
	--print("玩家:"..LActor.getActorId(actor)..",收到消息请求,系统:"..sysId..",协议:"..cmdId)
	if func then
		func(actor, pack)
	end
end

_G.OnNetMsg= OnNetMsg






