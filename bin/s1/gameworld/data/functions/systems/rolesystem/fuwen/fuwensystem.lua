--v1.0 符文系统
--v2.0 战纹系统
module("fuwensystem", package.seeall)

local ItemConfig = ItemConfig

local RuneOtherConfig = RuneOtherConfig
local RuneConverConfig = RuneConverConfig
local RuneBaseConfig = RuneBaseConfig
local RuneLockPosConfig = RuneLockPosConfig

local MaxRuneLevel = 99		--最大战纹等级

local function actor_log(actor, str)
	if not actor or not str then return end
	local aid = LActor.getActorId(actor)
	print("fuwen aid:" .. aid .. " log:" .. str)
end

-- local function 

local function getStaticData(actor)
	local var = LActor.getStaticVar(actor) 
	if var == nil then return nil end
	if var.fuwenData == nil then
		var.fuwenData            = {}
	end

	return var.fuwenData
end

local function isOpen(actor)
	local level = LActor.getLevel(actor)
	if (level < RuneOtherConfig.zsLevel) then
		return false
	end
	return true
end

--通知删除某个位置的符文
local function noticeDelFuwen(actor, roleId, posId)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_FuWen, Protocol.sFuWenCmd_DelFuwen)
	if not pack then return end

	LDataPack.writeInt(pack, roleId)
	LDataPack.writeInt(pack, posId)

	LDataPack.flush(pack)
end

local function CheckEquipFuwen(actor,roleId,posId,itemId)
	if not ItemConfig[itemId] then
		LActor.log(actor,"fuwencommon.CheckEquipFuwen","conf error",itemId)
		return false
	end
	local FuWenuIdInfo = LActor.getFuWenuIdInfo(actor,roleId)
	if not FuWenuIdInfo then
		LActor.log(actor,"fuwencommon.CheckEquipFuwen","data error",posId)
		return false
	end

	local dstType = ItemConfig[itemId].subType
	local srcType = nil
	for i = 1, #FuWenuIdInfo do
		local id = FuWenuIdInfo[i]
		srcType = ItemConfig[id] and ItemConfig[id].subType
		if srcType and srcType == dstType and posId ~= i then
			return false
		end
	end

	--合成的符文，不能和材料符文一起镶嵌
	local fuwenId = {}	--已镶嵌的符文tmp 
	for i, id in pairs(FuWenuIdInfo) do
		if ItemConfig[id] then
			fuwenId[i] = math.floor(id / 100) * 100 + 1
		end
	end

	local itemIdTmp = math.floor(itemId / 100) * 100 + 1
	local replace	--是否替换
	if RuneComposeConfig[itemIdTmp] then
		local hasMaterial = {}
		for _, v in pairs(RuneComposeConfig[itemIdTmp].checkMaterial) do
			for i, id in pairs(fuwenId) do
				if v == id then
					table.insert(hasMaterial, {i, id})
					if i == posId then
						replace = i
					end
				end
			end
		end
		if #hasMaterial > 0 and not replace then
			--有镶嵌材料的时候，只能点替换
			return false
		elseif #hasMaterial > 1 and replace then
			--多于一个镶嵌材料时， 需要把其他的材料卸下来
			for _, v in pairs(hasMaterial) do
				if v[1] ~= replace then
					LActor.SetFuwen(actor, roleId, v[1], 0)
					noticeDelFuwen(actor, roleId, v[1])
				end
			end
		end
	else
		local composeIds = {}	--该材料对应的合成id
		for i, v in pairs(RuneComposeConfig) do
			for _, materialId in pairs(v.checkMaterial) do
				if itemIdTmp == materialId then
					table.insert(composeIds, i)
					break
				end
			end
		end

		for _, composeId in pairs(composeIds) do
			--是某个战纹的材料
			for i, id in pairs(fuwenId) do
				if id == composeId then
					--有镶嵌合成符文，材料就只能镶嵌在这个位置
					if i ~= posId then return false end
					break
				end
			end
		end
	end
	
	return true
end

