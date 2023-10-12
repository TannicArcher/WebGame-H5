module("tuposystem", package.seeall)

--装备强化接口
function equipTupo(actor, roleId, posId)
	local tTupoInfo = LActor.getTupoInfo(actor, roleId)
	if (not tTupoInfo) then
		return
	end

	--按顺序获取最低的等级和对应的坐标
	local minlevel, minposId = getMinLevelAndPos(tTupoInfo)
    if minposId ~= posId then
        return
    end

    local level = tTupoInfo[posId]
    if level == nil then return end

	local nextLevel = level + 1
	local costConfig = tupocommon.getTupoCostConfig(nextLevel)
	if (not costConfig) then
		return
	end

	local itemId = costConfig.itemId
	local count = costConfig.count
	local useYuanBao = false
	local log = "equip tu po"
	
	if (LActor.getItemCount(actor,itemId) < count) then
        print("equip bless decompose invalid. item not enough.aid:"..LActor.getActorId(actor))
        return
    end

    LActor.costItem(actor, itemId, count,log)

	--提高注灵等级
	LActor.setTupoLevel(actor, roleId, posId, nextLevel)
	--更新属性
	updateAttr(actor, roleId)

	--给前端回包
	reqTupoSync(actor, roleId, posId, nextLevel)

	actorevent.onEvent(actor, aeUpgradeTupo, roleId, posId, nextLevel)
end

--按顺序获取最低的等级和对应的坐标的接口
function getMinLevelAndPos(tTupoInfo)
	local tarPos = 0
	local minLevel = 0
	
	--按EnhanceConfig配置的顺序遍历
	for index = 1, #ForgeIndexConfig do
		local posId = ForgeIndexConfig[index].posId
		--为0的话就是最小等级了，返回就行
		if (tTupoInfo[posId] == 0) then
			tarPos = posId
			minLevel = 0
			break
		end

		if (tTupoInfo[posId] < minLevel or minLevel == 0) then
			tarPos = posId
			minLevel = tTupoInfo[posId]
		end
	end
	return minLevel, tarPos
end


--todu
--更新属性
function updateAttr(actor, roleId)
	--先把原来的清零
	LActor.clearTupoAttr(actor, roleId)

	addTupoAttr(actor, roleId)

	--刷新角色属性
	LActor.reCalcRoleAttr(actor, roleId)
end

function addTupoAttr(actor, roleId)
	local tTupoInfo = LActor.getTupoInfo(actor, roleId)
	if (not tTupoInfo) then
		return
	end

	--把所有位置的属性汇总
	local tAttrList = {}
	for posId, level in pairs(tTupoInfo) do
		local config = tupocommon.getTupoAttrConfig(posId, level)
		local tEquipAttr = LActor.getEquipAttr(actor, roleId, posId)
		if (config and tEquipAttr ~= nil) then
			for i=Attribute.atHp,Attribute.atCount-1 do
				if (tEquipAttr[i] ~= 0) then
					tAttrList[i] = tAttrList[i] or 0
					tAttrList[i] = tAttrList[i] + math.floor(tEquipAttr[i]*config.attr/100)
				end
			end
		end
	end

	--统一添加属性
	for type,value in pairs(tAttrList) do
		LActor.addTupoAttr(actor, roleId, type, value)
	end
end

--给前端注灵的结果回包
function reqTupoSync(actor, roleId, posId, level)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Tupo, Protocol.sTupoCmd_ReqLevelup)
	if pack == nil then return end

	LDataPack.writeData(pack, 3,
						dtShort, roleId,
						dtInt, posId,
						dtInt, level)
	LDataPack.flush(pack)	
end

--强化信息同步的协议
function tupoInfoSync(actor, roleId)
	local tTupoInfo = LActor.getTupoInfo(actor, roleId)
	if (not tTupoInfo) then
		return
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Tupo, Protocol.sTupoCmd_DataSync)
	if pack == nil then return end

	LDataPack.writeShort(pack, roleId)
	LDataPack.writeInt(pack, #tTupoInfo+1)
	for posId = 0, #tTupoInfo do
		LDataPack.writeData(pack, 2,
							dtInt, posId,
							dtInt, tTupoInfo[posId])
	end

	LDataPack.flush(pack)	
end


function equipTupo_c2s(actor, pack)
	local roleId = LDataPack.readShort(pack)
    local pos = LDataPack.readShort(pack)

	equipTupo(actor, roleId, pos)
end

function onLogin(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0,count-1 do
		tupoInfoSync(actor, roleId)
	end
end

function onEquipItem(actor, roleId)
	--先把原来的清零
	LActor.clearTupoAttr(actor, roleId)

	addTupoAttr(actor, roleId)
end

function tupoAttrInit(actor, roleId)
	--先把原来的清零
	LActor.clearTupoAttr(actor, roleId)

	addTupoAttr(actor, roleId)
end

_G.tupoAttrInit = tupoAttrInit

actorevent.reg(aeAddEquiment, onEquipItem)
netmsgdispatcher.reg(Protocol.CMD_Tupo, Protocol.cZTupoCmd_Levelup, equipTupo_c2s)
