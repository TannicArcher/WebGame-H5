module("godwingsystem", package.seeall)

--[[
data define:

    godWingData = {
        [roleId] = {
				[slot] = level   slot为部位
        }
    }
--]]

local MaxSlot = 4

local function getStaticData(actor)
    local var = LActor.getStaticVar(actor)
    if nil == var.godWingData then var.godWingData = {} end

    return var.godWingData
end

--获取角色神羽信息
local function getRoleData(actor, roleId)
	local var = getStaticData(actor)
	if not var[roleId] then var[roleId] = {} end

	return var[roleId]
end

--是否能开启神羽
local function checkOpenDay()
	local openDay = System.getOpenServerDay() + 1
	if openDay < WingCommonConfig.openDay then return false end

	return true
end

--根据阶级和部位获取道具id
local function getItemId(level, slot)
	if GodWingLevelConfig[level] and GodWingLevelConfig[level][slot] then
		return GodWingLevelConfig[level][slot].itemId
	end

	return 0
end

--获取身上最低的阶级，用于套装属性
local function getMinLevel(actor, roleId)
	local data = getRoleData(actor, roleId)

	local list = {}
	for i=1, MaxSlot do table.insert(list, data[i] or 0) end

	table.sort(list)

	return list[1] or 0
end

--获取身上最低的阶级对应的套装加成比
function getPrecent(actor, roleId)
	local level = getMinLevel(actor, roleId)
	if GodWingSuitConfig[level] then return GodWingSuitConfig[level].precent end

	return 0
end

--套装属性加成
local function addSuitAttr(actor, roleId, attr)
	local minLevel = getMinLevel(actor, roleId)
	if GodWingSuitConfig[minLevel] then
		local conf = GodWingSuitConfig[minLevel]
		if attr then
			for _, v in pairs(conf.exattr or {}) do attr:Add(v.type, v.value) end
		end
	end
end

local function updateAttr(actor, roleId, isLogin)
	local role = LActor.getRole(actor, roleId)
	if not role then return end
	local attr = LActor.GetGodWingAttrs(actor, roleId)
	if not attr then return end
	attr:Reset()

	local exattr = LActor.GetGodWingExAttrs(actor, roleId)
	if not exattr then return end
	exattr:Reset()

	local precent = getPrecent(actor, roleId)

	local data = getRoleData(actor, roleId)
	local power = 0
	for i=1, MaxSlot do
		if data[i] then
			local itemId = getItemId(data[i], i)
			local conf = GodWingItemConfig[itemId]
			if conf then
				for _, v in pairs(conf.attr or {}) do attr:Add(v.type, v.value+math.floor(v.value*precent/10000)) end
				for _, v in pairs(conf.exattr or {}) do exattr:Add(v.type, v.value) end
				power = power + conf.exPower
			end
		end
	end
	attr:SetExtraPower(power)

	--套装属性加成
	addSuitAttr(actor, roleId, exattr)

	--神翼在登陆时已加上神羽附加的属性，所以只需要在其它情况上再重算翅膀属性
	if not isLogin then
		wingsystem.updateAttr(actor, roleId)
		LActor.reCalcExAttr(role)
	end
end

local function sendInfo(actor, roleId)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sWingCmd_GodWingData)
	local data = getRoleData(actor, roleId)
	LDataPack.writeShort(npack, roleId)

	--先保存当前位置，后面再插入数据
	local oldPos = LDataPack.getPosition(npack)
	LDataPack.writeShort(npack, 0)

	local count = 0
	for i=1, MaxSlot do
		if data[i] then
			LDataPack.writeShort(npack, i)
			LDataPack.writeInt(npack, data[i] or 0)
			count = count + 1
		end
	end

	local newPos = LDataPack.getPosition(npack)

    --往前面插入数据
	LDataPack.setPosition(npack, oldPos)
	LDataPack.writeShort(npack, count)
	LDataPack.setPosition(npack, newPos)

	LDataPack.flush(npack)
end

--判断身上有没有该装备
local function checkEquipExist(actor, roleId, conf)
	local data = getRoleData(actor, roleId)
	if conf.level == (data[conf.slot] or 0) then return true end

	return false
end

