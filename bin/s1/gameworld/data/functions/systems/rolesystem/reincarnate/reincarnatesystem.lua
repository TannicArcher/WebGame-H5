module("reincarnatesystem", package.seeall)

local keyList = {}
for k in pairs(ReincarnateSuit or {}) do keyList[#keyList+1] = k end
table.sort(keyList)

local function onAddExp(posId, level, exp)
	local conf = ReincarnateSpirit[posId][level+1]
	while conf and exp >= conf.consume do
		exp = exp - conf.consume
		level = level + 1
		conf = ReincarnateSpirit[posId][level+1]
	end

	return level, exp
end

local function initSuitAttr(actor, roleId)
	local role = LActor.getRole(actor, roleId)
	if not role then return end

	local attr = LActor.GetReincarnateEquipAttr(actor, roleId)
	if not attr then return end
	attr:Reset()

	local exattr = LActor.GetReincarnateEquipExAttr(actor, roleId)
	if not exattr then return end
	exattr:Reset()

	--获取部位装备等级集合
	local list = {}
	for pos = EquipSlotType_Hats, EquipSlotType_Shield do
		local itemId = LActor.getEquipId(role, pos)
		local level = 0
		if ItemConfig[itemId] then level = ItemConfig[itemId].zsLevel or 0 end
		table.insert(list, level)
	end

	table.sort(list)

	local conf = nil
	for i = #keyList, 1, -1 do
		if list[1] >= keyList[i] then conf = ReincarnateSuit[keyList[i]] break end
	end

	if conf then
		for _, v in pairs(conf.attrs or {}) do attr:Add(v.type, v.value) end
		for _, v in pairs(conf.exAttrs or {}) do exattr:Add(v.type, v.value) end
		attr:SetExtraPower(conf.ex_power or 0)
		LActor.reCalcAttr(role)
		LActor.reCalcExAttr(role)
	end
end

local function updateAttr(actor, roleId)
	local actorId = LActor.getActorId(actor)
	local role = LActor.getRole(actor, roleId)
	if not role then return end
	local attr = LActor.getFulingAttr(actor, roleId)
	if not attr then return end
	attr:Reset()

	local exAttr = LActor.getFulingExAttr(actor, roleId)
	if not exAttr then return end
	exAttr:Reset()

	local isAdd = false
	for pos = EquipSlotType_Hats, EquipSlotType_Shield do

		--判断该部位有没有装备
		local itemId = LActor.getEquipId(role, pos)
		if 0 ~= itemId then
			local level, exp = LActor.getFulingInfo(actor, roleId, pos)
			if ReincarnateSpirit[pos] and ReincarnateSpirit[pos][level] then
				if not isAdd then isAdd = true end
				local conf = ReincarnateSpirit[pos][level]
				for _, v in pairs(conf.attrs or {}) do attr:Add(v.type, v.value) end
				for _, v in pairs(conf.exAttrs or {}) do exAttr:Add(v.type, v.value) end

				if 0 < (conf.precent or 0) then
					local equipAttr = LActor.getEquipAttr(actor, roleId, pos)
					for _, v in pairs(equipAttr or {}) do attr:Add(v.type, math.floor(v.value*conf.precent/10000)) end
				end
			end
		end
	end

	if isAdd then LActor.reCalcAttr(role) LActor.reCalcExAttr(role) end
end

function confirmExp(actor, roleId, posId, level, exp)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Equip, Protocol.sEquipCmd_ReqFulingSmelt)
	LDataPack.writeShort(npack, roleId)
	LDataPack.writeShort(npack, posId)
    LDataPack.writeShort(npack, level)
    LDataPack.writeInt(npack, exp)
	LDataPack.flush(npack)
end

