-- 公会技能

module("guildskill", package.seeall)

local LActor = LActor
local System = System
local LDataPack = LDataPack
local systemId = Protocol.CMD_Guild
local common = guildcommon
local SKILL_BUILDING_INDEX = 2 -- 练功房的建筑索引

local function updataAttrs(actor, roleId)
	local attrs = LActor.getGuildSkillAttrs(actor,roleId)
	if attrs == nil then return end

	local roleVar = common.getRoleVar(actor, roleId)

	attrs:Reset()
	
	local commonSkills = roleVar.commonSkills
	if commonSkills ~= nil then
		for skillIdx=1,#GuildCommonSkillConfig do
			local skillConfig = GuildCommonSkillConfig[skillIdx]
			local level = commonSkills[skillIdx] or 0
			local levelConfig = skillConfig[level]
			if levelConfig ~= nil then
				local attrsConfig = levelConfig.attrs
				for attrIdx=1,#attrsConfig do
					local attrConfig = attrsConfig[attrIdx]
					LActor.log(actor, "guildskill.updataAttrs", "make1", attrConfig.type, attrConfig.value)
					attrs:Add(attrConfig.type, attrConfig.value)
				end
			end
		end
	end

	local practiceSkills = roleVar.practiceSkills
	if practiceSkills ~= nil then
		for skillIdx=1,#GuildPracticeSkillConfig do
			local skillConfig = GuildPracticeSkillConfig[skillIdx]
			local practiceVar = practiceSkills[skillIdx]
			if practiceVar ~= nil then
				local level = practiceVar.level or 0
				local levelConfig = skillConfig[level]
				if levelConfig ~= nil then
					local attrsConfig = levelConfig.attrs
					for attrIdx=1,#attrsConfig do
						local attrConfig = attrsConfig[attrIdx]
						LActor.log(actor, "guildskill.updataAttrs", "make2", attrConfig.type, attrConfig.value)
						attrs:Add(attrConfig.type, attrConfig.value)
					end
				end
			end
		end
	end

	LActor.reCalcRoleAttr(actor, roleId)
end

-- 获取公会技能信息
function handleSkillInfo(actor, packet)
	local guild = LActor.getGuildPtr(actor)
	if guild == nil then return end

	local guildVar = LGuild.getStaticVar(guild)
	local buildingVar = guildVar.building or {}

	local roleNum = LActor.getRoleCount(actor)

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_SkillInfo)
	LDataPack.writeByte(pack, roleNum)

	for roleIdx=1,roleNum do
		local roleVar = common.getRoleVar(actor, roleIdx - 1)
		LDataPack.writeByte(pack, GuildConfig.commonSkillCount)
		local commonSkills = roleVar.commonSkills or {}
		for skillIdx=1,GuildConfig.commonSkillCount do
			LDataPack.writeInt(pack, commonSkills[skillIdx] or 0)
		end

		LDataPack.writeByte(pack, GuildConfig.practiceSkillCount)
		local practiceSkills = roleVar.practiceSkills or {}
		for skillIdx=1,GuildConfig.practiceSkillCount do
			local practiceVar = practiceSkills[skillIdx] or {}
			LDataPack.writeInt(pack, practiceVar.level or 0)
			LDataPack.writeInt(pack, practiceVar.exp or 0)
		end
	end
	LDataPack.flush(pack)
end

-- 升级技能
function handleUpgradeSkill(actor, packet)
	local roleId = LDataPack.readShort(packet) -- 角色ID
	local index = LDataPack.readByte(packet) -- 第几个技能，从1开始

	if roleId < 0 or roleId >= LActor.getRoleCount(actor) then
		print("upgrade guild common skill roleId error:"..roleId)
		return 
	end

	local skillConfig = GuildCommonSkillConfig[index]
	if skillConfig == nil then
		print("upgrade common skill index error:"..index)
		return 
	end 

	local guild = LActor.getGuildPtr(actor)
	if guild == nil then
		print("guild is nil")
		return 
	end

	local buildingLevel = common.getBuildingLevel(guild, SKILL_BUILDING_INDEX)

	local roleVar = common.getRoleVar(actor, roleId)
	if roleVar == nil then print("roleVar is nil") return end
	local commonSkills = roleVar.commonSkills
	if commonSkills == nil then
		roleVar.commonSkills = {}
		commonSkills = roleVar.commonSkills
	end

	-- 判断技能是否达到当前公会上限
	local levelLimit = GuildConfig.commonSkillLevels[buildingLevel] or 0
	local level = commonSkills[index] or 0 
	if level >= levelLimit then
		print("level limit")
		return 
	end

	local nextLevel = level + 1
	if nextLevel > #skillConfig then
		print("level limit2")
		return 
	end

	local nextLevelConfig = skillConfig[nextLevel]

	if LActor.getCurrency(actor, NumericType_Gold) < nextLevelConfig.money then
		print("no enough money")
		return 
	end
	if common.getContrib(actor) < nextLevelConfig.contribute then
		print("no enough contribute")
		return 
	end

	LActor.changeCurrency(actor, NumericType_Gold, -nextLevelConfig.money, "upgrade guild skill")
	common.changeContrib(actor, -nextLevelConfig.contribute, "UpgradeSkill")

	commonSkills[index] = nextLevel
	LActor.log(actor, "guildskill.handleUpgradeSkill", "make1", nextLevel, index)

	updataAttrs(actor, roleId)

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_UpgradeSkill)
	LDataPack.writeShort(pack, roleId)
    LDataPack.writeByte(pack, index)
    LDataPack.writeInt(pack, nextLevel)
    LDataPack.flush(pack)
    actorevent.onEvent(actor, aeGuildSkill, 1)
