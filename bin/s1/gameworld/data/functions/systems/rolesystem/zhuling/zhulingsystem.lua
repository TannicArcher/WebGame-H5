module("zhulingsystem", package.seeall)--铸造

--装备强化接口
function equipZhuling(actor, roleId, posId)
	local tZhulingInfo = LActor.getZhulingInfo(actor, roleId)
	if (not tZhulingInfo) then
		print("zhulingsystem.equipZhuling aid:"..LActor.getActorId(actor).." not have tZhulingInfo")
		return
	end

	--按顺序获取最低的等级和对应的坐标
	local minlevel, minposId = getMinLevelAndPos(tZhulingInfo)
    if minposId ~= posId then
		print("zhulingsystem.equipZhuling aid:"..LActor.getActorId(actor).." minposId("..minposId..") ~= posId("..posId..")")
        return
    end

    local level = tZhulingInfo[posId]
    if level == nil then return end

	local nextLevel = level + 1
	local costConfig = zhulingcommon.getZhulingCostConfig(nextLevel)
	if (not costConfig) then
		print("zhulingsystem.equipZhuling aid:"..LActor.getActorId(actor).." not have costConfig nextLevel="..nextLevel)
		return
	end

	local itemId = costConfig.itemId
	local count = costConfig.count
	if (LActor.getItemCount(actor,itemId) < count) then
        print("equip bless decompose invalid. item not enough.aid:"..LActor.getActorId(actor))
        return
    end
    LActor.costItem(actor, itemId, count, "zhuling")

	--提高注灵等级
	LActor.setZhulingLevel(actor, roleId, posId, nextLevel)
	--更新属性
	updateAttr(actor, roleId)

	--给前端回包
	reqZhulingSync(actor, roleId, posId, nextLevel)

	actorevent.onEvent(actor, aeUpgradeZhuling, roleId, posId, nextLevel)
end

--按顺序获取最低的等级和对应的坐标的接口
function getMinLevelAndPos(tZhulingInfo)
	local tarPos = 0
	local minLevel = 0
	
	--按EnhanceConfig配置的顺序遍历
	for index = 1, #ForgeIndexConfig do
		local posId = ForgeIndexConfig[index].posId
		--为0的话就是最小等级了，返回就行
		if (tZhulingInfo[posId] == 0) then
			tarPos = posId
			minLevel = 0
			break
		end

		if (tZhulingInfo[posId] < minLevel or minLevel == 0) then
			tarPos = posId
			minLevel = tZhulingInfo[posId]
		end
	end
	return minLevel, tarPos
end


--更新属性
function updateAttr(actor, roleId)
	--先把原来的清零
	LActor.clearZhulingAttr(actor, roleId)

	addZhulingAttr(actor, roleId)

	--刷新角色属性
	LActor.reCalcRoleAttr(actor, roleId)
end

function addZhulingAttr(actor, roleId)
	local tZhulingInfo = LActor.getZhulingInfo(actor, roleId)
	if (not tZhulingInfo) then
		return
	end	

	--把所有位置的属性汇总
	local tAttrList = {}
	for posId, level in pairs(tZhulingInfo) do
		local config = zhulingcommon.getZhulingAttrConfig(posId, level)
		if (config) then
			for _,tb in pairs(config.attr  or {}) do
				tAttrList[tb.type] = tAttrList[tb.type] or 0
				tAttrList[tb.type] = tAttrList[tb.type] + tb.value
			end
		end
	end

	--vip属性百分比加成
	local percent = vip.getAttrAdditionPercentBySysId(actor,asZhuling)

	--统一添加属性
	for type,value in pairs(tAttrList) do
		local valueEx = math.floor(value * (1 + percent))
		LActor.addZhulingAttr(actor, roleId, type, valueEx)
	end
end

--给前端注灵的结果回包
function reqZhulingSync(actor, roleId, posId, level)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Zhuling, Protocol.sZhulingCmd_ReqLevelup)
	if pack == nil then return end

	LDataPack.writeData(pack, 3,
						dtShort, roleId,
						dtInt, posId,
						dtInt, level)
	LDataPack.flush(pack)	
end

--强化信息同步的协议
function zhulingInfoSync(actor, roleId)
	local tZhulingInfo = LActor.getZhulingInfo(actor, roleId)
	if (not tZhulingInfo) then
		return
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Zhuling, Protocol.sZhulingCmd_DataSync)
	if pack == nil then return end

	LDataPack.writeShort(pack, roleId)
	LDataPack.writeInt(pack, #tZhulingInfo+1)
	for posId = 0, #tZhulingInfo do
		LDataPack.writeData(pack, 2,
							dtInt, posId,
							dtInt, tZhulingInfo[posId])
	end

	LDataPack.flush(pack)	
end


function equipZhuling_c2s(actor, pack)
	local roleId = LDataPack.readShort(pack)
    local posId = LDataPack.readShort(pack)

	equipZhuling(actor, roleId, posId)
end

function onLogin(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0,count-1 do
		zhulingInfoSync(actor, roleId)
	end
end

function zhulingAttrInit(actor, roleId)
	--先把原来的清零
	LActor.clearZhulingAttr(actor, roleId)

	addZhulingAttr(actor, roleId)
end

function onVipLevelChanged(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0,count-1 do
		updateAttr(actor, roleId)
	end
end

_G.zhulingAttrInit = zhulingAttrInit

actorevent.reg(aeUpdateVipInfo, onVipLevelChanged)

netmsgdispatcher.reg(Protocol.CMD_Zhuling, Protocol.cZhulingCmd_Levelup, equipZhuling_c2s)
