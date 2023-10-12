module("systems.roots.rootssystem", package.seeall)
setfenv(1, systems.roots.rootssystem)
--[[
	灵根系统
--]]
local actormoney = require("systems.actorsystem.actormoney")
require("protocol") 
require("roots.roots")

local actorevent 	   = require("actorevent.actorevent")
local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local centerservermsg  = require("utils.net.centerservermsg")

local SystemId 			 = SystemId
local enRootSystemID	 = SystemId.enRootSystemID
local RootSystemProtocol = RootSystemProtocol
local System   			 = System
local LActor   			 = LActor
local Roots 			 = Roots

local LDataPack = LDataPack
local writeInt  = LDataPack.writeInt
local writeWord = LDataPack.writeWord
local writeData = LDataPack.writeData
local readData  = LDataPack.readData

local getIntProperty = LActor.getIntProperty
local sendTipmsg 	 = LActor.sendTipmsg
local ScriptTips 	 = Lang.ScriptTips

local maxlevel = Roots.levelmax	 --等级上限

-- Comments: 初始化灵根配置
local function initRootAttrConfig()
	System.clearAttrConfig(acRoot)
	local rootAttr = {}

	local attriType = Roots.levels[1].attri.type
	rootAttr[1] = {}
	
	local rootIdx = {}

	rootAttr[1][attriType] = Roots.levels[1].attri.value
	local idx = System.createAttr(acRoot)

	rootIdx[1] = idx

	System.setAttr(acRoot, idx, attriType, Roots.levels[1].attri.value)
	-- 遍历所有等级

	for curlevel=2, maxlevel  do	 

		rootAttr[curlevel] = {}

		for k,v in pairs(rootAttr[curlevel - 1]) do
			rootAttr[curlevel][k] = v
		end

		local attritype = Roots.levels[curlevel].attri.type
		local value = Roots.levels[curlevel].attri.value

		rootAttr[curlevel][attritype] = (rootAttr[curlevel][attritype] or 0) + value
		idx = System.createAttr(acRoot)
		rootIdx[curlevel] = idx
		for k,v in pairs(rootAttr[curlevel]) do
			System.setAttr(acRoot, idx, k, v)
		end
	end

	return rootIdx
end

local rootIdx = initRootAttrConfig()

-- Comments: 设置玩家某个等级的灵根属性
local function setActorAttr(actor,level)
	if actor == nil or level == nil then return end
	if rootIdx[level] == nil then return end

	local attr = System.getAttrList(acRoot, rootIdx[level])
	if attr == nil then return end

	LActor.resetCalc(actor, acRoot)
	LActor.setCalc(actor, acRoot, attr)
	LActor.refreshAbility(actor)
end

-- Comments: 登录处理
function onLogin(actor)
	if actor == nil then return end

	local sysvar = LActor.getSysVar(actor)
	if sysvar.rootsys == nil then
		if not LActor.isSysOpen(actor, siRoot) then return end
	
		sysvar.rootsys = {}
		local rootsys = sysvar.rootsys
		rootsys.level = 0

		print("root sys onOpenSys not executed...")	
	end

	local rootsys = sysvar.rootsys
	if rootsys.level == 0 then
		return
	end

	local level = rootsys.level
	setActorAttr(actor, level)
end

-- Comments: 发送灵根信息
local function sendRootData(actor, rootdata, sysid, subsysid, levelUp, actorid)
	if rootdata == nil or sysid == nil or subsysid == nil then return end

	if not actor and not actorid then return end

	local packet
	if actor then
		packet = LDataPack.allocPacket(actor, sysid, subsysid)	
		if not packet then return end
	elseif actorid then
		packet = LDataPack.allocActorServerPacket(actorid, sysid, subsysid)
		if not packet then return end
		LDataPack.writeInt(packet, actorid)
	end
	writeInt(packet, rootdata)
	LDataPack.writeChar(packet, levelUp or 0)
		
	if actor then
		LDataPack.flush(packet)
	else
		System.sendDataToActorServer(packet)
	end
end


-- Comments: 系统开启
function onOpenSys(actor, sysId)
	if actor == nil or sysId == nil then return end 

	if sysId ~= siRoot then 
		return
	end

	local sysvar = LActor.getSysVar(actor)
	if sysvar == nil then return end
	
	sysvar.rootsys = {}
	local rootsys = sysvar.rootsys
	rootsys.level = 0
	sendRootData(actor, rootsys.level, enRootSystemID, RootSystemProtocol.sRootData)
end

-- Comments: 获取灵根信息
function processGetRootInfo(actor)
	local sysvar  = LActor.getSysVar(actor)
	if sysvar == nil then return end
	local rootsys = sysvar.rootsys
	if rootsys == nil or rootsys.level == nil then return end

	sendRootData(actor, rootsys.level, enRootSystemID, RootSystemProtocol.sRootData)
end

