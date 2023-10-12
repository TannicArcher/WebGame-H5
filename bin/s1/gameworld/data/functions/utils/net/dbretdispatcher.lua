module("utils.net.dbretdispatcher", package.seeall)

local dispatcher = {}

--注册数据库返回的处理函数 cmd为消息号
function reg(sysid, cmd, proc)
	print(string.format("dispatcher reg %d %d", sysid, cmd))

	if not proc then 
		print(string.format("dbretdispatcher is nil with cmd : %d", cmd))
		return false
	end

	local proclist = dispatcher[sysid]
	if not proclist or type(proclist) ~= "table" then
		dispatcher[sysid] = {}
		proclist = dispatcher[sysid]
	end

	if proclist[cmd] ~= nil then 
		print(string.format("dbretdispatcher is already regist with cmd : %d", cmd))
		return false 
	end

	proclist[cmd] = proc

	System.setDbRetRoute(sysid, cmd, 1)

	return true
end

function OnDbReturnDispatcher(reader, sysid, cmd)
	if reader == nil or sysid == nil or cmd == nil then return end
	
	print(string.format("OnDbReturnDispatcher:%d %d", sysid, cmd))
	
	local proclist = dispatcher[sysid]
	if not proclist then return end

	local proc = proclist[cmd]
	if not proc then return end
	
	if sysid == dbEntity then 
		OnEntityDbReturnData(reader, cmd, proc)
	else
		proc(reader, cmd)
	end
end

function OnEntityDbReturnData(reader, cmd, proc)
	local actorId = LDataPack.readInt(reader)
	local err = LDataPack.readByte(reader)
	if actorId == 0 then 
		print(string.format("Query actor data Error!!ActorID = %d", actorId))
		return 
	end
	local actor = LActor.getActorById(actorId)
	if not actor then return end
	if err ~= 0 then 
		print(string.format("EntityDbReturnData Error with cmd=%d, actorId=%d, errorID=%d, serverID=%d" , cmd, actorId, err, LActor.getServerId(actor)))
		return
	end
	proc(actor, reader, err)
end

_G.OnDbRetDispatcher = OnDbReturnDispatcher
