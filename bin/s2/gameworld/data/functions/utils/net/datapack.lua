module("utils.net.datapack", package.seeall)
setfenv(1, utils.net.datapack)

local LDataPack = LDataPack
local dtByte = dtByte

function allocBroadcastPacket(systemId, protocolId)
	local pack = LDataPack.allocPacket()
	if not pack then return end

	LDataPack.writeData(pack, 2,
		dtByte, systemId,
		dtByte, protocolId)

	return pack
end

LDataPack.allocBroadcastPacket = allocBroadcastPacket
LDataPack.allocLfPacket = allocBroadcastPacket
