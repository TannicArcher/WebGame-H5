--新玉佩系统
module("jadeplatesystem", package.seeall)

--玩家静态数据
--[[
	[roleid] = {
 		level 当前等级
		exp   当前经验
		itemInfo = {
			[itemId] = 已使用次数
		}
	}
]]

--检测开启等级
function checkOpenLevel(actor)
	local level = LActor.getZhuanShengLevel(actor) * 1000
	level = level + LActor.getLevel(actor)
	if level < JadePlateBaseConfig.openlv then return false end

	local openDay = System.getOpenServerDay() + 1
	if openDay < JadePlateBaseConfig.openDay then return false end

	return true
end

local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if nil == var.jadeplate then var.jadeplate = {} end
	return var.jadeplate
end

--获取角色信息
local function getRoleData(actor, roleId)
	local var = getStaticData(actor)
	if not var[roleId] then var[roleId] = {} end

	return var[roleId]
end

--获取上一次升阶的等级
local function getUpgradeLevel(level)
	pl = JadePlateBaseConfig.perLevel
	local value = math.floor(level / pl)
	return value * pl
end

--获取当前可以使用提升丹的最大数量
local function getMaxCountByLevel(level, itemId)
	local lastLevel = getUpgradeLevel(level)
	if lastLevel and JadePlateLevelConfig[lastLevel] and JadePlateLevelConfig[lastLevel].upgradeItemInfo then
		return JadePlateLevelConfig[lastLevel].upgradeItemInfo[itemId] or 0
	end

	return 0
end

--检测是否需要升阶
local function checkNeedStageUp(level)
	pl = JadePlateBaseConfig.perLevel
	if (level-pl+1)%pl == 0 then return true end
	--[[ 阶级通项公式推倒过程,0级开始的情况
		0 - 1-2 -3- 4- 5- 6- 7- 8- 9->  10 = 10 + (1-1) * 11
		11-12-13-14-15-16-17-18-19-20-> 21 = 10 + (2-1) * 11
		22-23-24-25-26-27-28-29-30-31-> 32 = 10 + (3-1) * 11
		(当前等级 - N级每阶(10))/(N级每阶(9)+1) + 1 = 阶数
		0 --> 9  = 9 + (1 - 1) * 10 ==> 1 = (9-9)/10 + 1
		10--> 19 = 9 + (2 - 1) * 10 ==> 2 = (19-9)/10 + 1
		20--> 29 = 9 + (3 - 1) * 10 ==> 3 = (29-9)/10 + 1
		(当前等级 - N级每阶(9))/(N级每阶(9)+1) + 1 = 阶数
		得出:
		(当前等级 - N级每阶(9))%(N级每阶(9)+1) == 0 为需要升阶等级
		向上取整((当前等级 - N级每阶的配置) / (N级每阶的配置 + 1) + 1) = 阶数 (0阶开始的时候需要 阶数-1)
		当前等级 - (N级每阶的配置 + (阶数-2)*(N级每阶的配置+1) + 1) = 星数
		eq:
			(0-9)%(9+1) !== 0  (0-10)%(10+1) !== 0
			(9-9)%(9+1)  == 0  (32-10)%(10+1) == 0
	]]

	return false
end

local function writeData(data, npack)
	--先保存当前位置，后面再插入数据
	local oldPos = LDataPack.getPosition(npack)
	LDataPack.writeShort(npack, 0)

	if nil == data.itemInfo then data.itemInfo = {} end
	local count = 0
	for id, _ in pairs(JadePlateBaseConfig.upgradeInfo or {}) do
		if data.itemInfo[id] then
			LDataPack.writeInt(npack, id)
			LDataPack.writeShort(npack, data.itemInfo[id] or 0)
			count = count + 1
		end
	end

	local newPos = LDataPack.getPosition(npack)

    --往前面插入数据
	LDataPack.setPosition(npack, oldPos)
	LDataPack.writeShort(npack, count)
	LDataPack.setPosition(npack, newPos)
end

