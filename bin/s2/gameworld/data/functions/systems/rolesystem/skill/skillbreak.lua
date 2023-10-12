module("skillbreak", package.seeall)

local Protocol = Protocol
local SkillsConfig = SkillsConfig
local SkillsBreakConf = SkillsBreakConf
local SkillsBreakUpgradeConfig = SkillsBreakUpgradeConfig

--最大等級
local SkillBreakLevelMax = 5

--判断是否达到技能突破开启
local function isOpenSkillBreak(actor, index)
	local st = System.getOpenServerStartDateTime()
	st = st + 172800 --2*24*60*60
	local now = System.getNowTime()
	if now < st then return false end

	local actorLevel = LActor.getLevel(actor)
	if actorLevel <= 0 then
		return false
	end
	return true
end

local function getRoleJobType(actor, roleid)
	if roleid < 0 or roleid >= 3 then
		return
	end
	local role = LActor.getRole(actor,roleid)
	if role == nil then return false end
	local jobType = LActor.getJob(role)
	if jobType <= JobType_None or jobType >= JobType_Max then
		return
	end
	return jobType
end

--判断技能突破索引范围
local function getConf(actor, jobType, index)
	local conf = SkillsBreakUpgradeConfig[jobType] and SkillsBreakUpgradeConfig[jobType][index]
	return conf
end

local function consumeItem(actor, itemid, count)
	if itemid == nil or count == nil then return false end
	if itemid == 0 or count == 0 then return false end
	local ret = LActor.consumeItem(actor, itemid, count, false,"skillbreak.consumeItem")
	return ret
end

--升级技能
local function upgradeSkill(actor, roleid, index)
	--判断是否足够等级学习节能突破
	if not isOpenSkillBreak(actor, index) then return end

	--检查子角色id 
	local jobType = getRoleJobType(actor, roleid)
	if not jobType then return end
	--取配置
	local conf = getConf(actor, jobType, index)
	if not conf then return end

	--判断是否等级已经最大
	local level = LActor.getRoleSkillBreakLevel(actor, roleid, index-1) --这里要减1，c++从0开始
	if level >= SkillBreakLevelMax then return end

	local curconf = conf[level+1]
	local itemid,count = curconf.itemid, curconf.count
	local itemidex,countex = curconf.itemidex, curconf.countex
	--扣道具
	if not (consumeItem(actor, itemidex, countex) or consumeItem(actor, itemid, count)) then return end
	--升級
	LActor.upgradeSkillBreak(actor, roleid, index-1)
	--
	local afterLevel = LActor.getRoleSkillBreakLevel(actor, roleid, index-1)
	-- print(string.format("aid: %d,roleid:%d ,before upgradeSkillBreak %d,after upgradeSkillBreak %d",LActor.getActorId(actor),roleid,level,afterLevel))
	LActor.log(actor, "skillbreak.upgradeSkill", "mark1", roleid, level, afterLevel, index-1)
	if curconf.notice ~= nil then
		local skillbreakid = jobType * 10000 + index * 1000 + level
		if SkillsBreakConf[skillbreakid] ~= nil then
			noticemanager.broadCastNotice( curconf.notice, LActor.getActorName(LActor.getActorId(actor)), SkillsConfig[skillbreakid].skinName )
		end
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_UpgradeSkillBreak)
	if npack == nil then return end
	LDataPack.writeShort(npack, roleid)
	LDataPack.writeShort(npack, index)
	LDataPack.writeShort(npack, afterLevel)
	LDataPack.flush(npack)
end

local function onReqUpgradeSkillBreak(actor, packet)
	local roleid = LDataPack.readShort(packet)
	local index = LDataPack.readShort(packet)

	upgradeSkill(actor, roleid, index)
end


netmsgdispatcher.reg(Protocol.CMD_Skill, Protocol.cSkillCmd_UpgradeSkillBreak, onReqUpgradeSkillBreak)

local gmsystem    = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.sku = function(actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeShort(pack, tonumber(args[1] or 0))
	LDataPack.writeShort(pack, tonumber(args[2] or 1))
	LDataPack.setPosition(pack, 0)
	onReqUpgradeSkillBreak(actor,pack)
	return true
end