local function EquipFuWen(actor,roleId,posId,uId,itemId)
	local conf = RuneBaseConfig
	if not conf[itemId] then
		print("fuwensystem.EquipFuWen itemId:"..itemId..", is not config")
		return false
	end
	if not CheckEquipFuwen(actor,roleId,posId,itemId) then
		LActor.sendTipmsg(actor, LAN.FuWen.fw004, ttScreenCenter)
		return false
	end
	if not RuneLockPosConfig[posId] then
		print("fuwensystem.EquipFuWen posId:"..posId..", is not RuneLockPosConfig")
		return false
	end
	if challengefbsystem.getChallengeId(actor) < RuneLockPosConfig[posId].lockLv then
		print("fuwensystem.EquipFuWen aid:"..LActor.getActorId(actor)..",roleId:"..roleId..", is not unlock")
		return false
	end
	LActor.SetFuwen(actor,roleId,posId,uId)

	updateAttr(actor,roleId)
	return true,index,fuwenlevel
end

local function OnEquipFuwen(actor,packet)
	local roleId = LDataPack.readShort(packet)
	local posId    = LDataPack.readShort(packet)
	local uId    = LDataPack.readInt64(packet)
	if not isOpen(actor) then
		 LActor.sendTipmsg(actor, LAN.FuWen.fw007, ttScreenCenter)
		return
	end
	if posId < 0 or posId >= RuneOtherConfig.maxEquip then
		LActor.log(actor,"fuwensystem.OnEquipFuwen",posId)
		return
	end
	local itemId = LActor.getItemIdByUid(actor,uId)
	if 0 == itemId then
		LActor.log(actor,"fuwencommon.EquipFuWen","error1",itemId)
		return false
	end
	local ret = EquipFuWen(actor,roleId,posId,uId,itemId)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_FuWen, Protocol.sFuWenCmd_EquipFuwen)
	LDataPack.writeShort(npack,ret and 1 or 0)
	if ret then
		LDataPack.writeShort(npack,roleId)
		LDataPack.writeShort(npack,posId)
		LDataPack.writeInt(npack,itemId)
	end
	LDataPack.flush(npack)
end

local function LevelUp(actor,roleId,posId)
	local FuWenuIdInfo = LActor.getFuWenuIdInfo(actor,roleId)
	--未装备符文
	local itemId = FuWenuIdInfo[posId]
	if not itemId or itemId == 0 then
		LActor.sendTipmsg(actor, LAN.FuWen.fw005, ttScreenCenter)
		return false
	end
	local conf = RuneBaseConfig[itemId]
	if not conf then return false end
	local nextItemId = itemId + 1
	local nextconf = RuneBaseConfig[nextItemId]
	--满级了
	if not nextconf then
		LActor.sendTipmsg(actor, LAN.FuWen.fw006, ttScreenCenter)
		return false
	end
	local expend = conf.expend
	if LActor.getCurrency(actor, NumericType_Shatter) < expend then
		return false
	end
	LActor.changeCurrency(actor, NumericType_Shatter, -expend, "upFWLv")
	--升级
	LActor.FuwenLevelup(actor,roleId,posId,nextItemId)
	updateAttr(actor,roleId)

	--成就
	actorevent.onEvent(actor, aeFuWenLevel, nextItemId)
	return true,nextItemId
end

local function OnLevelUpFuwen(actor,packet)
	local roleId = LDataPack.readShort(packet)
	local posId    = LDataPack.readShort(packet)
	if not isOpen(actor) then
		LActor.sendTipmsg(actor, LAN.FuWen.fw007, ttScreenCenter)
		return
	end
	if posId < 0 or posId > RuneOtherConfig.maxEquip then
		LActor.log(actor,"fuwensystem.OnLevelUpFuwen",posId)
		return
	end
	local ret,nextItemId = LevelUp(actor,roleId,posId)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_FuWen, Protocol.sFuWenCmd_LevelUpFuwen)
	LDataPack.writeByte(npack,ret and 1 or 0)
	if ret then
		LDataPack.writeShort(npack,roleId)
		LDataPack.writeShort(npack,posId)
		LDataPack.writeInt(npack,nextItemId)
	end
	LDataPack.flush(npack)
