module("equippoint", package.seeall)



max_probability = 10000



local function getData(actor)
	local var = LActor.getStaticVar(actor)

	if var == nil then 
		return nil
	end
	if var.equippoint == nil then 
		var.equippoint = {}
	end
	return var.equippoint
end





local function getEquipPointData(actor,role_id,equip_point_id)
	local var = getData(actor)
	if var == nil then 
		return nil
	end

	if var[role_id] == nil then 
		var[role_id] = {}
	end
	if var[role_id][equip_point_id] == nil then 
		var[role_id][equip_point_id] = {}
	end
	if var[role_id][equip_point_id].rank == nil then 
		var[role_id][equip_point_id].rank = 0
	end
	if var[role_id][equip_point_id].growUpId == nil then 
		var[role_id][equip_point_id].growUpId = 0
	end
	return var[role_id][equip_point_id]
end


local function isActivation(actor,role_id,equip_point_id)
	if role_id == nil then 
		return false
	end

	if equip_point_id == nil then
		return false
	end
	local conf = EquipPointBasicConfig[equip_point_id] 
	if conf == nil then 
		print("not config " .. equip_point_id)
		return false
	end
	if LActor.getRole(actor,role_id) == nil then 
		print("not role " .. role_id)
		return false
	end
	local var = getEquipPointData(actor,role_id,equip_point_id)
	return var.growUpId ~= 0
end

local function  packEquipPointData(actor, role_id, pack)
	if not pack then print("no pack") return end
	
	local var = getData(actor)
	local len = 0
	for j, jv in pairs(EquipPointBasicConfig) do
		len = len + 1
	end
	LDataPack.writeShort(pack, len)
	for i, v in pairs(EquipPointBasicConfig) do
		local var = getEquipPointData(actor, role_id, i)
		LDataPack.writeInt(pack, i)
		LDataPack.writeShort(pack, var.rank)
		LDataPack.writeInt(pack, var.growUpId)
	end
end
_G.packEquipPointData = packEquipPointData


local function updataAttrs(actor,role_id)

	local attrs = LActor.getEquipPointAttrs(actor,role_id)
	if attrs == nil then 
		return
	end
	attrs:Reset()
	for i,v in pairs(EquipPointBasicConfig) do 
		if isActivation(actor,role_id,i) then
			local var = getEquipPointData(actor,role_id,i)
			if var ~= nil then 
				local growUpId = (var.rank * EquipPointConstConfig.rankGrowUp) + var.growUpId
				local conf = EquipPointGrowUpConfig[i][growUpId]
				if conf ~= nil then
					for j,jv in pairs(conf.attrs) do 
						attrs:Add(jv.type,jv.value)
					end
				else 
					print("not config " .. i .. "  " .. growUpId)
				end
			end
		end
	end
	LActor.reCalcRoleAttr(actor, role_id)
end



local function growUp(actor,role_id,equip_point_id)
	if role_id == nil then 
		return false
	end

	if equip_point_id == nil then
		return false
	end
--	print("growUp " .. role_id .. " " .. equip_point_id)
	local conf = EquipPointBasicConfig[equip_point_id] 
	if conf == nil then 
		print("basic not config " .. equip_point_id)
		return false
	end
	if LActor.getRole(actor,role_id) == nil then 
		print("not role " .. role_id)
		return false
	end
	local var = getEquipPointData(actor,role_id,equip_point_id)
	local growUpId = (var.rank * EquipPointConstConfig.rankGrowUp) + var.growUpId
	local conf = EquipPointGrowUpConfig[equip_point_id][growUpId]
	if conf == nil then 
		print("not config" .. equip_point_id .. " " .. growUpId)
		return false
	end
	if not next(conf.growUpItem) then 
		print("full level")
		return false
	end
	local level = (LActor.getZhuanShengLevel(actor) * 1000) + LActor.getLevel(actor)

	if level < conf.needLevel then 
		print("need level " .. level .. " " .. conf.needLevel)
		return false
	end

	 if (LActor.getItemCount(actor,conf.growUpItem.id) < conf.growUpItem.count) then
        print("not item " .. equip_point_id .. " " .. growUpId)
        return
    end

    LActor.costItem(actor, conf.growUpItem.id, conf.growUpItem.count,log)

	
	local probability = System.rand(max_probability)
	if probability > conf.growUpProbability  then 
		System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
        "equip point grow up failure", var.rank .. " " .. var.growUpId, "" .. role_id, "" .. equip_point_id, "", "", "")
		return false
	end
	var.growUpId = var.growUpId + 1
	print("growUp ok " .. var.growUpId)
	updataAttrs(actor,role_id)
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
        "equip point grow up ok", var.rank .. " " .. var.growUpId, "" .. role_id, "" .. equip_point_id, "", "", "")
	return true

end