local function equipItem(actor, roleId, itemId)
	local actorId = LActor.getActorId(actor)

	if roleId >= MAX_ROLE then print("godwingsystem.equipItem:roleId illegal, actorId:"..tostring(actorId)) return false end

	--开服天数判断
	if false == checkOpenDay() then print("godwingsystem.equipItem:checkOpenDay false, actorId:"..tostring(actorId)) return false end

	--是否开启神翼了
	local level, exp, status, ctime = LActor.getWingInfo(actor, roleId)
	if not status or 0 == status then print("godwingsystem.equipItem:wing not activate, actorId:"..tostring(actorId)) return false end

	--是否有该物品
	if 0 >= LActor.getItemCount(actor, itemId) then
		print("godwingsystem.equipItem:count not enough, sourceId:"..tostring(itemId)..", actorId:"..tostring(actorId))
		return false
	end

	local conf = GodWingItemConfig[itemId]
	if not conf then
		print("godwingsystem.equipItem:conf nil, itemId:"..tostring(itemId)..", actorId:"..tostring(actorId))
		return false
	end

	--阶级判断
	if level + 1 < conf.level then
		print("godwingsystem.equipItem:level limit, itemId:"..tostring(itemId)..", actorId:"..tostring(actorId))
		return false
	end

	local data = getRoleData(actor, roleId)

	--如果有数据，表明身上有穿装备，替换下来到背包
	if data[conf.slot] then
		local equidId = getItemId(data[conf.slot], conf.slot)
		LActor.giveItem(actor, equidId, 1, "godwing unequip")
	end

	LActor.costItem(actor, itemId, 1, "godwing equip")

	data[conf.slot] = conf.level

	print("godwingsystem.equipItem:equip, itemId:"..tostring(itemId)..", actorId:"..tostring(actorId))

	sendInfo(actor, roleId)

	updateAttr(actor, roleId, false)

	return true
end

local function godWingEquip(actor, packet)
	local roleId = LDataPack.readShort(packet)
	local itemId = LDataPack.readInt(packet)

	local isEquip = equipItem(actor, roleId, itemId)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sWingCmd_GodWingEquip)
	LDataPack.writeByte(npack, isEquip and 1 or 0)

	LDataPack.flush(npack)
end

local function godWingCompose(actor, packet)
	local type = LDataPack.readShort(packet)
	local itemId = LDataPack.readInt(packet)
	local actorId = LActor.getActorId(actor)

	local roleId = 0
	if 1 == type then roleId = LDataPack.readShort(packet) end

	if roleId >= MAX_ROLE then print("godwingsystem.godWingCompose:roleId illegal, actorId:"..tostring(actorId)) return end

	--开服天数判断
	if false == checkOpenDay() then print("godwingsystem.godWingCompose:checkOpenDay false, actorId:"..tostring(actorId)) return end

	local conf = GodWingItemConfig[itemId]
	if not conf then
		print("godwingsystem.godWingCompose:conf nil, itemId:"..tostring(itemId)..", actorId:"..tostring(actorId))
		return
	end

	--快速合成需要穿装备，所以要阶级判断
	if 1 == type then
		--是否开启神翼了
		local level, exp, status, ctime = LActor.getWingInfo(actor, roleId)
		if not status or 0 == status then print("godwingsystem.godWingCompose:wing not activate, actorId:"..tostring(actorId)) return end

		if level + 1 < conf.level then
			print("godwingsystem.godWingCompose:level limit, itemId:"..tostring(itemId)..", actorId:"..tostring(actorId))
			return
		end
	end

	local needCount = conf.composeItem.count
	local composeConf = nil

	--身上是否有合成的材料
	local isExist = false
	if 1 == type then
		composeConf = GodWingItemConfig[conf.composeItem.id]
		if composeConf then
			isExist = checkEquipExist(actor, roleId, composeConf)
			if isExist then needCount = needCount - 1 end
		end
	end

	--道具够不够
	if needCount > LActor.getItemCount(actor, conf.composeItem.id) then
		print("godwingsystem.godWingCompose:item not enough, itemId:"..tostring(conf.composeItem.id)..", actorId:"..tostring(actorId))
		return
	end

	if 0 < needCount then LActor.costItem(actor, conf.composeItem.id, needCount, "godwing composeC") end

	--普通合成需要给物品
	if 2 == type then LActor.giveItem(actor, itemId, 1, "godwing composeG") end

	if 1 == type then
		local data = getRoleData(actor, roleId)
		if data[conf.slot] then
			local equidId = getItemId(data[conf.slot], conf.slot)

			if not isExist then LActor.giveItem(actor, equidId, 1, "godwing unequip") end
		end

		data[conf.slot] = conf.level

		print("godwingsystem.godWingCompose:equip, itemId:"..tostring(itemId)..", actorId:"..tostring(actorId))

		sendInfo(actor, roleId)

		updateAttr(actor, roleId, false)

		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sWingCmd_GodWingEquip)
		LDataPack.writeByte(npack, 1)

		LDataPack.flush(npack)
	end