end

--compose合成的时候，分解材料不给战纹碎片
local function DecomposeFuwen(actor, count, list, compose)
	if (not count or not list) then
		LActor.log(actor,"fuwensystem.DecomposeFuwen","1")
		return false
	end

	local conf = nil
	local gain = 0
	local uId = 0
	local itemId = 0
	local itemDataTb = nil
	for i =1 ,count do
	 	itemId = list[i]
	 	conf = RuneBaseConfig[itemId]

		if conf and conf.gain then
			if LActor.getItemCount(actor, itemId) >= 1 then
				LActor.costItem(actor, itemId, 1, "decomposeFuwen")
				LActor.changeCurrency(actor, NumericType_Shatter, conf.gain, "decomposeFuwen")
				if conf.chip and not compose then
					LActor.changeCurrency(actor, NumericType_SpeShatter, conf.chip, "decomposeFuwen")
				end
				if conf.goldCount and conf.goldCount > 0 then
					LActor.giveItem(actor, RuneOtherConfig.goldItemId, conf.goldCount, "decomposeFuwen")
				end

				gain = gain + conf.gain
			end
		end
	end
	return true,gain
end

local function OnDecomposeFuwen(actor,packet)
	local count = LDataPack.readInt(packet)
	if count < 0 then
		LActor.log(actor,"fuwensystem.OnDecomposeFuwen")
		return
	end
	local list = {}
	for i =1, count do
		list[i] = LDataPack.readInt(packet)
	end
	if not isOpen(actor) then
		LActor.sendTipmsg(actor, LAN.FuWen.fw007, ttScreenCenter)
		return
	end
	local ret,gain = DecomposeFuwen(actor,count,list)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_FuWen, Protocol.sFuWenCmd_DecomPoseFuwen)
	LDataPack.writeByte(npack,ret and 1 or 0)
	LDataPack.writeInt(npack,gain)
	LDataPack.flush(npack)
end

local function OnConverFuwen(actor,packet)
	local itemId = LDataPack.readInt(packet)

	if not isOpen(actor) then
		LActor.sendTipmsg(actor, LAN.FuWen.fw007, ttScreenCenter)
		return
	end
	local conf = RuneConverConfig[itemId]
	if not conf then return end

	if challengefbsystem.getChallengeId(actor) < conf.checkpoint then return end

	local conversion = conf.conversion

	if LActor.getCurrency(actor, NumericType_SpeShatter) < conversion then
		return
	end
	LActor.changeCurrency(actor, NumericType_SpeShatter, -conversion, "converFuWen")
	LActor.giveAward(actor, AwardType_Item, itemId, 1, "byConver")
	
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_FuWen, Protocol.sFuWenCmd_ConverFuwen)
	LDataPack.writeByte(npack,1)
	LDataPack.flush(npack)
end

function updateAttributes(actor, sysType)
	local roleCount = LActor.getRoleCount(actor)
	for roleId = 0,roleCount-1 do
		local FuWenuIdInfo = LActor.getFuWenuIdInfo(actor,roleId)
		if FuWenuIdInfo then
			local specialattrList = {}
			for posId,itemId in pairs(FuWenuIdInfo) do
				conf = RuneBaseConfig[itemId]
				if conf then
					local specialattr = conf.specialAttr
					if specialattr then
						for _,tb in pairs(specialattr) do
							specialattrList[tb.type] = specialattrList[tb.type] or 0
							specialattrList[tb.type] = specialattrList[tb.type] + tb.value
						end
					end
				end
			end		
			for type,value in pairs(specialattrList) do
				specialattribute.add(actor,type,value,sysType)
			end
		end
	end	
end

