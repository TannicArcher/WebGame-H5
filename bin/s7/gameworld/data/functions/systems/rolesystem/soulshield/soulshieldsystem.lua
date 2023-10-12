module("soulshieldsystem", package.seeall)

function soulshieldStageup(actor,roleId,type)
	local stage,level,exp = LActor.getSoulShieldinfo(actor,roleId,type)
	if (not level or not stage or not exp ) then
		return
	end

	--是否需要进阶
	if (not soulshieldcommon.checkNeedStageUp(type,level,stage)) then
		LActor.sendTipmsg(actor,Lang.ScriptTips.lhx001,ttMessage)
		return
	end


	stage = stage + 1
	print("soulstageup:"..stage.."type:"..tostring(type))

	LActor.setSoulShieldStage(actor,roleId,type,stage)
	updateAttr(actor,roleId)
	reqStageupSync(actor, roleId, type, stage)


end

local function soulshieldAct(actor, roleId, type)
	if type ~= ssLoongSoul then return end--暂时只考虑龙魂(宝物)
	local stage,level,exp,act = LActor.getSoulShieldinfo(actor, roleId, type)
	if act == 1 then return end --已经激活过了
	--还没到激活等级
	if soulshieldcommon.getOpenLv(type) > LActor.getLevel(actor) then
		print("soulshieldAct: not open level:"..soulshieldcommon.getOpenLv(type)..", type:"..tostring(type))
		return
	end
	--激活
	LActor.setSoulShieldAct(actor,roleId,type,1)
	--属性
	updateAttr(actor,roleId)
	--通知客户端
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_SoulShield, Protocol.sSoulShieldCmd_ReqAct)
	if pack == nil then return end
	LDataPack.writeData(pack, 3,
						dtShort, roleId,
						dtShort, type,
						dtByte, 1)
	LDataPack.flush(pack)	
end

function soulshieldLevelup(actor, roleId, type)
	local stage,level,exp,act = LActor.getSoulShieldinfo(actor, roleId, type)
	if (not level or not stage or not exp or act ~= 1) then
		return
	end
	if soulshieldcommon.getOpenLv(type) > LActor.getLevel(actor) then
		print("soulshieldLevelup: not open level:"..soulshieldcommon.getOpenLv(type)..", type:"..tostring(type))
		return
	end
	local nextLevel = level + 1
	local config = soulshieldcommon.getLevelConfig(type, nextLevel)
	if (not config) then
		return
	end

	local stageconf = soulshieldcommon.getStageConfig(type,stage)
	if not stageconf then return end

	local itemId = config.itemId	
	local itemexp = stageconf.normalBaseExp
	local count = stageconf.normalCost
	local upgradeexp = config.upgradeexp
	local addexp = itemexp * count
	local useYuanBao = false
	--local log = "soul shield level up"..tostring(type)

	--材料不足的时候，有多少扣多少
	if (LActor.getItemCount(actor,itemId) < count) then
		count = LActor.getItemCount(actor,itemId)
		addexp = itemexp * count
	end

	if (LActor.getItemCount(actor,itemId) == 0) then
		LActor.sendTipmsg(actor,Lang.ScriptTips.lhx004,ttMessage)
		return
	end


	
	--是否满级
	if (soulshieldcommon.isMaxlvel(type,level)) then
		LActor.sendTipmsg(actor,Lang.ScriptTips.lhx002,ttMessage)
		return
	end

	--是否需要进阶
	--print("==============soulshieldcommon.checkNeedStageUp(level,stage:"..tostring(soulshieldcommon.checkNeedStageUp(type,level,stage)))
	if (soulshieldcommon.checkNeedStageUp(type,level,stage)) then
		LActor.sendTipmsg(actor,Lang.ScriptTips.lhx003,ttMessage)
		return
	end

	LActor.costItem(actor, itemId, count,log)
	addsoulexp(actor,roleId,type,addexp)
	--print("soullevelup:"..level.."type:"..tostring(type))
	--print("=========================龙魂进阶:"..stage.."level:"..level.."exp:"..addexp)
	--LActor.setSoulShieldLevel(actor, roleId, type, nextLevel)
	
	--updateAttr(actor, roleId)

	--reqLevelupSync(actor, roleId, type, nextLevel)
	
