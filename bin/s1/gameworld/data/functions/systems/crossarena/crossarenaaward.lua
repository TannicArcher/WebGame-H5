--跨服竞技场奖励
module("crossarenaaward", package.seeall)

require("systems.crossarena.crossarenacommon")
local getActorVar = crossarenacommon.getActorVar

local function actor_log(actor, str)
	if not actor or not str then return end

	print("error crossarenaaward, actorId:"..LActor.getActorId(actor).."log:"..str)
end

local function sendInfo(actor)
	local var = getActorVar(actor)
	if not var then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_SendAwardInfo)
	if not pack then return end

	LDataPack.writeInt(pack, var.lastMetal or 1)
	LDataPack.writeInt(pack, var.lastMetalAward or 0)
	LDataPack.writeInt(pack, var.peakCount or 0)
	LDataPack.writeInt(pack, var.peakAward or 0)

	LDataPack.flush(pack)
end

--领取每日奖励
local function getEveryDayAward(actor)
	local var = getActorVar(actor)
	if not var then return end

	if not var.lastMetal or var.lastMetalAward then
		LActor.sendTipmsg(actor, LAN.FUBEN.ca23)
		return
	end

	local config
	for _, v in pairs(CrossArenaBase.everyDayAward) do
		if v.metal == var.lastMetal then
			config = v
			break
		end
	end
	if not config then
		actor_log(actor, "not has this everyDayAward "..var.lastMetal)
		return
	end

	var.lastMetalAward = 1
	LActor.giveAwards(actor, config.award, "crossArena everyDayAward")

	sendInfo(actor)
end

--领取巅峰令达标奖励
local function getPeakAward(actor, packet)
	local idx = LDataPack.readInt(packet)

	local var = getActorVar(actor)
	if not var or not var.peakCount then
		actor_log(actor, "getPeakAward not init data")
		return
	end

	local config = CrossArenaBase.peakAwards[idx]
	if not config then return end

	if config.count > var.peakCount then return end

	if System.bitOPMask(var.peakAward, idx) then
		 return
	end

	var.peakAward = System.bitOpSetMask(var.peakAward, idx, true)

	LActor.giveAwards(actor, config.award, "crossArena peak")

	sendInfo(actor)
end


actorevent.reg(aeUserLogin, sendInfo)
netmsgdispatcher.reg(Protocol.CMD_Cross3Vs3, Protocol.cCross3vs3_GetMetalAward, getEveryDayAward)
netmsgdispatcher.reg(Protocol.CMD_Cross3Vs3, Protocol.cCross3Vs3_GetPeakAward, getPeakAward)
