module("enhancesystem", package.seeall)

--装备强化接口
function equipEnhance(actor, roleId, posId)
	local tEnhanceInfo = LActor.getEnhanceInfo(actor, roleId)
	if (not tEnhanceInfo) then
		return
	end

	--按顺序获取最低的等级和对应的坐标
	local minlevel, minposId = getMinLevelAndPos(tEnhanceInfo)
    if minposId ~= posId then
        return
    end

    local level = tEnhanceInfo[posId]
    if level == nil then return end

	local nextLevel = level + 1
	local costConfig = enhancecommon.getEnhanceCostConfig(nextLevel)
	if (not costConfig) then
		return
	end

	local itemId = costConfig.stoneId
	local count = costConfig.stoneNum
	local useYuanBao = false
	local log = "equip enhance"
	--LActor.costItem(actor, itemId, count, log)
	if (not LActor.consumeItem(actor, itemId, count, useYuanBao, log)) then
		return 
	end
	
	--提高强化等级
	LActor.setEnhanceLevel(actor, roleId, posId, nextLevel)

	actorevent.onEvent(actor, aeStrongLevelChanged, roleId, posId, nextLevel)
	--更新属性
	updateAttr(actor, roleId)

	--给前端回包
	reqEnhanceSync(actor, roleId, posId, nextLevel)
end

--按顺序获取最低的等级和对应的坐标的接口
function getMinLevelAndPos(tEnhanceInfo)
	local tarPos = 0
	local minLevel = 0
	
	--按EnhanceConfig配置的顺序遍历
	for index = 1, #ForgeIndexConfig do
		local posId = ForgeIndexConfig[index].posId
		--为0的话就是最小等级了，返回就行
		if (tEnhanceInfo[posId] == 0) then
			tarPos = posId
			minLevel = 0
			break
		end

		if (tEnhanceInfo[posId] < minLevel or minLevel == 0) then
			tarPos = posId
			minLevel = tEnhanceInfo[posId]
		end
	end
	return minLevel, tarPos
end


--更新属性
function updateAttr(actor, roleId)
	--先把原来的清零
	LActor.clearEnhanceAttr(actor, roleId)

	addEnhanceAttr(actor, roleId)

	--刷新角色属性
	LActor.reCalcRoleAttr(actor, roleId)
end

function addEnhanceAttr(actor, roleId)
	local tEnhanceInfo = LActor.getEnhanceInfo(actor, roleId)
	if (not tEnhanceInfo) then
		return
	end

	--把所有位置的属性汇总
	local tAttrList = {}
	for posId, level in pairs(tEnhanceInfo) do
		local config = enhancecommon.getEnhanceAttrConfig(posId, level)
		if (config) then
			for _,tb in pairs(config.attr) do
				tAttrList[tb.type] = tAttrList[tb.type] or 0
				tAttrList[tb.type] = tAttrList[tb.type] + tb.value
			end
		end
	end

	--vip属性百分比加成
	local percent = vip.getAttrAdditionPercentBySysId(actor,asEnhance)

	--统一添加属性
	for type,value in pairs(tAttrList) do
		local valueEx = math.floor(value * (1 + percent))
		vip.attrAssert(actor,asEnhance,value,percent,valueEx)
		LActor.addEnhanceAttr(actor, roleId, type, valueEx)
	end
end

--给前端强化的结果回包
function reqEnhanceSync(actor, roleId, posId, level)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Enhance, Protocol.sEnhanceCmd_ReqEnhance)
	if pack == nil then return end

	LDataPack.writeData(pack, 3,
						dtShort, roleId,
						dtInt, posId,
						dtInt, level)
	LDataPack.flush(pack)	
end

--强化信息同步的协议
function enhanceInfoSync(actor, roleId)
	local tEnhanceInfo = LActor.getEnhanceInfo(actor, roleId)
	if (not tEnhanceInfo) then
		return
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Enhance, Protocol.sEnhanceCmd_InitData)
	if pack == nil then return end

	LDataPack.writeShort(pack, roleId)
	LDataPack.writeInt(pack, #tEnhanceInfo+1)
	for posId = 0, #tEnhanceInfo do
		LDataPack.writeData(pack, 2,
							dtInt, posId,
							dtInt, tEnhanceInfo[posId])
	end

	LDataPack.flush(pack)	
end


function equipEnhance_c2s(actor, pack)

	local roleId = LDataPack.readShort(pack)
    local pos = LDataPack.readShort(pack)

	equipEnhance(actor, roleId, pos)
end

function onLogin(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0,count-1 do
		enhanceInfoSync(actor, roleId)
	end
end

function enhanceAttrInit(actor, roleId)
	--先把原来的清零
	LActor.clearEnhanceAttr(actor, roleId)

	addEnhanceAttr(actor, roleId)
end

function onVipLevelChanged(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0,count-1 do
		LActor.clearEnhanceAttr(actor, roleId)
		addEnhanceAttr(actor, roleId)
	end
	LActor.reCalcAttr(actor)
end

_G.enhanceAttrInit = enhanceAttrInit

actorevent.reg(aeUpdateVipInfo, onVipLevelChanged)

netmsgdispatcher.reg(Protocol.CMD_Enhance, Protocol.cEnhanceCmd_Enhance, equipEnhance_c2s)
