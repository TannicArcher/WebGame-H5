module("togetherhitpunchequip", package.seeall)

--获取最低等级的部位和等级
function getMinLevelAndPos(EquipInfo)
	local tarPos = 0
	local minLevel = 0
	
	--按部位顺序遍历
	for posId = 0, TogetherHitSlotType_Max - 1 do
		--为0的话就是最小等级了，返回就行
		if EquipInfo[posId] == 0 then
			tarPos = posId
			minLevel = 0
			break
		end

		if EquipInfo[posId] < minLevel or minLevel == 0 then
			tarPos = posId
			minLevel = EquipInfo[posId]
		end
	end
	return minLevel, tarPos
end

--初始化属性
local function initAttr(actor)
	local EquipInfo = LActor.getTogetherPunchInfo(actor)
	if (not EquipInfo) then
		return
	end
	local attr = LActor.getTogetherPunchAttr(actor)
	if not attr then return end
	local ex_attr = LActor.getTogetherPunchExAttr(actor)
	if not ex_attr then return end
	attr:Reset()
	ex_attr:Reset()
	
	local minLv = nil
	for pos,lv in pairs(EquipInfo) do
		if not minLv then 
			minLv = lv
		elseif minLv > lv then
			minLv = lv
		end
		if lv > 0 then
			--获取配置
			local posCfg = PunchEquipConfig[pos]
			if posCfg then
				local lvCfg = posCfg[lv]
				if lvCfg then
					--添加属性
					for _,v in ipairs(lvCfg.attr or {}) do
						attr:Add(v.type, v.value)
					end
					for _,v in ipairs(lvCfg.exattr or {}) do
						ex_attr:Add(v.type, v.value)
					end
				end
			end
		end
	end
	--套装属性
	local mcfg = PunchEquipMasterConfig[minLv]
	if mcfg then
		for _,v in ipairs(mcfg.attr or {}) do
			attr:Add(v.type, v.value)
		end
		for _,v in ipairs(mcfg.exattr or {}) do
			ex_attr:Add(v.type, v.value)
		end		
	end
	LActor.reCalcAttr(actor)
	LActor.reCalcExAttr(actor)
end

--发送强化信息
local function sendPuncheInfo(actor, pos, lv)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_TogetherHitPuncheInfo)
	if pack == nil then return end
	if not pos then
		local EquipInfo = LActor.getTogetherPunchInfo(actor)
		if EquipInfo then
			LDataPack.writeShort(pack, #EquipInfo+1)
			for posId = 0, TogetherHitSlotType_Max - 1 do
				LDataPack.writeData(pack, 2, dtShort, posId, dtInt, EquipInfo[posId])
			end
		else
			LDataPack.writeShort(pack, 0)
		end
	else
		LDataPack.writeShort(pack, 1)
		LDataPack.writeData(pack, 2, dtShort, pos, dtInt, lv or 0)		
	end
	LDataPack.flush(pack)	
end

--请求强化合击部位
local function reqPuncheLvup(actor, packet)
	local EquipInfo = LActor.getTogetherPunchInfo(actor)
	if (not EquipInfo) then
		return
	end
	local minlv, pos = getMinLevelAndPos(EquipInfo)
	local nextLevel = minlv + 1
	--获取配置
	local posCfg = PunchEquipConfig[pos]
	if not posCfg then
		print(LActor.getActorId(actor).." togetherhitpunchequip.reqPuncheLvup not posCfg "..tostring(pos))
		return
	end
	local lvCfg = posCfg[nextLevel]
	if not lvCfg then
		print(LActor.getActorId(actor).." togetherhitpunchequip.reqPuncheLvup not lvCfg "..tostring(pos)..","..tostring(nextLevel))
		return
	end
	--检测是否够钱
	local cost = LActor.getCurrency(actor, lvCfg.cost.id)
	if cost >= lvCfg.cost.count then
		LActor.changeCurrency(actor, lvCfg.cost.id, 0 - lvCfg.cost.count, "tgh punche "..pos)
	else
		print(LActor.getActorId(actor).." togetherhitpunchequip.reqPuncheLvup not enough: "..tostring(pos)..","..tostring(nextLevel))
		return
	end
	--提高强化等级
	LActor.setTogetHerEquipLevel(actor, pos, nextLevel)
	--刷属性
	initAttr(actor)
	--回应客户端
	sendPuncheInfo(actor, pos, nextLevel)
end

--登陆回调
local function onLogin(actor)
	sendPuncheInfo(actor, nil, nil)
end

--初始化回调
local function onInit(actor)
	initAttr(actor)
end

local function init()
	actorevent.reg(aeInit, onInit)
	actorevent.reg(aeUserLogin, onLogin)
	
	netmsgdispatcher.reg(Protocol.CMD_Skill, Protocol.cSkillCmd_TogetherHitPuncheLvup, reqPuncheLvup)
end

table.insert(InitFnTable, init)