local function rankUp(actor,role_id,equip_point_id)
	if not isActivation(actor,role_id,equip_point_id) then 
		print("not isActivation " .. role_id  .. " " .. equip_point_id)
		return false
	end
	local var = getEquipPointData(actor,role_id,equip_point_id)
	local conf = EquipPointRankConfig[equip_point_id][var.rank] 
	if conf == nil then 
		print("not config " .. var.rank)
		return false
	end
	if not next(conf.rankUpItem) then 
		print("full rank")
		return false
	end

	 if (LActor.getItemCount(actor,conf.rankUpItem.id) < conf.rankUpItem.count) then
        print("not item")
        return
    end

    LActor.costItem(actor, conf.rankUpItem.id, conf.rankUpItem.count,log)

	local probability = System.rand(max_probability)
	if probability > conf.rankUpProbability  then 
		System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
        "equip point rank up failure", var.rank .. " " .. var.growUpId, "" .. role_id, "" .. equip_point_id, "", "", "")
		return false
	end
	var.rank = var.rank + 1
	print("rankUp ok")
	updataAttrs(actor,role_id)
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
        "equip point rank up ok", var.rank .. " " .. var.growUpId, "" .. role_id, "" .. equip_point_id, "", "", "")
	return true
end

local function resolve(actor)
	for i,v in pairs(EquipPointResolveConfig) do 
		local count = LActor.getItemCount(actor,i)
		if count ~= 0 then 
			LActor.costItem(actor, i, count,log)
			local add = {}
			for j = 1,#v.materials do 
				local it = v.materials[j]
				if add[it.id] == nil then 
					add[it.id] = {}
					add[it.id].id = it.id;
					add[it.id].type = it.type;
					add[it.id].count = 0
				end
				add[it.id].count = add[it.id].count + (it.count * count)
			end
			local items = {}
			for j,jv in pairs(add) do 
				table.insert(items,jv)
			end
			--print(utils.t2s(add))
			LActor.giveAwards(actor,items,"equip point resolve")
		end
	end
	return true

end

--net 

local function sendEquipPointData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_EquipPoint, Protocol.sEquipPoint_EquipPointData)
	if npack == nil then 
		return
	end
	local role_count = LActor.getRoleCount(actor) 
	LDataPack.writeShort(npack,role_count)
	local i = 0
	local len = 0
	for j,jv in pairs(EquipPointBasicConfig) do 
		len = len + 1
	end
	while (i < role_count) do 
		LDataPack.writeByte(npack,i)
		LDataPack.writeShort(npack,len)
		for j,jv in pairs(EquipPointBasicConfig) do 
			local var = getEquipPointData(actor,i,j)
			LDataPack.writeInt(npack,j)
			LDataPack.writeShort(npack,var.rank)
			LDataPack.writeInt(npack,var.growUpId)

--			print(i .. "  " .. j .. " " .. var.growUpId)
		end
		i = i + 1
	end
	LDataPack.flush(npack)
end

local function onActivation(actor,packet)
	local role_id = LDataPack.readByte(packet)
	local equip_point_id = LDataPack.readInt(packet)
	local ret = activationEquipPoint(actor,role_id,equip_point_id)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_EquipPoint, Protocol.sEquipPoint_Activation)
	if npack == nil then 
		return
	end
	LDataPack.writeByte(npack,ret)
	LDataPack.flush(npack)
	sendEquipPointData(actor)
end



local function onRankUp(actor,packet)
	local role_id = LDataPack.readByte(packet)
	local equip_point_id = LDataPack.readInt(packet)
	local ret = rankUp(actor,role_id,equip_point_id)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_EquipPoint, Protocol.sEquipPoint_RankUp)
	if npack == nil then 
		return
	end
	LDataPack.writeByte(npack,ret and 1 or 0)
	LDataPack.flush(npack)
	sendEquipPointData(actor)

end

local function onGrowUp(actor,packet)
	local role_id = LDataPack.readByte(packet)
	local equip_point_id = LDataPack.readInt(packet)
	local ret = growUp(actor,role_id,equip_point_id)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_EquipPoint, Protocol.sEquipPoint_GrowUp)
	if npack == nil then 
		return
	end
	LDataPack.writeByte(npack,ret and 1 or 0)
	LDataPack.flush(npack)
	sendEquipPointData(actor)

end

local function onResolve(actor,packet)
	resolve(actor)
end



--net end

local function onInit(actor)
	local role_count = LActor.getRoleCount(actor) 
	local i = 0
	while (i < role_count) do 
		updataAttrs(actor,i)
		i = i + 1
	end
end

local function onLogin(actor)
	sendEquipPointData(actor)
end
local function onCreateRole(actor,role_id)
	updataAttrs(actor,role_id)
	sendEquipPointData(actor)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)
actorevent.reg(aeCreateRole,onCreateRole)
netmsgdispatcher.reg(Protocol.CMD_EquipPoint, Protocol.cEquipPoint_RankUp, onRankUp)
netmsgdispatcher.reg(Protocol.CMD_EquipPoint, Protocol.cEquipPoint_GrowUp, onGrowUp)
netmsgdispatcher.reg(Protocol.CMD_EquipPoint, Protocol.cEquipPoint_Resolve, onResolve)
