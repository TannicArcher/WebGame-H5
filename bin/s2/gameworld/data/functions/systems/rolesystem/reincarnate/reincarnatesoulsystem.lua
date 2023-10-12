module("reincarnatesoulsystem", package.seeall)

function sendInfo(actor, roleId, posId, level)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Equip, Protocol.sEquipCmd_ReqSoulEquip)
	LDataPack.writeShort(npack, roleId)
	LDataPack.writeShort(npack, posId)
    LDataPack.writeShort(npack, level)
	LDataPack.flush(npack)
end

local function updateAttr(actor, roleId)
	local actorId = LActor.getActorId(actor)
	local role = LActor.getRole(actor, roleId)
	if not role then return end
	local attr = LActor.getSoulAttr(actor, roleId)
	if not attr then return end
	attr:Reset()

	local exAttr = LActor.getSoulExAttr(actor, roleId)
	if not exAttr then return end
	exAttr:Reset()

	local job = LActor.getJob(role)
	local power = 0
	for pos = EquipSlotType_Hats, EquipSlotType_Shield do
		--判断该部位有没有装备
		local itemId = LActor.getEquipId(role, pos)
		local level = LActor.getSoulLevel(actor, roleId, pos)
		if 0 ~= itemId and ReincarnationSoulLevel[job] and ReincarnationSoulLevel[job][pos] and ReincarnationSoulLevel[job][pos][level] then
			local conf = ReincarnationSoulLevel[job][pos][level]
			local demonLevel = conf.demonLevel or 0
			local soulLinkLevel = conf.soulLinkLevel or 0

			--魔魂属性
			for _, v in pairs(conf.attrs or {}) do attr:Add(v.type, v.value) end
			for _, v in pairs(conf.ex_attrs or {}) do exAttr:Add(v.type, v.value) end
			power = power + (conf.ex_power or 0)

			--魔化属性
			if 0 < demonLevel and ReincarnationDemonLevel[pos] and ReincarnationDemonLevel[pos][demonLevel] then
				local conf = ReincarnationDemonLevel[pos][demonLevel]
				if 0 < (conf.precent or 0) then
					local equipAttr = LActor.getEquipAttr(actor, roleId, pos)

					for attrType = Attribute.atHpMax, Attribute.atTough do
						if 0 < (equipAttr[attrType] or 0) then
							attr:Add(attrType, math.floor(equipAttr[attrType]*conf.precent/10000))
						end
					end

					--给固定属性加成
					for k, v in pairs(ReincarnationBase.effectAttrType or {}) do
						if 0 < (equipAttr[v] or 0) then
							attr:Add(v, math.floor(equipAttr[v]*conf.precent/10000))
							--power = power + math.floor(equipAttr:GetExtraPower()*conf.precent/10000)
						end
					end
				end
			end

			--灵魂锁链属性
			conf = ReincarnationLinkLevel[pos]
			for posId, cfg in pairs(conf or {}) do
				local itemId = LActor.getEquipId(role, posId)
				if 0 ~= itemId then
					--取得两个装备的最小灵魂锁链等级
					local soulLevel = LActor.getSoulLevel(actor, roleId, posId)
					local mixLevel = math.min(soulLevel, level)

					if cfg[mixLevel] then
						for _, v in pairs(cfg[mixLevel].attrs or {}) do attr:Add(v.type, v.value) end
						for _, v in pairs(cfg[mixLevel].ex_attrs or {}) do exAttr:Add(v.type, v.value) end
						power = power + (cfg[mixLevel].ex_power or 0)
					end
				end
			end
		end
	end

	attr:SetExtraPower(power)
	LActor.reCalcAttr(role)
	LActor.reCalcExAttr(role)
end

local function onReqSoulEquip(actor, packet)
	local roleId = LDataPack.readShort(packet)
	local posId = LDataPack.readShort(packet)
	local actorId = LActor.getActorId(actor)

	local role = LActor.getRole(actor, roleId)
	if not role then print("reincarnatesoulsystem.onReqSoulEquip:role nil, roleId:"..tostring(roleId)..", actorId:"..tostring(actorId)) return end

	--做个部位判断
	if posId < EquipSlotType_Hats or posId > EquipSlotType_Shield then
		print("reincarnatesoulsystem.onReqSoulEquip:posId error, posId:"..tostring(posId)..", actorId:"..tostring(actorId))
		return
	end

	--该部位没有装备则不能注魔
	local itemId = LActor.getEquipId(role, posId)
	if 0 == itemId then
		print("reincarnatesoulsystem.onReqSoulEquip:itemId 0, roleId:"..tostring(roleId)..", pos:"..tostring(posId)..", actorId:"..tostring(actorId))
		return
	end

	local level = LActor.getSoulLevel(actor, roleId, posId)
	local job = LActor.getJob(role)

	local conf = nil
	if ReincarnationSoulLevel[job] and ReincarnationSoulLevel[job][posId] and ReincarnationSoulLevel[job][posId][level+1] then
		conf = ReincarnationSoulLevel[job][posId][level+1]
	end

	if not conf then
		print("reincarnatesoulsystem.onReqSoulEquip:conf nil, job:"..tostring(job)..", pos:"..tostring(posId)..", level:"..tostring(level+1)
			..", actorId:"..tostring(actorId))
		return
	end

	if conf.materialInfo then
		if conf.materialInfo.count > LActor.getItemCount(actor, conf.materialInfo.id) then
			print("reincarnatesoulsystem.onReqSoulEquip:not enough, itemId:"..tostring(conf.materialInfo.id)..", actorId:"..tostring(actorId))
			return
		end

		LActor.costItem(actor, conf.materialInfo.id, conf.materialInfo.count, "equipsoul")
		LActor.setSoulLevel(actor, roleId, posId, level+1)

		sendInfo(actor, roleId, posId, level+1)
		updateAttr(actor, roleId)
	end
end

local function onInit(actor)
	for i=0, LActor.getRoleCount(actor) - 1 do updateAttr(actor, i) end
end

local function onEquipItem(actor, roleId, slot)
	if EquipSlotType_Hats <= slot and EquipSlotType_Shield >= slot then updateAttr(actor, roleId) end
end

local function initGlobalData()
	actorevent.reg(aeInit, onInit)
	actorevent.reg(aeAddEquiment, onEquipItem)

	netmsgdispatcher.reg(Protocol.CMD_Equip, Protocol.cEquipCmd_ReqSoulEquip, onReqSoulEquip)
end

table.insert(InitFnTable, initGlobalData)


local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.reincarnatesoulsystem = function(actor, args)

end