end

local function godWingExchange(actor, packet)
	local sourceId = LDataPack.readInt(packet)
	local destId = LDataPack.readInt(packet)
	local actorId = LActor.getActorId(actor)

	if false == checkOpenDay() then
		print("godwingsystem.godWingExchange:checkOpenDay false, actorId:"..tostring(actorId))
		return
	end

	local sourceConf = GodWingItemConfig[sourceId]
	if not sourceConf then
		print("godwingsystem.godWingExchange:conf nil, sourceId:"..tostring(sourceId)..", actorId:"..tostring(actorId))
		return
	end

	local destConf = GodWingItemConfig[destId]
	if not sourceConf then
		print("godwingsystem.godWingExchange:conf nil, destId:"..tostring(destId)..", actorId:"..tostring(actorId))
		return
	end

	if 0 >= LActor.getItemCount(actor, sourceId) then
		print("godwingsystem.godWingExchange:count not enough, sourceId:"..tostring(sourceId)..", actorId:"..tostring(actorId))
		return
	end

	--阶级一样才能兑换
	if sourceConf.level ~= destConf.level then
		print("godwingsystem.godWingExchange:level not same, sourceId:"..tostring(sourceId)..", destId:"..tostring(destId)..", actorId:"..tostring(actorId))
		return
	end

	--钱够不够
	local curYuanBao = LActor.getCurrency(actor, NumericType_YuanBao)
	if (destConf.needMoney > curYuanBao) then
		print("godwingsystem.godWingExchange:money not enough, sourceId:"..tostring(sourceId)..", destId:"..tostring(destId)..", actorId:"..tostring(actorId))
		return
	end

	LActor.changeYuanBao(actor, -destConf.needMoney, "godwing exchange")

	LActor.costItem(actor, sourceId, 1, "godwing exchangeS")

	LActor.giveItem(actor, destId, 1, "godwing exchangeD")
end

local function onLogin(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0, count-1 do
		sendInfo(actor, roleId)
	end
end

local function onInit(actor)
	for i=0,LActor.getRoleCount(actor) -1 do
		updateAttr(actor, i, true)
	end
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_Wing, Protocol.cWingCmd_GodWingEquip, godWingEquip)
netmsgdispatcher.reg(Protocol.CMD_Wing, Protocol.cWingCmd_GodWingCompose, godWingCompose)
netmsgdispatcher.reg(Protocol.CMD_Wing, Protocol.cWingCmd_GodWingExchange, godWingExchange)

function test(actor, args)
	if 1 == tonumber(args[1]) then
		equipItem(actor, tonumber(args[2]), tonumber(args[3]))
	elseif 2 == tonumber(args[1]) then
		local count = LActor.getRoleCount(actor)
		for roleId=0, count-1 do
			local data = getRoleData(actor, roleId)
			for i=1, MaxSlot do
				data[i] = tonumber(args[2])
			end

			sendInfo(actor, roleId)
			updateAttr(actor, roleId, false)
		end
	elseif 3 == tonumber(args[1]) then
		local data = getRoleData(actor, tonumber(args[2]))
		data = nil
	elseif 4 == tonumber(args[1]) then
		local type = tonumber(args[2])
		local itemId = tonumber(args[3])
		local actorId = LActor.getActorId(actor)
		local roleId = tonumber(args[4])
	end
end
