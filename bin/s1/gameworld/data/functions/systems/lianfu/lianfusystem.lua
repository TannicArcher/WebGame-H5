module("systems.lianfu.lianfusystem", package.seeall)
setfenv(1, systems.lianfu.lianfusystem)

local lianfuutils = require("systems.lianfu.lianfuutils")
local actorevent = require("actorevent.actorevent")

require("protocol")

local systemId = SystemId.lianfuSystemId
local protocol = LianfuSystemProtocol
local LDataPack = LDataPack

function onLogin(actor)
	if System.isCrossWarSrv() then return end

	if System.isCommSrv() then
		--恢复原来的pk模式
		local var = LActor.getSysVar(actor)
		if var.lfpkMode then
			LActor.setPkMode(actor, var.lfpkMode)
			var.lfpkMode = nil
		end
	end

	local flag = LianfuFun.isLianfu()

	local pack = LDataPack.allocPacket(actor, systemId, protocol.sLianfuOpen)
	if not pack then return end
	LDataPack.writeByte(pack, flag and 1 or 0)
	local time = lianfuutils.getLianfuTime()
	LDataPack.writeUInt(pack, time or 0)
	LDataPack.flush(pack)
end

actorevent.reg(aeUserLogin, onLogin)