--下发数据
local function sendData(actor, roleId)
	local data = getRoleData(actor, roleId)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_JadePlate, Protocol.sJadePlateCmd_JadePlateData)
	LDataPack.writeShort(npack, roleId)
	LDataPack.writeShort(npack, data.level or 0)
	LDataPack.writeShort(npack, data.exp or 0)

	writeData(data, npack)

	LDataPack.flush(npack)
end

local function packJadePlateData(actor, roleId, npack)
	if not actor then return end
	if not roleId then return end
	if not npack then print("jadeplatesystem.packJadePlateData:npack nil, actorId:"..LActor.getActorId(actor)) return end

	local data = getRoleData(actor, roleId)
	LDataPack.writeShort(npack, data.level or 0)
end

_G.packJadePlateData = packJadePlateData

--玉佩属性
local function updateAttr(actor, roleId)
	local role = LActor.getRole(actor, roleId)
	if not role then return end

	local attr = LActor.getJadePlateAttr(actor, roleId)
	attr:Reset()

	local exAttr = LActor.getJadePlateExAttr(actor, roleId)
	if not exAttr then return end
	exAttr:Reset()

	local data = getRoleData(actor, roleId)

	--属性增加
	local conf = JadePlateLevelConfig[data.level or 0]
	if conf then
		for _, v in pairs(conf.attrs or {}) do attr:Add(v.type, v.value) end
		for _, v in pairs(conf.exAttrs or {}) do exAttr:Add(v.type, v.value) end

		if nil == data.itemInfo then data.itemInfo = {} end
		for id, cfg in pairs(JadePlateBaseConfig.upgradeInfo or {}) do
			if data.itemInfo[id] then
				local count = data.itemInfo[id] or 0

				--加固定值
				if cfg.attr then
					for _, v in pairs(cfg.attr or {}) do attr:Add(v.type, math.floor(v.value*count)) end
				end

				--加万分比
				if cfg.precent then
					for _, v in pairs(conf.attrs or {}) do attr:Add(v.type, math.floor(v.value*count*cfg.precent/10000)) end
				end
			end
		end

		--学习技能
		local lastLevel = getUpgradeLevel(data.level or 0)
		if lastLevel and JadePlateLevelConfig[lastLevel] and JadePlateLevelConfig[lastLevel].skillId then
			local cfg = JadePlateLevelConfig[lastLevel].skillId
			for _, id in pairs(cfg or {}) do LActor.AddPassiveSkill(role, id) end
		end

		LActor.reCalcAttr(role)
		LActor.reCalcExAttr(role)
	end
end

--升级
local function onAddExp(level, exp)
	local conf = JadePlateLevelConfig[level]
	while conf and exp >= conf.exp do
		exp = exp - conf.exp
		level = level + 1

		--要升阶就不继续升级了
		if true == checkNeedStageUp(level) then break end

		conf = JadePlateLevelConfig[level]
	end

	return level, exp
end

--请求使用提升丹
local function onUpgrate(actor, packet)
	local roleId = LDataPack.readShort(packet)
	local itemId = LDataPack.readInt(packet)
	local actorId = LActor.getActorId(actor)

	--id判断
	if roleId >= MAX_ROLE then print("jadeplatesystem.onUpgrate:roleId illegal, actorId:"..tostring(actorId)) return end

	--等级判断
	if false == checkOpenLevel(actor) then print("jadeplatesystem.onUpgrate:checkOpenLevel false, actorId:"..tostring(actorId)) return end

	--itemid是否适合
	if not JadePlateBaseConfig.upgradeInfo[itemId] then print("jadeplatesystem.onUpgrate:itemid illegal, actorId:"..tostring(actorId)) return end

	--角色是否存在
	local role = LActor.getRole(actor, roleId)
	if not role then print("jadeplatesystem.onUpgrate:role not exist, roleId:"..tostring(roleId)..", actorId:"..tostring(actorId)) return end

	local data = getRoleData(actor, roleId)

	--是否超过了最大使用数量限制
	if nil == data.itemInfo then data.itemInfo = {} end
	if (data.itemInfo[itemId] or 0) >= getMaxCountByLevel(data.level or 0, itemId) then
		print("jadeplatesystem.onUpgrate:count limit, count:"..tostring(data.itemInfo[itemId])..", actorId:"..tostring(actorId))
		return
	end

	--道具够不够
	if 1 > LActor.getItemCount(actor, itemId) then
		print("jadeplatesystem.onUpgrate:item not enough, itemId:"..tostring(itemId)..", actorId:"..tostring(actorId))
		return
	end

	LActor.costItem(actor, itemId, 1, "jadeplateupgrade")

	data.itemInfo[itemId] = (data.itemInfo[itemId] or 0) + 1

	sendData(actor, roleId)

	updateAttr(actor, roleId)