end

function addsoulexp(actor,roleId,type,addexp)
	local stage,level,exp = LActor.getSoulShieldinfo(actor, roleId, type)
	if (not stage or not level) then
		return
	end

	--是否满级
	if (soulshieldcommon.isMaxlvel(type,level)) then
		LActor.sendTipmsg(actor,Lang.ScriptTips.lhx002,ttMessage)
		return
	end

	local levelconf = soulshieldcommon.getLevelConfig(type,level)
	if (not levelconf ) then
		print("soullevel comf is error!!!!!!!!!")
		return
	end
	
	local oldlevel = level
	exp = exp + addexp
	while (exp >= levelconf.exp) do
		exp = exp - levelconf.exp

		level = level + 1

		System.logCounter(LActor.getActorId(actor),
			LActor.getAccountName(actor),
			tostring(LActor.getLevel(actor)),
			"soulshield levelup", 
			tostring(level),
			"","","", "", "")

		--是否满级
		if (soulshieldcommon.isMaxlvel(type,level)) then
			exp = 0
			break
		end

		levelconf = soulshieldcommon.getLevelConfig(type,level)
		if (not levelconf) then
			break
		end
	end
	--print("========设置经验和等级exp:"..exp.."level:"..level)
	LActor.setSoulShieldExp(actor,roleId,type,exp)

	if (oldlevel ~= level) then
		LActor.setSoulShieldLevel(actor,roleId,type,level)
		updateAttr(actor,roleId)
		if (type == ssLoongSoul) then
			actorevent.onEvent(actor, aeUpgradeLoongSoul, roleId, level)
		elseif(type == ssShield) then
			actorevent.onEvent(actor, aeUpgradeShield, roleId, level)
		elseif(type == ssXueyu) then
			actorevent.onEvent(actor, aeXueyuLevelCount, roleId,level)
		end
	end

	--提升多少次成就
	if (type == ssLoongSoul) then
		--print("龙魂成就")
		actorevent.onEvent(actor, aeloongLevelCount, roleId, 1)
	elseif(type == ssShield) then
		actorevent.onEvent(actor, aeShieldLevelCount, roleId, 1)
	end


	reqLevelupSync(actor, roleId, type, level,exp)

end


--更新属性
function updateAttr(actor, roleId)
	--先把原来的清零
	
	LActor.clearSoulShieldAttr(actor, roleId)
	
	addSoulShieldAttr(actor, roleId)

	--刷新角色属性
	LActor.reCalcRoleAttr(actor, roleId)
end

function addSoulAttr(actor, roleId)	
	local stage,soulLevel,exp,act = LActor.getSoulShieldinfo(actor, roleId, ssLoongSoul)
	if act ~= 1 then return end
	--if (soulLevel and stage) then
		local config = soulshieldcommon.getLevelConfig(ssLoongSoul, soulLevel)
		if (config) then
			local percent = vip.getAttrAdditionPercentBySysId(actor,asLongSoul)

			local value = 0
			for _, tb in pairs(config.attr) do
				value = math.floor(tb.value * (1+percent))
				vip.attrAssert(actor,asLongSoul,tb.value,percent,value)
				LActor.addSoulShieldAttr(actor, roleId, tb.type, value)
			end
		end

		local stageconf = soulshieldcommon.getStageConfig(ssLoongSoul,stage)
		if (stageconf) then
			local stagevalue = 0
			for _,tb in pairs(stageconf.attr) do
				LActor.addSoulShieldAttr(actor, roleId, tb.type, tb.value)
			end
		end
	--end
end