end

-- 修炼技能
function handlePracticeSkill(actor, packet)
	local roleId = LDataPack.readShort(packet) -- 角色ID
	local index = LDataPack.readByte(packet) -- 第几个技能，从1开始

	if roleId < 0 or roleId >= LActor.getRoleCount(actor) then
		print("upgrade guild practice skill roleId error:"..roleId)
		return 
	end

	local skillConfig = GuildPracticeSkillConfig[index]

	if skillConfig == nil then
		print("upgrade guild pracetice index error:"..index)
		return 
	end 

	local guild = LActor.getGuildPtr(actor)
	if guild == nil then
		print("guild is nil")
		return 
	end

	local buildingLevel = common.getBuildingLevel(guild, SKILL_BUILDING_INDEX)

	local roleVar = common.getRoleVar(actor, roleId)
	if roleVar == nil then print("roleVar is nil") return end
	local practiceSkills = roleVar.practiceSkills
	if practiceSkills == nil then
		roleVar.practiceSkills = {}
		practiceSkills = roleVar.practiceSkills
	end

	-- 判断技能是否达到当前公会上限
	local levelLimit = GuildConfig.practiceSkillLevels[buildingLevel] or 0
	local skillVar = practiceSkills[index]
	if skillVar == nil then
		practiceSkills[index] = {}
		skillVar = practiceSkills[index]
	end
	local level = skillVar.level or 0
	if level >= levelLimit then
		print("level limit")
		return 
	end

	local nextLevel = level + 1
	if nextLevel > #skillConfig then
		print("level limit2")
		return 
	end

	local nextLevelConfig = skillConfig[nextLevel]

	if LActor.getCurrency(actor, NumericType_Gold) < nextLevelConfig.money then
		print("no enough money")
		return 
	end
	if common.getContrib(actor) < nextLevelConfig.contribute then
		print("no enough contribute")
		return 
	end

	LActor.changeCurrency(actor, NumericType_Gold, -nextLevelConfig.money, "upgrade practice skill")
	common.changeContrib(actor, -nextLevelConfig.contribute, "PracticeSkill")

	local exp = skillVar.exp or 0
	exp = exp + nextLevelConfig.exp
	if exp >= nextLevelConfig.upExp then
		skillVar.level = level + 1
		exp = exp - nextLevelConfig.upExp
	end
	skillVar.exp = exp
	LActor.log(actor, "guildskill.handlePracticeSkill", "make1", skillVar.level, skillVar.exp, index)

	updataAttrs(actor, roleId)

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_PracticeBuilding)
	LDataPack.writeShort(pack, roleId)
    LDataPack.writeByte(pack, index)
    LDataPack.writeInt(pack, skillVar.level or 0)
    LDataPack.writeInt(pack, exp)
    LDataPack.writeInt(pack, nextLevelConfig.exp)
    LDataPack.flush(pack)
    actorevent.onEvent(actor, aeGuildSkill, 1)
end

function onLogin(actor)
end

function onInit(actor)
	local roleNum = LActor.getRoleCount(actor) 
	for roleIdx=1,roleNum do
		updataAttrs(actor, roleIdx - 1)
	end
end

function onCreateRole(actor, roleId)
	updataAttrs(actor, roleId)
end

function onGameInit()
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)
actorevent.reg(aeCreateRole,onCreateRole)
table.insert(InitFnTable, onGameInit)