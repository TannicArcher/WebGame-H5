--装备开光(强化系统)
module("blesssystem", package.seeall)


--已开启的加两次属性
--新开启的时候加个记录标记,正常加1次属性

--[[
blessData = {
	flags = [roleid][posid] = true
 }
--]]

local NOTICE_ID = 36
local function getAttrConfig(posId, level)
    if (BlessAttrConfig[posId]) then
        return BlessAttrConfig[posId][level]
    end
    return nil
end

local function getCostConfig(level)
    return BlessCostConfig[level]
end

local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
    if var == nil then return nil end

    if var.blessData == nil then
        var.blessData = {}
    end
    return var.blessData
end

local function checkFlag(actor, roleid, posid)
	local data = getStaticData(actor)
	if data.flags == nil then return false end

	if data.flags[roleid] == nil then return false end
	return data.flags[roleid][posid] == 1
end

local function setFlag(actor, roleid, posid)
	local data = getStaticData(actor)
	if data.flags == nil then data.flags = {} end
	if data.flags[roleid] == nil then
		data.flags[roleid] = {}
	end

	data.flags[roleid][posid] = 1
end


--给前端强化的结果回包
local function notifyBless(actor, roleId, posId, level)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Enhance, Protocol.sEnhanceCmd_UpdateBlessInfo)
    if pack == nil then return end

    LDataPack.writeData(pack, 3,
        dtShort, roleId,
        dtInt, posId,
        dtInt, level)
    LDataPack.flush(pack)
end

--按顺序获取最低的等级和对应的坐标的接口
local function getMinLevelAndPos(equipInfo)
    local tarPos = 0
    local minLevel = 0

    --之前的人 把部位顺序都写在锻造的配置里了ForgeConfig
    for index = 1, #ForgeIndexConfig do
        local posId = ForgeIndexConfig[index].posId
        --为0的话就是最小等级了，返回就行
        print("bless info: index:"..index.." pos:"..posId.." lv:"..equipInfo[posId].bless_lv)
        if (equipInfo[posId].bless_lv == 0) then
            tarPos = posId
            minLevel = 0
            break
        end

        if (equipInfo[posId].bless_lv < minLevel or minLevel == 0) then
            tarPos = posId
            minLevel = equipInfo[posId].bless_lv
        end
    end
    return minLevel, tarPos
end

local function getEquipInfo(actor, roleId)
    local roleData = LActor.getRoleData(actor, roleId)
    if roleData == nil then
        print("get roledata error.."..LActor.getActorId(actor))
        return nil
    end
    return roleData.equips_data.slot_data
end

local function getPosName(pos)
    for _, v in ipairs(ForgeIndexConfig) do
        if v.posId == pos then
            return v.name
        end
    end
    return nil
end

--更新属性
local function updateAttr(actor, roleId, recalc)
    local attrs = LActor.getEquipBlessAttrs(actor, roleId)
    if attrs == nil then
        print("get equip bless attr error.."..LActor.getActorId(actor))
        return
    end

    local equipInfo = getEquipInfo(actor, roleId)
    if equipInfo == nil then
        print("get equipInfo error.."..LActor.getActorId(actor))
        return
    end

    attrs:Reset()
	for _,fv in ipairs(ForgeIndexConfig) do
		local posId = fv.posId
        local v = equipInfo[posId]
        local conf = getAttrConfig(posId, v.bless_lv)
        if conf ~= nil then
            for _, attr in pairs(conf.attr) do
                attrs:Add(attr.type, attr.value)
	            if not checkFlag(actor, roleId,  posId) then
		            attrs:Add(attr.type, attr.value)
	            end
            end
        end
    end
    if recalc then
        LActor.reCalcRoleAttr(actor, roleId)
    end
end


--强化接口
local function equipBless(actor, roleId, posId)
    local equipInfo = getEquipInfo(actor, roleId)
    if (not equipInfo) then
        return
    end

    --按顺序获取最低的等级和对应的坐标
    --[[
    local minlevel, minposId = getMinLevelAndPos(equipInfo)
    if minposId ~= posId then
        print("level pos")
        return
    end
    --]]

    local level = equipInfo[posId].bless_lv
    if level == nil then return end

    local nextLevel = level + 1
    local costConfig = getCostConfig(nextLevel)
    if (not costConfig) then
        print("equip bless cost config nil. level:"..nextLevel)
        return
    end

    local itemId = costConfig.stoneId
    local count = costConfig.stoneNum
    local useYuanBao = false
    local log = "equip bless"

    if (LActor.getItemCount(actor,itemId) < count) then
        print("item "..costConfig.stoneId.. " not enough. aid:"..LActor.getActorId(actor))
        return
    end

    LActor.costItem(actor, itemId, count,log)
    

    --提高强化等级
    equipInfo[posId].bless_lv = nextLevel
    local posName = getPosName(posId)
    if posName then
        noticemanager.broadCastNotice(NOTICE_ID, LActor.getName(actor), getPosName(posId))
    else
        print("get pos name error:"..posId)
    end

    actorevent.onEvent(actor, aeBlessLevelChanged, roleId, posId, nextLevel)
    setFlag(actor, roleId, posId)
    --更新属性
    updateAttr(actor, roleId, true)

    --给前端回包
    notifyBless(actor, roleId, posId, nextLevel)
    actorevent.onEvent(actor,aeCasting,1,false)
end

--分解材料
local function equipBlessDecompose(actor, count)
	local conf = getCostConfig(1)
	if conf == nil or conf.stoneId == nil or conf.recycleYuanbao == nil then
		print("on equipBlessDecompose can't find config")
		return
	end
	local ret = true
	local itemId = conf.stoneId
	local yb = conf.recycleYuanbao

    if (LActor.getItemCount(actor,itemId) < count) then
        print("equip bless decompose invalid. item not enough.aid:"..LActor.getActorId(actor))
        return
    end

    LActor.costItem(actor, itemId, count,log)
	
	if ret then
		LActor.changeYuanBao(actor, yb * count, "equip bless decompose")
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Enhance, Protocol.sEnhanceCmd_BlessDecomposeResult)
	if npack == nil then return end

	LDataPack.writeByte(npack, ret and 1 or 0)
	LDataPack.flush(npack)
end


--client callback
local function onEquipBless(actor, pack)
    local roleId = LDataPack.readShort(pack)
    local pos = LDataPack.readShort(pack)

    equipBless(actor, roleId, pos)
end

local function onEquipBlessDecompose(actor, pack)
	local count = LDataPack.readShort(pack)
	if count == nil or count <= 0 then
		print("on bless decompose invalid. count:"..tostring(count).." aid:"..LActor.getActorId(actor))
		return
	end

	equipBlessDecompose(actor, count)
end


local function blessAttrInit(actor)
	local roleCount = LActor.getRoleCount(actor)
	for roleId=0,roleCount -1 do
		updateAttr(actor, roleId)
	end
end

actorevent.reg(aeInit, blessAttrInit)

netmsgdispatcher.reg(Protocol.CMD_Enhance, Protocol.cEnhanceCmd_EquipBless, onEquipBless)
netmsgdispatcher.reg(Protocol.CMD_Enhance, Protocol.cEnhanceCmd_EquipBlessDecompose, onEquipBlessDecompose)


function gmEquipBless(actor, roleid, pos)
    equipBless(actor, roleid, pos)
end

