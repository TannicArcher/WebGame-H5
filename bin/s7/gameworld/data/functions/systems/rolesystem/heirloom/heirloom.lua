module("heirloom", package.seeall) --传世装备

--获取玩家静态变量数据
local function getVarData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then 
		return nil
	end
	--初始化静态变量的数据
	if var.heirloom == nil then
		var.heirloom = {}
	end
	return var.heirloom
end

--初始化属性
local function initAttr(actor, role_id)
	local role = LActor.getRole(actor, role_id)
	if role == nil then return end
	
	local attr = LActor.GetHeirloomAttrs(actor, role_id)
	if not attr then return end
	attr:Reset();
	local minLv = 999999
	--所有部位的等级
	for slot,_ in ipairs(ForgeIndexConfig) do
		local lv = LActor.getHeirloomLv(actor, role_id, slot-1)
		if lv > 0 then
			--根据部位和等级获取对应的配置
			local slotCfg = HeirloomEquipConfig[slot]
			if slotCfg then
				--获取对应等级的配置行
				local cfg = slotCfg[lv]
				if cfg then
					for _,v in ipairs(cfg.attr) do
						attr:Add(v.type or 0, v.value or 0)
					end
					--给装备基础属性增加
					local tEquipAttr = LActor.getEquipAttr(actor, role_id, slot-1)
					for type=Attribute.atHpMax,Attribute.atTough do
						if tEquipAttr[type] ~= 0 then
							local value = math.floor(tEquipAttr[type] * cfg.attr_add/100)
							attr:Add(type, value or 0)
						end
					end
					--给强化属性的增加
					local tEnhanceInfo = LActor.getEnhanceInfo(actor, role_id)
					if tEnhanceInfo then
						local ecfg = enhancecommon.getEnhanceAttrConfig(slot-1, tEnhanceInfo[slot-1])
						if ecfg then
							for _,v in ipairs(ecfg.attr) do
								local value = math.floor(v.value * cfg.attr_add/100)
								attr:Add(v.type, value or 0)
							end
						end
					end
					--给精炼系统属性的增加
					local tZhulingInfo = LActor.getZhulingInfo(actor, role_id)
					if tZhulingInfo then
						local zcfg = zhulingcommon.getZhulingAttrConfig(slot-1, tZhulingInfo[slot-1]) 
						if zcfg then
							for _,v in ipairs(zcfg.attr or {}) do
								local value = math.floor(v.value * cfg.attr_add/100)
								attr:Add(v.type, value or 0)
							end
						end
					end
				end
			end
		end
		--计算最小等级
		if lv < minLv then minLv = lv end
	end
	--套装效果
	if minLv > 0 then
		local setCfg = HeirloomEquipSetConfig[minLv]
		if setCfg then	
			local lnoteLv = getVarData(actor)
			if (lnoteLv[role_id] or 0) < minLv then
				lnoteLv[role_id] = minLv
				if setCfg.nid then
					noticemanager.broadCastNotice(setCfg.nid, LActor.getName(actor), setCfg.name)
				end
			end
			for _,v in ipairs(setCfg.attr) do
				attr:Add(v.type or 0, v.value or 0)
			end	
		end
	end
	
	LActor.reCalcAttr(role)
end

--升级或激活回包
local function sendSlotLv(actor, role_id, slot, lv)
	local npack =  LDataPack.allocPacket(actor, Protocol.CMD_Heirloom, Protocol.sHeirloomCmd_Info)
	LDataPack.writeByte(npack, role_id)
	LDataPack.writeByte(npack, slot)
	LDataPack.writeByte(npack, lv)
	LDataPack.flush(npack)
end

--请求合成道具
local function reqCompose(actor, packet)
	local slot = LDataPack.readByte(packet)
	local cfg = HeirloomEquipItemConfig[slot]
	if not cfg then
		print("heirloom.reqCompose not have cfg slot:"..slot..", actor_id:"..LActor.getActorId(actor))
		return
	end
	local item_id = cfg.item
	--检测升级消耗
	local count = LActor.getItemCount(actor, cfg.expend.id)
	if count < cfg.expend.count then
		print("heirloom.reqCompose not enough cost item_id:"..item_id..", actor_id:"..LActor.getActorId(actor))
		return
	end
	--扣除消耗
	LActor.costItem(actor, cfg.expend.id, cfg.expend.count, "heirloom Compose")
	--获取道具
	local awards = {{type=AwardType_Item, id=item_id, count=1}}
	--获得奖励
	LActor.giveAwards(actor, awards, "heirloom Compose")