local function addFuWenAttr(actor,roleId)
	local FuWenuIdInfo = LActor.getFuWenuIdInfo(actor,roleId)
	if not FuWenuIdInfo then return end

	local attrList = {}
	local exattrList = {}
	local totalpower = 0

	local conf = nil
	local attr = nil
	local equipAttr = nil
	local exAttr = nil
	for posId,itemId in pairs(FuWenuIdInfo) do
		conf = RuneBaseConfig[itemId]
		if conf then
			attr = conf.attr
			exAttr = conf.exAttr
			equipAttr = conf.equipAttr
			if attr then
				for _,tb in pairs(attr) do
					attrList[tb.type] = attrList[tb.type] or 0
					attrList[tb.type] = attrList[tb.type] + tb.value
				end
			end
			if exAttr then
				for _,tb in pairs(exAttr) do
					exattrList[tb.type] = exattrList[tb.type] or 0
					exattrList[tb.type] = exattrList[tb.type] + tb.value
				end
			end
			if equipAttr then
				for _,tb in pairs(equipAttr) do						
					local tEquipAttr = LActor.getEquipAttr(actor, roleId, tb.type)
					for i=Attribute.atHpMax,Attribute.atTough do
						if tEquipAttr[i] ~= 0 then
							attrList[i] = attrList[i] or 0
							attrList[i] = attrList[i] + math.floor(tEquipAttr[i] * tb.value/100)
						end
					end
				end
			end
			if conf.power and power ~= 0 then
				totalpower = totalpower + conf.power
			end
		end
	end		
	--汇总后统一加
	for type,value in pairs(attrList) do
		LActor.addFuWenAttr(actor, roleId, type, value)
	end
	for type,value in pairs(exattrList) do
		LActor.addFuWenExattr(actor, roleId, type, value)
	end
	
	local attr = LActor.getFuWenAttr(actor,roleId)
	attr:SetExtraPower(totalpower)

	specialattribute.updateAttribute(actor)
end

function updateAttr(actor,roleId)
	LActor.clearFuWenAttr(actor,roleId)

	addFuWenAttr(actor,roleId)

	LActor.reCalcRoleAttr(actor, roleId)

	LActor.CalcExAttr(actor,roleId)
end

local function initFuWen(actor)
	local roleCount = LActor.getRoleCount(actor)

	for roleId = 0,roleCount-1 do
		updateAttr(actor,roleId)
	end
end

local function onEquipItem(actor, roleId)
	updateAttr(actor, roleId)
end

--合成符文
local function composeFuwen(actor, packet)
	local itemId = LDataPack.readInt(packet)

	local conf = RuneComposeConfig[itemId]
	if not conf then return end

	if LActor.getItemCount(actor, RuneOtherConfig.goldItemId) < conf.count then
		actor_log(actor, "composeFuwen not has item "..itemId.." "..RuneOtherConfig.goldItemId)
		return
	end

	local costItem = {}
	for _, id in pairs(conf.material) do
		local hasItem
		for i = 1, MaxRuneLevel do
			local nowId = id + i - 1
			if not RuneBaseConfig[nowId] then
				break
			end

			if LActor.getItemCount(actor, nowId) >= 1 then
				table.insert(costItem, nowId)
				hasItem = 1
				break
			end
		end

		if not hasItem then
			actor_log(actor, "composeFuwen not has item "..itemId.." "..id)
			return
		end
	end

	LActor.costItem(actor, RuneOtherConfig.goldItemId, conf.count, "composeFuwen")
	DecomposeFuwen(actor, #costItem, costItem, true)

	LActor.giveItem(actor, itemId, 1, "composeFuwen")
end

actorevent.reg(aeInit,initFuWen)
actorevent.reg(aeAddEquiment, onEquipItem)

netmsgdispatcher.reg(Protocol.CMD_FuWen, Protocol.cFuWenCmd_EquipFuwen, OnEquipFuwen)
netmsgdispatcher.reg(Protocol.CMD_FuWen, Protocol.cFuWenCmd_LevelUpFuwen, OnLevelUpFuwen)
netmsgdispatcher.reg(Protocol.CMD_FuWen, Protocol.cFuWenCmd_DecomPoseFuwen, OnDecomposeFuwen)
netmsgdispatcher.reg(Protocol.CMD_FuWen, Protocol.cFuWenCmd_ConverFuwen, OnConverFuwen)
netmsgdispatcher.reg(Protocol.CMD_FuWen, Protocol.cFuWenCmd_Compose, composeFuwen)