local function onReqFulingSmelt(actor, packet)
	local roleId = LDataPack.readShort(packet)
	local posId = LDataPack.readShort(packet)
	local actorId = LActor.getActorId(actor)
	local count = LDataPack.readShort(packet)

	local role = LActor.getRole(actor, roleId)
	if not role then print("reincarnatesystem.onReqFulingSmelt:role nil, roleId:"..tostring(roleId)..", actorId:"..tostring(actorId)) return end

	--做个部位判断
	if posId < EquipSlotType_Hats or posId > EquipSlotType_Shield then
		print("reincarnatesystem.onReqFulingSmelt:posId error, posId:"..tostring(posId)..", actorId:"..tostring(actorId))
		return
	end

	--该部位没有装备则不能附灵
	local itemId = LActor.getEquipId(role, posId)
	if 0 == itemId then
		print("reincarnatesystem.onReqFulingSmelt:itemId 0, roleId:"..tostring(roleId)..", pos:"..tostring(posId)..", actorId:"..tostring(actorId))
		return
	end

	local level, exp = LActor.getFulingInfo(actor, roleId, posId)

	local addExp = 0
	for i=1, count do
		local uid = LDataPack.readUint64(packet)
		local id = LActor.getItemIdByUid(actor, uid)
		if ReincarnateEquip[id] and LActor.costItemByUid(actor, uid, 1, "fulingsmelt") then addExp = addExp + (ReincarnateEquip[id].exp or 0) end
	end

	if addExp > 0 then
		local level, exp = onAddExp(posId, level, exp + addExp)
		LActor.setFulingInfo(actor, roleId, posId, level, exp)

		confirmExp(actor, roleId, posId, level, exp)

		updateAttr(actor, roleId)
	end
end

local function onCompose(actor, itemId, roleId)
	local actorId = LActor.getActorId(actor)

	local conf = ReincarnateEquipCompose[itemId]
	if not conf then
		print("reincarnatesystem.onCompose:conf nil, itemId:"..tostring(itemId)..", actorId:"..tostring(actorId))
		return false
	end

	--roleId有值表示需要脱下玩家身上的装备用于合成，会造成战力下降
	if 0 <= roleId then
		local role = LActor.getRole(actor, roleId)
		if not role then print("reincarnatesystem.onCompose:role nil, roleId:"..tostring(roleId)..", actorId:"..tostring(actorId)) return false end

		--检测有没有装备
		local index = nil
		for pos = EquipSlotType_Hats, EquipSlotType_Shield do
			local id = LActor.getEquipId(role, pos)
			if id == conf.material.id then index = pos break end
		end

		if not index then
			print("reincarnatesystem.onCompose:not equip, itemId:"..tostring(conf.material.id)..", actorId:"..tostring(actorId))
			return false
		end

		--脱装备
		LActor.takeOutEquip(actor, roleId, index)
	end

	if conf.material.count > LActor.getItemCount(actor, conf.material.id) then
		print("reincarnatesystem.onCompose:not enough, itemId:"..tostring(conf.material.id)..", actorId:"..tostring(actorId))
		return false
	end

	LActor.costItem(actor, conf.material.id, conf.material.count, "reincarnatecomposeC")

	LActor.giveItem(actor, itemId, 1, "reincarnatecomposeG")

	return true
end

local function onEquipItem(actor, roleId, slot)
	if EquipSlotType_Hats <= slot and EquipSlotType_Shield >= slot then updateAttr(actor, roleId) initSuitAttr(actor, roleId) end
end

local function onInit(actor)
	for i=0, LActor.getRoleCount(actor) - 1 do
		updateAttr(actor, i)
		initSuitAttr(actor, i)
	end
end

local function onReqCompose(actor, packet)
	local itemId = LDataPack.readInt(packet)
	local roleId = LDataPack.readShort(packet)
	local ret = onCompose(actor, itemId, roleId)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Reincarnate, Protocol.sReincarnateCMD_EquipCompose)
	LDataPack.writeByte(npack, ret and 1 or 0)
	LDataPack.flush(npack)
end

local function initGlobalData()
	actorevent.reg(aeAddEquiment, onEquipItem)
	actorevent.reg(aeInit, onInit)

	netmsgdispatcher.reg(Protocol.CMD_Equip, Protocol.cEquipCmd_ReqFulingSmelt, onReqFulingSmelt)
	netmsgdispatcher.reg(Protocol.CMD_Reincarnate, Protocol.cReincarnateCMD_EquipCompose, onReqCompose)
end

table.insert(InitFnTable, initGlobalData)


local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.reincarnatesystem = function(actor, args)
    --[[
	local roleId = tonumber(args[1])
	local posId = tonumber(args[2])

	local level, exp = LActor.getFulingInfo(actor, roleId, posId)


	local totalLevel, totalExp = onAddExp(posId, level, exp + tonumber(args[3]))
	LActor.setFulingInfo(actor, roleId, posId, totalLevel, totalExp)
	]]

	onCompose(actor, tonumber(args[1]), tonumber(args[2]))
end
