--[[
	author = 'Roson'
	time   = 05.07.2015
	name   = 跨服广播助手
	ver    = 0.1
]]

module("systems.lianfu.lianfuchat", package.seeall)
setfenv(1, systems.lianfu.lianfuchat)

require("protocol")
local sysId = SystemId.enChatSystemID
local protocol = chatSystemProtocol

function broadcastLevelTipmsg(tipMsg, level, tipMsgType)
	if not tipMsg then return end
	if not tipMsgType then tipMsgType = ttMessage end
	if not level then level = 0 end

	local pack = LDataPack.allocBroadcastPacket(sysId, protocol.sSendAMsg)
	if not pack then return end

	LDataPack.writeData(pack, 3,
		dtChar, level,
		dtInt, tipMsgType,
		dtString, tipMsg)

	LianfuFun.broadcastData(pack)
end

function broadcastTipmsg(tipMsg, tipMsgType)
	broadcastLevelTipmsg(tipMsg, 0, tipMsgType)
end

function sendTipmsg(actorId, tipMsg, tipMsgType)
	local onLineSrvId = LianfuFun.getOnlineServerId(actorId)
	if onLineSrvId <= 0 then return end

	local pack = LDataPack.allocBroadcastPacket(sysId, protocol.sSendAMsg)
	if not pack then return end

	LDataPack.writeData(pack, 3,
		dtChar, 0,
		dtInt, tipMsgType,
		dtString, tipMsg)

	LianfuFun.sendToActor(actorId, pack)
end

function broadcastGuildTipmsg(guildId, tipMsg)
	local pack = LDataPack.allocExtraPacket()
	if not pack then return end

	LDataPack.writeData(pack, 3,
		dtByte, sysId,
		dtByte, protocol.sGuildTipMsg,
		dtString, tipMsg)

	LianfuFun.guildBroadCast(guildId, pack)
end

-- 注册用于连服广播的方法
LianfuFun.broadcastLevelTipmsg = broadcastLevelTipmsg
LianfuFun.broadcastTipmsg = broadcastTipmsg
LianfuFun.sendTipmsg = sendTipmsg
LianfuFun.broadcastGuildTipmsg = broadcastGuildTipmsg