end

--请求升级玉佩
local function onLevelUp(actor, packet)
	local roleId = LDataPack.readShort(packet)
	local itemId = LDataPack.readInt(packet)
	local actorId = LActor.getActorId(actor)

	--id判断
	if roleId >= MAX_ROLE then print("jadeplatesystem.onLevelUp:roleId illegal, actorId:"..tostring(actorId)) return end

	--等级判断
	if false == checkOpenLevel(actor) then print("jadeplatesystem.onLevelUp:checkOpenLevel false, actorId:"..tostring(actorId)) return end

	--itemid是否适合
	if not JadePlateBaseConfig.itemInfo[itemId] then print("jadeplatesystem.onLevelUp:itemid illegal, actorId:"..tostring(actorId)) return end

	--角色是否存在
	local role = LActor.getRole(actor, roleId)
	if not role then print("jadeplatesystem.onLevelUp:role not exist, roleId:"..tostring(roleId)..", actorId:"..tostring(actorId)) return end

	local data = getRoleData(actor, roleId)
	local conf = JadePlateLevelConfig[data.level or 0]

	--是否已到最大级
	if #JadePlateLevelConfig <= (data.level or 0) then print("jadeplatesystem.onLevelUp:level max, actorId:"..tostring(actorId)) return end

	--是否到了升阶,升阶也就是不需要消耗材料升级
	if false == checkNeedStageUp(data.level or 0) then
		--道具够不够
		if 1 > LActor.getItemCount(actor, itemId) then
			print("jadeplatesystem.onLevelUp:item not enough, itemId:"..tostring(itemId)..", actorId:"..tostring(actorId))
			return
		end

		LActor.costItem(actor, itemId, 1, "jadeplatelevelup")

		--加经验
		data.exp = (data.exp or 0) + JadePlateBaseConfig.itemInfo[itemId]

		data.level, data.exp = onAddExp(data.level or 0, data.exp or 0)
	else
		data.level = (data.level or 0) + 1

		--升阶有可能会打断升级，所以升阶后再调用升级
		data.level, data.exp = onAddExp(data.level or 0, data.exp or 0)
	end

	sendData(actor, roleId)

	updateAttr(actor, roleId)
end

--初始化时候的回调
local function onInit(actor)
	if false == checkOpenLevel(actor) then return end
	for i=0, LActor.getRoleCount(actor) - 1 do updateAttr(actor, i) end
end

--登陆回调
local function onLogin(actor)
	if false == checkOpenLevel(actor) then return end
	for i=0, LActor.getRoleCount(actor) - 1 do sendData(actor, i) end
end

local function onCreateRole(actor, roleId)
	if false == checkOpenLevel(actor) then return end
	sendData(actor, roleId)
end

local function onActorLvChange(actor)
	if false == checkOpenLevel(actor) then return end
	for i=0, LActor.getRoleCount(actor) - 1 do
		updateAttr(actor, i)
		sendData(actor, i)
	end
end

--初始化
local function init()
	actorevent.reg(aeInit,onInit)
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeLevel, onActorLvChange)
	actorevent.reg(aeZhuansheng, onActorLvChange)
	actorevent.reg(aeCreateRole, onCreateRole)

	netmsgdispatcher.reg(Protocol.CMD_JadePlate, Protocol.cJadePlateCmd_UseItemUpgrate, onUpgrate)
	netmsgdispatcher.reg(Protocol.CMD_JadePlate, Protocol.cJadePlateCmd_LevelUp, onLevelUp)
end
table.insert(InitFnTable, init)


local gmsystem    = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.jadeplate = function(actor, args)
	local data = getRoleData(actor, tonumber(args[1]))
	data.level = tonumber(args[2])
	sendData(actor, tonumber(args[1]))
end
