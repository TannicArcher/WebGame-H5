module("zhizunequipsystem", package.seeall)

local openLevel = 5000

function sendInfo(actor, roleId, posId, level)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Equip, Protocol.sEquipCmd_ReqZhiZunLevelUp)
	LDataPack.writeShort(npack, roleId)
	LDataPack.writeShort(npack, posId)
    LDataPack.writeShort(npack, level)
	LDataPack.flush(npack)
end

--检测开启等级
function checkOpenLevel(actor)
	local level = LActor.getZhuanShengLevel(actor) * 1000
	level = level + LActor.getLevel(actor)
	if level < openLevel then return false end

	return true
end

local function updateAttr(actor, roleId)
	local actorId = LActor.getActorId(actor)
	local role = LActor.getRole(actor, roleId)
	if not role then return end
	local attr = LActor.getZhiZunAttr(actor, roleId)
	if not attr then return end
	attr:Reset()

	local exAttr = LActor.getZhiZunExAttr(actor, roleId)
	if not exAttr then return end
	exAttr:Reset()

	local power = 0
	local skillList = {}
	for index = 1, #ForgeIndexConfig do
		--判断该部位有没有装备
		local pos = ForgeIndexConfig[index].posId
		local itemId = LActor.getEquipId(role, pos)
		local level = LActor.getSoulLevel(actor, roleId, pos)
		if 0 ~= itemId and ZhiZunEquipLevel[pos] and ZhiZunEquipLevel[pos][level] then
			local conf = ZhiZunEquipLevel[pos][level]
			local soulLinkLevel = conf.soulLinkLevel or 0
			--至尊属性
			for _, v in pairs(conf.attrs or {}) do attr:Add(v.type, v.value) end
			for _, v in pairs(conf.ex_attrs or {}) do exAttr:Add(v.type, v.value) end
			power = power + (conf.ex_power or 0)

			if conf.skillId then table.insert(skillList, conf.skillId) end

			--灵魂锁链属性
			conf = ZhiZunLinkLevel[pos]
			for posId, cfg in pairs(conf or {}) do
				local itemId = LActor.getEquipId(role, posId)
				if 0 ~= itemId then
					--取得两个装备的最小灵魂锁链等级
					local soulLevel = LActor.getSoulLevel(actor, roleId, posId)
					local mixLevel = math.min(soulLevel, level)

					if cfg[mixLevel] then
						for _, v in pairs(cfg[mixLevel].attrs or {}) do attr:Add(v.type, v.value) end
						for _, v in pairs(cfg[mixLevel].exAttrs or {}) do exAttr:Add(v.type, v.value) end
						power = power + (cfg[mixLevel].ex_power or 0)
					end
				end
			end
		end
	end

	--学习技能
	for _, id in pairs(skillList or {}) do
		LActor.DelPassiveSkillById(role, id/1000)
		LActor.AddPassiveSkill(role, id)
	end

	attr:SetExtraPower(power)
	LActor.reCalcAttr(role)
	LActor.reCalcExAttr(role)
end

local function onLevelUp(actor, packet)
	local roleId = LDataPack.readShort(packet)
	local posId = LDataPack.readShort(packet)
	local actorId = LActor.getActorId(actor)

	local role = LActor.getRole(actor, roleId)
	if not role then print("zhizunequipsystem.onLevelUp:role nil, roleId:"..tostring(roleId)..", actorId:"..tostring(actorId)) return end

	--检测等级
	if false == checkOpenLevel(actor) then print("zhizunequipsystem.onLevelUp: level limit, actorId:"..tostring(actorId)) return end

	local isFind = false
	for k, v in pairs(ForgeIndexConfig or {}) do
		if v.posId == posId then isFind = true break end
	end

	--做个部位判断
	if not isFind then
		print("zhizunequipsystem.onLevelUp:posId error, posId:"..tostring(posId)..", actorId:"..tostring(actorId))
		return
	end

	--该部位没有装备则不能升级
	local itemId = LActor.getEquipId(role, posId)
	if 0 == itemId then
		print("zhizunequipsystem.onLevelUp:itemId 0, roleId:"..tostring(roleId)..", pos:"..tostring(posId)..", actorId:"..tostring(actorId))
		return
	end

	local level = LActor.getSoulLevel(actor, roleId, posId)

	local conf = nil
	if ZhiZunEquipLevel[posId] and ZhiZunEquipLevel[posId][level+1] then conf = ZhiZunEquipLevel[posId][level+1] end

	if not conf then
		print("zhizunequipsystem.onLevelUp:conf nil, pos:"..tostring(posId)..", level:"..tostring(level+1)..", actorId:"..tostring(actorId))
		return
	end

	if conf.materialInfo then
		if conf.materialInfo.count > LActor.getItemCount(actor, conf.materialInfo.id) then
			print("zhizunequipsystem.onLevelUp:not enough, itemId:"..tostring(conf.materialInfo.id)..", actorId:"..tostring(actorId))
			return
		end

		LActor.costItem(actor, conf.materialInfo.id, conf.materialInfo.count, "zhizunlevelup")
		LActor.setSoulLevel(actor, roleId, posId, level+1)

		sendInfo(actor, roleId, posId, level+1)
		updateAttr(actor, roleId)
	end
end

local function onInit(actor)
	for i=0, LActor.getRoleCount(actor) - 1 do updateAttr(actor, i) end
end

local function onEquipItem(actor, roleId, slot)
	if ForgeIndexConfig[slot] then updateAttr(actor, roleId) end
end

local function initGlobalData()
	actorevent.reg(aeInit, onInit)
	actorevent.reg(aeAddEquiment, onEquipItem)

	netmsgdispatcher.reg(Protocol.CMD_Equip, Protocol.cEquipCmd_ReqZhiZunLevelUp, onLevelUp)
end

table.insert(InitFnTable, initGlobalData)


local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.reincarnatesoulsystem = function(actor, args)

end
