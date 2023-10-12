--兵魂系统
module("weaponsoulsystem", package.seeall)

--[[玩家数据定义
data={
	[role_id] = {
		pos={ --部位等级
			[部位ID]=等级
		},
		wsact = {--兵魂激活
			[兵魂ID] =1
		}
		itemact = { --兵魂之灵的激活ID
			[兵魂ID] = 1
		}
		uitemNum = 0 --使用了兵魂之灵的个数
	}
}
]]
--获取静态数据
local function getData(actor)
	local data = LActor.getStaticVar(actor)
	if nil == data then return nil end
	if nil == data.weaponsoulsystem then data.weaponsoulsystem = {} end

	return data.weaponsoulsystem
end

--获取指定角色ID的数据
local function getRoleData(actor, role_id)
	local data = getData(actor)
	if not data[role_id] then data[role_id] = {} end
	return data[role_id]
end

--获取指定角色ID的部位等级
local function getRolePosLevel(actor, role_id, id)
	local data = getRoleData(actor, role_id)
	if not data.pos then return 0 end
	return data.pos[id] or 0
end

--设置指定角色ID的部位等级
local function setRolePosLevel(actor, role_id, id, lv)
	local data = getRoleData(actor, role_id)
	if not data.pos then data.pos = {} end
	data.pos[id] = lv
end

--下发初始化角色数据
local function SendRoleWeaponSoulsData(actor, role_id)
	local roleData = getRoleData(actor, role_id)
	if not roleData then return end
	local npack =  LDataPack.allocPacket(actor, Protocol.CMD_WeaponSoul, Protocol.sWeaponSoulCmd_DataInfo)
	LDataPack.writeByte(npack, role_id)
	--部位信息
	local count = 0
	local pos = LDataPack.getPosition(npack)
	LDataPack.writeShort(npack, count)
	for id,cfg in pairs(WeaponSoulPosConfig) do 
		if roleData.pos and roleData.pos[id] then
			LDataPack.writeShort(npack, id)
			LDataPack.writeInt(npack, roleData.pos[id])
			count = count + 1
		end
	end
	local pos2 = LDataPack.getPosition(npack)
	LDataPack.setPosition(npack, pos)
	LDataPack.writeShort(npack, count)
	LDataPack.setPosition(npack, pos2)
	--激活信息
	count = 0
	pos = LDataPack.getPosition(npack)
	LDataPack.writeShort(npack, count)
	for id,cfg in pairs(WeaponSoulConfig) do
		if roleData.wsact and roleData.wsact[id] then
			LDataPack.writeShort(npack, id)
			count = count + 1
		end
	end
	pos2 = LDataPack.getPosition(npack)
	LDataPack.setPosition(npack, pos)
	LDataPack.writeShort(npack, count)
	LDataPack.setPosition(npack, pos2)

	--兵魂之灵的激活信息
	count = 0
	pos = LDataPack.getPosition(npack)
	LDataPack.writeShort(npack, count)
	for id,cfg in pairs(WeaponSoulConfig) do
		if roleData.itemact and roleData.itemact[id] then
			LDataPack.writeShort(npack, id)
			count = count + 1
		end
	end
	pos2 = LDataPack.getPosition(npack)
	LDataPack.setPosition(npack, pos)
	LDataPack.writeShort(npack, count)
	LDataPack.setPosition(npack, pos2)
	
	LDataPack.writeShort(npack, roleData.uitemNum or 0)

	LDataPack.flush(npack)
end

--下发兵魂之灵信息
local function SendWeaponSoulsItemData(actor, role_id)
	local roleData = getRoleData(actor, role_id)
	local npack =  LDataPack.allocPacket(actor, Protocol.CMD_WeaponSoul, Protocol.sWeaponSoulCmd_ItemDataInfo)
	LDataPack.writeChar(npack, role_id)
	LDataPack.writeShort(npack, roleData.uitemNum or 0)
	LDataPack.flush(npack)
end

