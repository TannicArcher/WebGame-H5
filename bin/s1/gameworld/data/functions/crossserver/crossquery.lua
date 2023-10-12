
module("crossquery" , package.seeall)

local cmd = CrossSrvCmd
local subCmd = CrossSrvSubCmd

local function onSrcToCross(sId, sType, dp)
	local tarServerId = LDataPack.readInt(dp)
	local tarActorId = LDataPack.readInt(dp)
	local srcServerId = LDataPack.readInt(dp)
	local srcActorId = LDataPack.readInt(dp)
	
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, cmd.SCQueryCmd)
	LDataPack.writeByte(pack, subCmd.SCQueryCmd_CrossToTar)
	LDataPack.writeInt(pack, tarServerId)
	LDataPack.writeInt(pack, tarActorId)
	LDataPack.writeInt(pack, srcServerId)
	LDataPack.writeInt(pack, srcActorId)
	
	System.sendPacketToAllGameClient(pack, tarServerId)
end

local function asyneventQueryCross(tarActor, tarServerId, tarActorId, srcServerId, srcActorId, sId)
	local actorPacket = LActor.getActorInfoPacket(tarActor)
	if actorPacket == nil then
	    return
	end
	if LDataPack.getLength(actorPacket) == 0 then
	    return
	end

	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, cmd.SCQueryCmd)
	LDataPack.writeByte(pack, subCmd.SCQueryCmd_TarToCross)
	LDataPack.writeInt(pack, tarServerId)
	LDataPack.writeInt(pack, tarActorId)
	LDataPack.writeInt(pack, srcServerId)
	LDataPack.writeInt(pack, srcActorId)

	LDataPack.writePacket(pack,actorPacket)
	
	System.sendPacketToAllGameClient(pack, sId)
end

local function onCrossToTar(sId, sType, dp)
	local tarServerId = LDataPack.readInt(dp)
	local tarActorId = LDataPack.readInt(dp)
	local srcServerId = LDataPack.readInt(dp)
	local srcActorId = LDataPack.readInt(dp)
	
	local curServerId = System.getServerId()

	if curServerId == tarServerId then
		asynevent.reg(tarActorId, asyneventQueryCross, tarServerId, tarActorId, srcServerId, srcActorId, sId)
	end
end

local function onTarToCross(sId, sType, dp)
	local tarServerId = LDataPack.readInt(dp)
	local tarActorId = LDataPack.readInt(dp)
	local srcServerId = LDataPack.readInt(dp)
	local srcActorId = LDataPack.readInt(dp)
	
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, cmd.SCQueryCmd)
	LDataPack.writeByte(pack, subCmd.SCQueryCmd_CrossToSrc)
	LDataPack.writeInt(pack, tarServerId)
	LDataPack.writeInt(pack, tarActorId)
	LDataPack.writeInt(pack, srcServerId)
	LDataPack.writeInt(pack, srcActorId)
	LDataPack.writePacket(pack,dp,false)
	
	System.sendPacketToAllGameClient(pack, srcServerId)
end

local function onCrossToSrc(sId, sType, dp)
	local tarServerId = LDataPack.readInt(dp)
	local tarActorId = LDataPack.readInt(dp)
	local srcServerId = LDataPack.readInt(dp)
	local srcActorId = LDataPack.readInt(dp)

	local curServerId = System.getServerId()


	
	if curServerId == srcServerId then
		local srcActor = LActor.getActorById(srcActorId)
		if srcActor then
			local pack = LDataPack.allocPacket(srcActor, Protocol.CMD_Base, Protocol.sBaseCmd_ResActorInfo)
			if pack == nil then return end
			LDataPack.writePacket(pack,dp,false)
			LDataPack.flush(pack)
		end
	end
end

local function GetOtherSrvActorDetail(actor, tarServerId, tarActorId)
	if not System.isCommSrv() then return end
	
	local srcServerId = System.getServerId()
	local srcActorId = LActor.getActorId(actor)

	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, cmd.SCQueryCmd)
	LDataPack.writeByte(pack, subCmd.SCQueryCmd_SrcToCross)
	LDataPack.writeInt(pack, tarServerId)
	LDataPack.writeInt(pack, tarActorId)
	LDataPack.writeInt(pack, srcServerId)
	LDataPack.writeInt(pack, srcActorId)
	
	System.sendPacketToAllGameClient(pack, csbase.GetMainBattleSvrId())
end
_G.GetOtherSrvActorDetail = GetOtherSrvActorDetail


csmsgdispatcher.Reg(cmd.SCQueryCmd, subCmd.SCQueryCmd_SrcToCross, onSrcToCross)
csmsgdispatcher.Reg(cmd.SCQueryCmd, subCmd.SCQueryCmd_CrossToTar, onCrossToTar)
csmsgdispatcher.Reg(cmd.SCQueryCmd, subCmd.SCQueryCmd_TarToCross, onTarToCross)
csmsgdispatcher.Reg(cmd.SCQueryCmd, subCmd.SCQueryCmd_CrossToSrc, onCrossToSrc)
