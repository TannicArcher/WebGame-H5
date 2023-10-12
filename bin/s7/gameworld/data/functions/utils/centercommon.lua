module("utils.centercommon", package.seeall)
setfenv(1, utils.centercommon)

require("protocol")

local centerservermsg = require("utils.net.centerservermsg")
local defaultSystemId = SystemId.enDefaultEntitySystemID
local protocol = defaultSystemProtocol.CentSrvCmd
local sendTipmsg = LActor.sendTipmsg

function allocCenterPacket(toServerId, sysId, subId)
	local pack = LDataPack.allocPacketToCenter()
	if not pack then return end

	LDataPack.writeData(pack, 3, dtInt, toServerId, dtByte, sysId, dtByte, subId)
	return pack
end

function allocActorServerPacket(actorid, sysId, subId)
	local pack = LDataPack.allocPacketToCenter()
	if not pack then return end

	LDataPack.writeData(pack, 3, dtInt, actorid, dtByte, sysId, dtByte, subId)
	return pack
end

--toServerId == 0 全部服广播
--actorId == 0 全服广播
function sendCenterTipmsg(toServerId, actorId, msg, msgType)
	if not toServerId then return end
	local pack = LDataPack.allocCenterPacket(toServerId, defaultSystemId, protocol.sSendTips)
	if not pack then return end
	actorId = actorId or 0
	msg = msg or ""
	msgType = msgType or ttMessage
	LDataPack.writeInt(pack, actorId)
	LDataPack.writeString(pack, msg)
	LDataPack.writeInt(pack, msgType)
	System.sendDataToCenter(pack)
end

function recieveCenterTipmsg(packet)
	local actorId = LDataPack.readInt(packet)
	local msg = LDataPack.readString(packet)
	local msgType = LDataPack.readInt(packet)

	if actorId == 0 then
		local actors = LuaHelp.getAllActorList()
		for _, actor in ipairs(actors) do 
			sendTipmsg(actor, msg, msgType)
		end
	else
		local actor = LActor.getActorById(actorId)
		if actor then
			sendTipmsg(actor, msg, msgType)
		end
	end
end

LDataPack.allocCenterPacket = allocCenterPacket
LDataPack.allocActorServerPacket = allocActorServerPacket

centerservermsg.reg(defaultSystemId, protocol.sSendTips, recieveCenterTipmsg)