--计算属性
local function initAttr(actor, role_id)
	local role = LActor.getRole(actor, role_id)
	if role == nil then return end
	local attr = LActor.GetWeaponSoulAttrs(actor, role_id)
	if not attr then return end
	attr:Reset()
	local exattr = LActor.GetWeaponSoulExAttrs(actor, role_id)
	if not exattr then return end
	exattr:Reset()
	local roleData = getRoleData(actor, role_id)
	if not roleData then return end
	--加所有部位属性
	if roleData.pos then
		for id,cfg in pairs(WeaponSoulPosConfig) do 
			if roleData.pos[id] then
				local config = cfg[roleData.pos[id]]
				for _,v in ipairs(config.attr or {}) do
					attr:Add(v.type, v.value)
				end
				for _,v in ipairs(config.ex_attr or {}) do
					exattr:Add(v.type, v.value)
				end	
			end
		end
	end
	
	--套装属性
	local uid = LActor.getUseingWeaponSoulId(actor, role_id)
	for wid,cfg in pairs(WeaponSoulConfig) do
		if ((roleData.uitemNum or 0) == 0 and wid == uid) --未激活道具的时候
		 	or ((roleData.uitemNum or 0) ~= 0 and roleData.itemact and roleData.itemact[wid]) then
			--求最小等级
			local minLv = 999999
			for _,pid in ipairs(cfg.actcond or {}) do
				local lv = roleData.pos and roleData.pos[pid] or 0
				if lv < minLv then minLv = lv end
			end
			--获取套装配置
			local suitCfg = nil
			if minLv > 0 then
				for slv, conf in pairs(WeaponSoulSuit[wid] or {}) do
					if slv <= minLv and ( not suitCfg or suitCfg.level < slv) then
						suitCfg = conf
					end
				end
			else
				suitCfg = WeaponSoulSuit[wid] and WeaponSoulSuit[wid][0]
			end
			--存在这个套装
			if suitCfg then
				for _,v in ipairs(suitCfg.attr or {}) do
					attr:Add(v.type, v.value)
				end
				for _,v in ipairs(suitCfg.ex_attr or {}) do
					exattr:Add(v.type, v.value)
				end	
				attr:SetExtraPower(suitCfg.power or 0)
			end
		end
	end
	
	--兵魂之灵道具个数属性
	if roleData.uitemNum then
		local cfg = WeaponSoulItemAttr[roleData.uitemNum]
		if cfg then
			for _,v in ipairs(cfg.attr or {}) do
				attr:Add(v.type, v.value)
			end	
		end
	end

	LActor.reCalcAttr(role)
	LActor.reCalcExAttr(role)
end

--请求使用兵魂之灵
local function reqUseItem(actor, packet)
	local role_id = LDataPack.readByte(packet)
	if role_id < 0 and role_id > (LActor.getRoleCount(actor) -1) then
		print(LActor.getActorId(actor).." weaponsoulsystem.reqUseItem error role_id:"..role_id)
		return
	end
	local roleData = getRoleData(actor, role_id)
	--判断最大使用个数
	if (roleData.uitemNum or 0) >= WeaponSoulBaseConfig.maxItemNum then
		print(LActor.getActorId(actor).." weaponsoulsystem.reqUseItem is max role_id:"..role_id)
		return
	end
	--判断道具数量
	if LActor.getItemCount(actor, WeaponSoulBaseConfig.itemid) <= 0 then
		print(LActor.getActorId(actor).." weaponsoulsystem.reqUseItem not have item")
		return
	end
	--扣除道具
	LActor.costItem(actor, WeaponSoulBaseConfig.itemid, 1, "weap item "..role_id)
	--增加次数
	roleData.uitemNum = (roleData.uitemNum or 0) + 1
	--刷属性
	initAttr(actor, role_id)
	--回应客户端
	SendWeaponSoulsItemData(actor, role_id)
end