function addShieldAttr(actor, roleId)
	local stage,shieldLevel,exp = LActor.getSoulShieldinfo(actor, roleId, ssShield)
	if (shieldLevel and stage) then
		local config = soulshieldcommon.getLevelConfig(ssShield, shieldLevel)
		if (config) then
			local percent = vip.getAttrAdditionPercentBySysId(actor,asShield)

			local value = 0
			for _, tb in pairs(config.attr) do
				value = math.floor(tb.value * (1+percent))
				vip.attrAssert(actor,asShield,tb.value,percent,value)
				LActor.addSoulShieldAttr(actor, roleId, tb.type, value)
			end
		end

		local stageconf = soulshieldcommon.getStageConfig(ssShield,stage)
		if (stageconf) then
			local stagevalue = 0
			for _,tb in pairs(stageconf.attr) do
				LActor.addSoulShieldAttr(actor, roleId, tb.type, tb.value)
			end
		end
	end
end

function addXueyuAttr(actor,roleId)
	local stage,XueyuLevel,exp = LActor.getSoulShieldinfo(actor, roleId, ssXueyu)
	if (XueyuLevel and stage) then
		local config = soulshieldcommon.getLevelConfig(ssXueyu, XueyuLevel)
		if (config) then
			
			local percent = vip.getAttrAdditionPercentBySysId(actor,asShield)

			local value = 0
			for _, tb in pairs(config.attr) do
				value = math.floor(tb.value * (1+percent))
				vip.attrAssert(actor,asShield,tb.value,percent,value)
				LActor.addSoulShieldAttr(actor, roleId, tb.type, value)
			end
		end

		local stageconf = soulshieldcommon.getStageConfig(ssXueyu,stage)
		if (stageconf) then
			
			local stagevalue = 0
			for _,tb in pairs(stageconf.attr) do
				LActor.addSoulShieldAttr(actor, roleId, tb.type, tb.value)
			end
		end
	end
end

function addSoulShieldAttr(actor, roleId)
	addSoulAttr(actor, roleId)
	--addShieldAttr(actor, roleId)
	--addXueyuAttr(actor,roleId)
end

function reqStageupSync(actor, roleId, type, stage)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_SoulShield, Protocol.sSoulShieldCmd_ReqStageUp)
	if pack == nil then return end

	LDataPack.writeData(pack, 3,
						dtShort, roleId,
						dtShort, type,
						dtInt, stage)
	LDataPack.flush(pack)
end

function reqLevelupSync(actor, roleId, type, level, exp)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_SoulShield, Protocol.sSoulShieldCmd_ReqLevelUp)
	if pack == nil then return end

	LDataPack.writeData(pack, 4,
						dtShort, roleId,
						dtShort, type,
						dtInt, level,
						dtInt, exp)
	LDataPack.flush(pack)	
end

function soulshieldLevelup_c2s(actor, pack)
	local roleId = LDataPack.readShort(pack)
	local type = LDataPack.readShort(pack)
	soulshieldLevelup(actor, roleId, type)
end

function soulshieldStageup_c2s(actor,pack)
	local roleId = LDataPack.readShort(pack)
	local type = LDataPack.readShort(pack)
	soulshieldStageup(actor, roleId, type)
end

function soulshieldAct_c2s(actor, pack)
	local roleId = LDataPack.readShort(pack)
	local type = LDataPack.readShort(pack)
	soulshieldAct(actor, roleId, type)
end

function soulShieldAttrInit(actor, roleId)
	--先把原来的清零
	LActor.clearSoulShieldAttr(actor, roleId)

	addSoulShieldAttr(actor, roleId)
end

function onVipLevelChanged(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0,count-1 do
		LActor.clearSoulShieldAttr(actor, roleId)
		addSoulShieldAttr(actor, roleId)
	end
	LActor.reCalcAttr(actor)
end

_G.soulShieldAttrInit = soulShieldAttrInit

actorevent.reg(aeUpdateVipInfo, onVipLevelChanged)

netmsgdispatcher.reg(Protocol.CMD_SoulShield, Protocol.cSoulShieldCmd_LevelUp, soulshieldLevelup_c2s)
netmsgdispatcher.reg(Protocol.CMD_SoulShield, Protocol.cSoulShieldCmd_StageUp, soulshieldStageup_c2s)
netmsgdispatcher.reg(Protocol.CMD_SoulShield, Protocol.cSoulShieldCmd_Act, soulshieldAct_c2s)