end

--请求激活装备
local function reqActive(actor, packet)
	local role_id = LDataPack.readByte(packet)
	local slot = LDataPack.readByte(packet)
	--获取配置
	local cfg = HeirloomEquipFireConfig[slot]
	if not cfg then
		print("heirloom.reqActive not have config slot:"..slot..",actor_id:"..LActor.getActorId(actor))
		return
	end
	--获取该部位等级
	local lv = LActor.getHeirloomLv(actor, role_id, slot-1)
	if lv ~= 0 then
		print("heirloom.reqActive lv("..lv..") is have val, role_id:"..role_id..",slot:"..slot..", actor_id:"..LActor.getActorId(actor))
		return
	end
	--检测升级消耗
	local count = LActor.getItemCount(actor, cfg.expend.id)
	if count < cfg.expend.count then
		print("heirloom.reqActive not enough cost slot:"..slot..", actor_id:"..LActor.getActorId(actor))
		return
	end
	--扣除消耗
	LActor.costItem(actor, cfg.expend.id, cfg.expend.count, "heirloom Compose")
	local newLv = lv+1
	--激活装备
	LActor.setHeirloomLv(actor, role_id, slot-1, newLv)
	--回应包给客户端
	sendSlotLv(actor, role_id, slot, newLv)
	initAttr(actor, role_id)
end

--请求升级装备
local function reqLvUp(actor, packet)
	local role_id = LDataPack.readByte(packet)
	local slot = LDataPack.readByte(packet)
	--获取该部位等级
	local lv = LActor.getHeirloomLv(actor, role_id, slot-1)
	if lv <= 0 then
		print("heirloom.reqLvUp lv("..lv..") is not val, role_id:"..role_id..",slot:"..slot..", actor_id:"..LActor.getActorId(actor))
		return
	end
	--根据部位和等级获取对应的配置
	local slotCfg = HeirloomEquipConfig[slot]
	if not slotCfg then
		print("heirloom.reqLvUp slot("..slot..") is not have config, actor_id:"..LActor.getActorId(actor))
		return
	end
	--判断是否达到最大等级
	if lv >= #slotCfg then
		print("heirloom.reqLvUp slot("..slot.."),lv("..lv..") is max lv, actor_id:"..LActor.getActorId(actor))
		return
	end
	--获取对应等级的配置行
	local cfg = slotCfg[lv]
	if not cfg then
		print("heirloom.reqLvUp slot("..slot.."),lv("..lv..") is not have config, actor_id:"..LActor.getActorId(actor))
		return
	end
	--检测升级消耗
	local count = LActor.getItemCount(actor, cfg.expend.id)
	if count < cfg.expend.count then
		print("heirloom.reqActive not enough cost slot:"..slot..", actor_id:"..LActor.getActorId(actor))
		return
	end
	--扣除消耗
	LActor.costItem(actor, cfg.expend.id, cfg.expend.count, "heirloom Compose")
	local newLv = lv+1
	--升级装备
	LActor.setHeirloomLv(actor, role_id, slot-1, newLv)
	--回应包给客户端
	sendSlotLv(actor, role_id, slot, newLv)
	initAttr(actor, role_id)
end

local function onInit(actor)
	for i=0,LActor.getRoleCount(actor) -1 do
		initAttr(actor, i)
	end
end

local function onEquipItem(actor, roleId)
	initAttr(actor, roleId)
end

local function onStrongLevel(actor, roleId, posId, level)
	initAttr(actor, roleId)
end

local function onZhulingLevelup(actor, roleId, posId, level)
	initAttr(actor, roleId)
end

--初始化全局数据
local function initGlobalData()
	actorevent.reg(aeInit, onInit)
	actorevent.reg(aeAddEquiment, onEquipItem)
	actorevent.reg(aeStrongLevelChanged, onStrongLevel)
	actorevent.reg(aeUpgradeZhuling, onZhulingLevelup)
	
	netmsgdispatcher.reg(Protocol.CMD_Heirloom, Protocol.cHeirloomCmd_ReqCompose, reqCompose) --请求合成
	netmsgdispatcher.reg(Protocol.CMD_Heirloom, Protocol.cHeirloomCmd_ReqActive, reqActive) --请求激活
	netmsgdispatcher.reg(Protocol.CMD_Heirloom, Protocol.cHeirloomCmd_ReqLvUp, reqLvUp)--请求升级
end

table.insert(InitFnTable, initGlobalData)
