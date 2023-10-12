module("stonesystem", package.seeall) --精炼

function updateAttr(actor, roleId)
	--先把原来的清零
	LActor.clearStoneAttr(actor, roleId)

	addStoneAttr(actor, roleId)

	--刷新角色属性
	LActor.reCalcRoleAttr(actor, roleId)
end

function addStoneAttr(actor, roleId)
	local stoneInfo = LActor.getStoneInfo(actor, roleId)
	if (not stoneInfo) then
		return
	end

	local tAttrList = {}
	for pos, level in pairs(stoneInfo) do
		local config = stonecommon.getPosLevelConfig(pos, level)
		if (config) then
			for _,tb in pairs(config.attr or {}) do
				tAttrList[tb.type] = tAttrList[tb.type] or 0
				tAttrList[tb.type] = tAttrList[tb.type] + tb.value
			end
		end
	end

	--vip属性百分比加成
	local percent = vip.getAttrAdditionPercentBySysId(actor,asStone)

	--统一添加属性
	for type,value in pairs(tAttrList) do
		local valueEx = math.floor(value * (1 + percent))
		vip.attrAssert(actor,asStone,value,percent,valueEx)
		LActor.addStoneAttr(actor, roleId, type, valueEx)
	end
end

function stoneInfoSync(actor, roleId)
	local stoneInfo = LActor.getStoneInfo(actor, roleId)
	if (not stoneInfo) then
		return
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Stone, Protocol.sStoneCmd_DataSync)
	if pack == nil then return end

	LDataPack.writeShort(pack, roleId)
	LDataPack.writeInt(pack, #stoneInfo+1)
	for posId = 0, #stoneInfo do
		LDataPack.writeData(pack, 2,
							dtInt, posId,
							dtInt, stoneInfo[posId])
	end

	LDataPack.flush(pack)	
end

function stoneLevelup(actor, roleId, posId)
	local stoneInfo = LActor.getStoneInfo(actor, roleId)
	if (not stoneInfo) then
		return
	end
	
	--按顺序获取最低的等级和对应的坐标
	--local level, posId = getMinLevelAndPos(stoneInfo)
	--判断格子开启等级
	local openCfg = StoneOpenConfig[posId]
	if not openCfg then
		print("stoneLevelup: posId="..tostring(posId).." is not Open Config")
		return
	end
	if openCfg.openLv > LActor.getLevel(actor) then
		print("stoneLevelup: openCfg.openLv="..tostring(openCfg.openLv).." level="..LActor.getLevel(actor).." Not satisfied")
		return
	end
	local level = stoneInfo[posId]
	local nextLevel = level + 1
	local costConfig = stonecommon.getLevelCostConfig(nextLevel)
	if (not costConfig) then
		return
	end

	
	--获取魂值，看够不够
	local count = LActor.getCurrency(actor, NumericType_Essence)
	if (count < costConfig.soulNum) then
		print("zhulingsystem.equipZhuling aid:"..LActor.getActorId(actor).." count("..count..") < costConfig.soulNum("..costConfig.soulNum..")")
		return
	end
	--先扣钱，再发货
	LActor.changeCurrency(actor, NumericType_Essence, -costConfig.soulNum, "stone")
	

	--提高等级
	LActor.setStoneLevel(actor, roleId, posId, nextLevel)

	--更新属性
	updateAttr(actor, roleId)

	--给前端回包
	reqStoneLevelupSync(actor, roleId, posId, nextLevel)	

	System.logCounter(LActor.getActorId(actor),
		LActor.getAccountName(actor),
		tostring(LActor.getLevel(actor)),
		"stone levelup", 
		tostring(nextLevel),
		tostring(posId),
		"","", "", "")
	actorevent.onEvent(actor, aeUpgradeStone, roleId, posId, nextLevel)
end


--按顺序获取最低的等级和对应的坐标的接口
function getMinLevelAndPos(stoneInfo)
	local tarPos = 0
	local minLevel = 0
	
	--按EnhanceConfig配置的顺序遍历
	local levelPer = #ForgeIndexConfig
	for index = 1, #ForgeIndexConfig do
		local posId = ForgeIndexConfig[index].posId

		if 0 ~= stoneInfo[posId]%8 then
			tarPos = posId
			minLevel = stoneInfo[posId]
			break
		end

		if (stoneInfo[posId] == 0) then
            tarPos = posId
            minLevel = 0
            break
        end

        if stoneInfo[posId] < minLevel or minLevel == 0 then
            tarPos = posId
            minLevel = stoneInfo[posId]
        end
	end

	return minLevel, tarPos
end

function reqStoneLevelupSync(actor, roleId, posId, level)	
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Stone, Protocol.sStoneCmd_ReqLevelUp)
	if pack == nil then return end

	LDataPack.writeData(pack, 3,
						dtShort, roleId,
						dtInt, posId,
						dtInt, level)

	LDataPack.flush(pack)		

end

function stoneLevelup_c2s(actor, pack)
	local roleId = LDataPack.readShort(pack)
	local posId = LDataPack.readByte(pack)
	stoneLevelup(actor, roleId, posId)
end

function onLogin(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0,count-1 do
		stoneInfoSync(actor, roleId)
	end
end

function stoneAttrInit(actor, roleId)
	--先把原来的清零
	LActor.clearStoneAttr(actor, roleId)

	addStoneAttr(actor, roleId)
end

function onVipLevelChanged(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0,count-1 do
		LActor.clearStoneAttr(actor, roleId)
		addStoneAttr(actor, roleId)
	end
	LActor.reCalcAttr(actor)
end

_G.stoneAttrInit = stoneAttrInit

actorevent.reg(aeUpdateVipInfo, onVipLevelChanged)

netmsgdispatcher.reg(Protocol.CMD_Stone, Protocol.cStoneCmd_LevelUp, stoneLevelup_c2s)