--请求激活升级突破部位
local function reqLevelUpPos(actor, packet)
	local role_id = LDataPack.readByte(packet)
	local id = LDataPack.readShort(packet)
	--部位配置
	local config = WeaponSoulPosConfig[id]
	if not config then 
		print(LActor.getActorId(actor).." weaponsoulsystem.reqLevelUpPos poscfg is nil, id:"..id)
		return
	end
	--获取角色ID的部位的等级
	local pos_lv = getRolePosLevel(actor, role_id, id)
	--判断是否满级
	if not config[pos_lv + 1] then 
		print(LActor.getActorId(actor).." weaponsoulsystem.reqLevelUpPos is maxLv, id:"..id.." pos_lv:"..tostring(pos_lv))
		return
	end
	--获取当前等级配置
	local lvCfg = config[pos_lv]
	if not lvCfg then 
		print(LActor.getActorId(actor).." weaponsoulsystem.reqLevelUpPos lvCfg is nil, id:"..id.." pos_lv:"..tostring(pos_lv))
		return
	end
	--检测道具是否足够
	local count = LActor.getItemCount(actor, lvCfg.costItem)
	if count < lvCfg.costNum then
		print(LActor.getActorId(actor).." weaponsoulsystem.reqLevelUpPos not enough cost, id:"..id.." pos_lv:"..tostring(pos_lv))
		return
	end
	--扣除消耗
	LActor.costItem(actor, lvCfg.costItem, lvCfg.costNum, "weaponsoul pos lvup")
	--设置等级
	setRolePosLevel(actor, role_id, id, pos_lv+1)
	initAttr(actor, role_id)
	--下发消息给客户端
	local npack =  LDataPack.allocPacket(actor, Protocol.CMD_WeaponSoul, Protocol.sWeaponSoulCmd_PosInfo)
	LDataPack.writeByte(npack, role_id)
	LDataPack.writeShort(npack, id)
	LDataPack.writeInt(npack, pos_lv+1)
	LDataPack.flush(npack)
end

--请求激活兵魂
local function reqActiveWs(actor, packet)
	local role_id = LDataPack.readByte(packet)
	local id = LDataPack.readShort(packet)
	--获取配置
	local cfg = WeaponSoulConfig[id]
	if not cfg then
		print(LActor.getActorId(actor).." weaponsoulsystem.reqActiveWs cfg is nil, id:"..id)
		return
	end
	--获取玩家数据
	local roleData = getRoleData(actor, role_id)
	if not roleData then
		print(LActor.getActorId(actor).." weaponsoulsystem.reqActiveWs roleData is nil, role_id:"..role_id)
		return
	end
	--判断是否已经激活
	if roleData.wsact and roleData.wsact[id] then
		print(LActor.getActorId(actor).." weaponsoulsystem.reqActiveWs is acted, role_id:"..role_id)
		return
	end
	if not roleData.pos then 
		return
	end
	--判断是否已经装备了所有部位
	for _,pid in ipairs(cfg.actcond or {}) do
		if not roleData.pos[pid] then
			print(LActor.getActorId(actor).." weaponsoulsystem.reqActiveWs actcond, role_id:"..role_id..", pid:"..pid)
			return
		end
	end
	--标记为激活
	if not roleData.wsact then roleData.wsact = {} end
	roleData.wsact[id] = 1
	initAttr(actor, role_id)
	--回应客户端
	local npack =  LDataPack.allocPacket(actor, Protocol.CMD_WeaponSoul, Protocol.sWeaponSoulCmd_ActiveInfo)
	LDataPack.writeByte(npack, role_id)
	LDataPack.writeShort(npack, id)
	LDataPack.flush(npack)	
end

--请求使用兵魂
local function reqUsedWs(actor, packet)
	local role_id = LDataPack.readByte(packet)
	local id = LDataPack.readShort(packet)
	if id ~= 0 then
		--获取配置
		local cfg = WeaponSoulConfig[id]
		if not cfg then
			print(LActor.getActorId(actor).." weaponsoulsystem.reqUsedWs cfg is nil, id:"..id)
			return
		end
		--获取玩家数据
		local roleData = getRoleData(actor, role_id)
		if not roleData then
			print(LActor.getActorId(actor).." weaponsoulsystem.reqUsedWs roleData is nil, role_id:"..role_id)
			return
		end
		--判断是否已经激活
		if not roleData.wsact or not roleData.wsact[id] then
			print(LActor.getActorId(actor).." weaponsoulsystem.reqUsedWs is not act, role_id:"..role_id)
			return
		end
	end
	--标记为使用该兵魂
	LActor.setUseingWeaponSoulId(actor, role_id, id)
	initAttr(actor, role_id)
	--回应客户端
	local npack =  LDataPack.allocPacket(actor, Protocol.CMD_WeaponSoul, Protocol.sWeaponSoulCmd_UsedInfo)
	LDataPack.writeByte(npack, role_id)
	LDataPack.writeShort(npack, id)
	LDataPack.flush(npack)	
