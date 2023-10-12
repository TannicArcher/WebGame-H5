-- 跨服网络传送相关
module("crossnet" , package.seeall)
-- CrossNet = {}

--
local CrossNet = {}
function register(sysId, cmdId, func)
	local newFunc = handleNetMsg(sysId, cmdId, func)
	-- NetMsgsHandleT.reg(sysId, cmdId, newFunc)
	netmsgdispatcher.reg(sysId, cmdId, newFunc)
	if CrossNet[sysId] == nil then
		CrossNet[sysId] = {}
	end
	CrossNet[sysId][cmdId] = func
end

-- 消息处理函数
function handleNetMsg(sysId, cmdId, func)
	return function(actor, pack)
		func(pack, LActor.getActorId(actor), actor, System.getServerId())
	end
end

-- 转发消息到其它服 bId : 战斗服ID, sId : 目标服ID, sysId : 系统号 cmd : 协议号
function transferToServer(bId, sId, actorId, dp)
	local npack = WarFun.allocPacket()
	if npack == nil then return end

	LDataPack.writeByte(npack, CrossSrvCmd.SCrossNetCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCrossNetCmd_TransferToServer)
	LDataPack.writeInt(npack, sId)
	LDataPack.writeInt(npack, System.getServerId())
	LDataPack.writeInt(npack, actorId)
	LDataPack.writePacket(npack, dp)

	if System.isBattleSrv() then
		System.sendPacketToAllGameClient(npack, sId)
	else
		System.sendPacketToAllGameClient(npack, bId)
	end
end

-- 发送一个包给玩家 bId : 战斗服ID, sId : 目标服ID
function sendToActor(actor, bId, sId, actorId, dp)
	if actor ~= nil then
		LActor.sendData(actor, dp)
	else
		LDataPack.setPosition(dp, 0)

		local npack = WarFun.allocPacket()
		if npack == nil then return end

		LDataPack.writeByte(npack, CrossSrvCmd.SCrossNetCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCrossNetCmd_TransferToActor)
		LDataPack.writeInt(npack, sId)
		LDataPack.writeInt(npack, actorId)
		LDataPack.writePacket(npack, dp)
		System.sendPacketToAllGameClient(npack, bId ~= System.getServerId() and bId or sId)
	end
end

-- 发送一个信息包给连接的战斗服（通知到在那个服的本服玩家）
-- sId 本服id，0为直接广播（可以通过协议里的数据进行区分）
function transferToFightServer(sId, dp)
	local npack = WarFun.allocPacket()
	if npack == nil then return end

	LDataPack.writeByte(npack, CrossSrvCmd.SCrossNetCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCrossNetCmd_TransferToFightServer)
	LDataPack.writeInt(npack, sId)
	LDataPack.writePacket(npack, dp)
	System.sendPacketToAllGameClient(npack, 0)
end



-- 转发给其它服
function onTransferToServer(sId, sType, dp)
	local tarSid = LDataPack.readInt(dp)
	if System.getBattleSrvFlag() == bsCommSrv or (tarSid == System.getServerId()) then
		local srcSid = LDataPack.readInt(dp)
		local actorId = LDataPack.readInt(dp)
		local sysId = LDataPack.readByte(dp)
		local cmdId = LDataPack.readByte(dp)

		if CrossNet[sysId] == nil then return end
		local func = CrossNet[sysId][cmdId]
		if func ~= nil then
			func(dp, actorId, nil, srcSid)
		end
	else -- 转发到目标服
        System.sendPacketToAllGameClient(dp, tarSid)
	end
end

-- 转发给其它玩家
function onTransferToActor(sId, sType, dp)
	if System.getBattleSrvFlag() == bsCommSrv then -- 发送给玩家
		local sId = LDataPack.readInt(dp)
		local actorId = LDataPack.readInt(dp)

		local actor = LActor.getActorById(actorId)
		if actor ~= nil then
			local npack = LDataPack.allocPacket()
			if npack ~= nil then
				LDataPack.writePacket(npack, dp)
				LActor.sendData(actor, npack)
			end
		end
	else -- 转发到目标服
		local sId = LDataPack.readInt(dp)
		if sId == System.getServerId() then -- 战斗服的玩家
			local actorId = LDataPack.readInt(dp)

			local actor = LActor.getActorById(actorId)
			if actor ~= nil then
				local npack = LDataPack.allocPacket()
				if npack ~= nil then
					LDataPack.writePacket(npack, dp)
					LActor.sendData(actor, npack)
				end
			end
		else
			System.sendPacketToAllGameClient(dp, sId)
		end
	end
end

-- 转发给玩家
function onTransferToFightServer(sId, sType, dp)
	if System.getBattleSrvFlag() == bsCommSrv then
		return
	end
	local sId = LDataPack.readInt(dp)
	if sId == 0 then
		-- sId 数据包来源服务器id，0为直接广播（可以通过协议里的数据进行区分）
		local npack = LDataPack.allocPacket()
		if npack ~= nil then
			LDataPack.writePacket(npack, dp)
			System.broadcastData(npack)
		end
	else
		local actors = LuaHelp.getAllActorList()
		if not actors then return end

		local npack = LDataPack.allocPacket()
		if npack ~= nil then
			LDataPack.writePacket(npack, dp)
			for i=1, #actors do
				local actor = actors[i]
				if LActor.getRealServerId(actor) == sId then
					LActor.sendData(actor, npack)
				end
			end
		end
	end
end


csmsgdispatcher.Reg(CrossSrvCmd.SCrossNetCmd, CrossSrvSubCmd.SCrossNetCmd_TransferToServer, onTransferToServer)
csmsgdispatcher.Reg(CrossSrvCmd.SCrossNetCmd, CrossSrvSubCmd.SCrossNetCmd_TransferToActor, onTransferToActor)
csmsgdispatcher.Reg(CrossSrvCmd.SCrossNetCmd, CrossSrvSubCmd.SCrossNetCmd_TransferToFightServer, onTransferToFightServer)
