module("actorlogin" , package.seeall)



local function onLogin(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_ServerOpenDay)
	LDataPack.writeInt(npack, System.getOpenServerDay())
	LDataPack.writeInt(npack, System.getOpenServerStartDateTime())
	LDataPack.writeInt(npack, hefutime.getHeFuDayStartTime() or 0)
	LDataPack.writeInt(npack, hefutime.getHeFuCount() or 0)
	LDataPack.writeByte(npack, csbase.hasCross and 1 or 0)
	LDataPack.flush(npack)
end

local function onNewDay(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_ServerOpenDay)
	LDataPack.writeInt(npack, System.getOpenServerDay())
	LDataPack.writeInt(npack, System.getOpenServerStartDateTime())
	LDataPack.writeInt(npack, hefutime.getHeFuDayStartTime() or 0)
	LDataPack.writeInt(npack, hefutime.getHeFuCount() or 0)
	LDataPack.writeByte(npack, csbase.hasCross and 1 or 0)
	LDataPack.flush(npack)
end

actorevent.reg(aeUserLogin,onLogin)
actorevent.reg(aeNewDayArrive,onNewDay)
