module("exring", package.seeall)


local config = ExRingConfig
local ringConf = {}

local CURRENT_RING_COUNT = 2
ringConf[0] = ExRing0Config
ringConf[1] = ExRing1Config
ringConf[2] = ExRing2Config
ringConf[3] = ExRing3Config


local function calcAttr(role, recalc)
	local attr = LActor.getExRingAttr(role)
	attr:Reset();
	local ex_attr = LActor.getExRingExAttr(role)
	ex_attr:Reset();
	local ex_power = 0
	for i = 0, CURRENT_RING_COUNT-1 do
		local level = LActor.getExRingLevel(role, i)
		--attr:Add(config[i].at1 or 0, ringConf[i][level].attr1 or 0)
		--attr:Add(config[i].at2 or 0, ringConf[i][level].attr2 or 0)
		--attr:Add(config[i].at3 or 0, ringConf[i][level].attr3 or 0)
		--attr:Add(config[i].at4 or 0, ringConf[i][level].attr4 or 0)
		--attr:Add(config[i].at5 or 0, ringConf[i][level].attr5 or 0)
		
		if ringConf[i][level].attrAward then
			for _,v in ipairs(ringConf[i][level].attrAward) do
				attr:Add(v.type or 0, v.value or 0)
			end
		end
		if ringConf[i][level].extAttrAward then
			for _,v in ipairs(ringConf[i][level].extAttrAward) do
				ex_attr:Add(v.type or 0, v.value or 0)
			end
		end
		if ringConf[i][level].power then
			ex_power = ex_power + ringConf[i][level].power
		end
	end
	attr:SetExtraPower(ex_power)
	if recalc then
		LActor.reCalcAttr(role)
	end
	return true
end

local function onReqUpgrade(actor, packet)
	local id = LDataPack.readShort(packet)
	local roleid = LDataPack.readShort(packet)
	
	if ringConf[id] == nil then return end
	if config[id] == nil then return end

	local role = LActor.getRole(actor, roleid)
	if role == nil then return end
	local level = LActor.getExRingLevel(role, id)
    if ringConf[id][level] == nil then return end

    if level >= #ringConf[id] then return end

	local count = LActor.getItemCount(actor, config[id].costItem)
	if count < ringConf[id][level].cost then
		print("not enough ring fragment")
		return
	end
	LActor.costItem(actor, config[id].costItem, ringConf[id][level].cost, "upgrade ex ring")
	LActor.setExRingLevel(role, id, level + 1)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_ExRing, Protocol.sExRingCmd_UpdateRing)
	if npack == nil then return end

	LDataPack.writeShort(npack, id)
	LDataPack.writeShort(npack, roleid)
	LDataPack.writeShort(npack, level + 1)
	LDataPack.flush(npack)

	calcAttr(role, true)
	if (0 == id) then
		actorevent.onEvent(actor,aeParalysis,1,false)
	elseif(1 == id) then
		actorevent.onEvent(actor,aeProtective,1,false)
	end
end


netmsgdispatcher.reg(Protocol.CMD_ExRing, Protocol.cExRingCmd_UpgradeRing, onReqUpgrade)

_G.calcExRingAttr = calcAttr