end

local OpType = {
	use = 0,
	cancel = 1,
}
--激活兵魂之灵兵魂
local function reqItemAct(actor, packet)
	local role_id = LDataPack.readByte(packet)
	local op = LDataPack.readByte(packet)
	local id = LDataPack.readShort(packet)
	if not WeaponSoulConfig[id] then return end
	if op == OpType.use then
		--获取玩家数据
		local roleData = getRoleData(actor, role_id)
		--判断是否有使用过道具
		if not roleData.uitemNum then 
			print(LActor.getActorId(actor).." weaponsoulsystem.reqItemAct not use item, role_id:"..role_id)
			return
		end
		--获取已经使用了的数量
		local count = 0
		for id,_ in pairs(WeaponSoulConfig) do
			if roleData.itemact and roleData.itemact[id] then
				count = count + 1
			end
		end
		--判断是否有足够数量
		if roleData.uitemNum + 1 <= count then
			print(LActor.getActorId(actor).." weaponsoulsystem.reqItemAct is max num, role_id:"..role_id)
			return
		end
		--直接激活指定的ID
		if not roleData.itemact then roleData.itemact = {} end
		roleData.itemact[id] = 1
	else
		local roleData = getRoleData(actor, role_id)
		if not roleData.itemact then 
			print(LActor.getActorId(actor).." weaponsoulsystem.reqItemAct not roleData.itemact, role_id:"..role_id)
			return
		end
		roleData.itemact[id] = nil
	end
	initAttr(actor, role_id)
	--回应客户端
	local npack =  LDataPack.allocPacket(actor, Protocol.CMD_WeaponSoul, Protocol.sWeaponSoulCmd_ItemActInfo)
	LDataPack.writeByte(npack, role_id)
	LDataPack.writeByte(npack, op)
	LDataPack.writeShort(npack, id)
	LDataPack.flush(npack)	
end

--初始化回调
local function onInit(actor)
	for i=0,LActor.getRoleCount(actor) -1 do
		initAttr(actor, i)
	end
end

--登陆回调
local function onLogin(actor)
	for i=0,LActor.getRoleCount(actor) -1 do
		SendRoleWeaponSoulsData(actor, i)
	end
end

--创建新角色的时候
local function onCreateRole(actor, roleId)
	for i=0,LActor.getRoleCount(actor) -1 do
		SendRoleWeaponSoulsData(actor, i)
	end
end

--初始化全局数据
local function initGlobalData()
	actorevent.reg(aeInit, onInit)
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeCreateRole, onCreateRole)
	
	netmsgdispatcher.reg(Protocol.CMD_WeaponSoul, Protocol.cWeaponSoulCmd_ReqLevelUp, reqLevelUpPos) --请求激活升级突破部位
	netmsgdispatcher.reg(Protocol.CMD_WeaponSoul, Protocol.cWeaponSoulCmd_ReqActive, reqActiveWs) --请求激活兵魂
	netmsgdispatcher.reg(Protocol.CMD_WeaponSoul, Protocol.cWeaponSoulCmd_ReqUsed, reqUsedWs) --请求使用兵魂
	netmsgdispatcher.reg(Protocol.CMD_WeaponSoul, Protocol.cWeaponSoulCmd_ReqItemAct, reqItemAct) --请求激活的兵魂(兵魂之灵)
	netmsgdispatcher.reg(Protocol.CMD_WeaponSoul, Protocol.cWeaponSoulCmd_ReqUseItem, reqUseItem) --请求使用兵魂之灵
end

table.insert(InitFnTable, initGlobalData)