-- Comments: 查看其他人灵根
function processGetOtherRootInfo(actor, packet)
	local other_id, other_name = readData(packet, 2, dtInt, dtString)

	local other_actor = System.getEntityPtrByActorID(other_id)
	if not other_actor then
		local pack = LDataPack.allocActorServerPacket(other_id, enRootSystemID, RootSystemProtocol.CenterSrvCmd.cOtherRootData)
		if not pack then return end
		LDataPack.writeData(pack, 3, dtInt, LActor.getActorId(actor), dtInt, other_id, dtString, other_name)
		System.sendDataToActorServer(pack)
		return
	end

	local sysvar = LActor.getSysVar(other_actor)
	if sysvar == nil then return end
	local rootsys = sysvar.rootsys
	if rootsys == nil or rootsys.level == nil then return end
	
	sendRootData(actor, rootsys.level, enRootSystemID, RootSystemProtocol.sOtherRootData)
end

function recvGetOtherRootInfo(packet)
	local actorid, other_id, other_name = LDataPack.readData(packet, 3, dtInt, dtInt, dtString)

	local other_actor = LActor.getActorById(other_id)
	if not other_actor then return end

	local sysvar = LActor.getSysVar(other_actor)
	if sysvar == nil then return end
	local rootsys = sysvar.rootsys
	if rootsys == nil or rootsys.level == nil then return end

	sendRootData(nil, rootsys.level, enRootSystemID, RootSystemProtocol.CenterSrvCmd.sOtherRootData, 0, actorid)
end

function retGetOtherRootInfo(packet)
	local actorid = LDataPack.readInt(packet)

	local actor = LActor.getActorById(actorid)
	if not actor then return end

	local pack = LDataPack.allocPacket(actor, enRootSystemID, RootSystemProtocol.sOtherRootData)
	if not pack then return end

	LDataPack.writePacket(pack, packet, false)

	LDataPack.flush(pack)
end

-- Comments: 灵根升级
function processUpRootLevel(actor)
	local sysvar = LActor.getSysVar(actor)
	if sysvar.rootsys == nil then return end
	local rootsys = sysvar.rootsys
	local level = rootsys.level + 1

	if level < 0 or level > maxlevel then
		sendTipmsg(actor, ScriptTips.root005, ttMessage)
		return 
	end

	local roots = Roots.levels[level]

	if roots == nil then return end
	local need_money_type = mtBindCoin

	local need_root_exp, need_money_cost = roots.expr, roots.coin
	if need_root_exp == nil or need_money_cost == nil then return end
	
	local root_exp = getIntProperty(actor, P_ROOT_EXP)
	if need_root_exp > root_exp then
		sendTipmsg(actor, ScriptTips.root003, ttMessage) --灵气不足公告	
		return
	end
	if need_money_cost > actormoney.getMixMoney(actor, need_money_type) then
		sendTipmsg(actor, ScriptTips.root004, ttMessage) --银币不足公告		 
		return
	end
	LActor.setIntProperty(actor, P_ROOT_EXP, root_exp - need_root_exp)
	actormoney.consumeMoney(actor, need_money_type, -need_money_cost, 1, true, "root", "level_up")

	rootsys.level = rootsys.level + 1

	setActorAttr(actor, level)		--属性计算
	sendRootData(actor, rootsys.level, enRootSystemID, RootSystemProtocol.sRootData, 1)

	--激活星图，参数1表示激活到哪个阶段
	LActor.triggerAchieveEvent(actor, aAchieveEventRoot, rootsys.level)

	if roots.broa then
		local str = string.format(ScriptTips.rootb01, LActor.getActorLink(actor), roots.broa)
		System.broadcastLevelTipmsg(str, Roots.openlvl, ttScreenCenter)
		str = str..ScriptTips.rootb02
		System.broadcastLevelTipmsg(str, Roots.openlvl, ttHearsay)
	end

	--记录日志
	local fightval = LActor.getAttrScore(actor,acRoot)
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), 
		tostring(LActor.getLevel(actor)), 
		"root_levelup", "old_level" .. (rootsys.level - 1), "",
		"new_level" .. rootsys.level, "root_fightval".. fightval, "", "",
		"rootsystem", lfBI)

end

--实体事件
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeOpenSys, onOpenSys)

--协议事件
netmsgdispatcher.reg(enRootSystemID, RootSystemProtocol.cRootData, processGetRootInfo)
netmsgdispatcher.reg(enRootSystemID, RootSystemProtocol.cLevelUp,  processUpRootLevel)
netmsgdispatcher.reg(enRootSystemID, RootSystemProtocol.cOtherRootData, processGetOtherRootInfo)

centerservermsg.reg(enRootSystemID, RootSystemProtocol.CenterSrvCmd.cOtherRootData, recvGetOtherRootInfo)
centerservermsg.reg(enRootSystemID, RootSystemProtocol.CenterSrvCmd.sOtherRootData, retGetOtherRootInfo)
