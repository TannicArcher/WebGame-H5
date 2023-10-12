--
module("guildcommon", package.seeall)

local MAX_ROLE = 3

local systemId = Protocol.CMD_Guild

function getActorVar(actor)
	local actorVar = LActor.getStaticVar(actor)
	if actorVar.guild == nil then
		actorVar.guild = {}
	end
	return actorVar.guild
end


function getRoleVar(actor, roleId)
	if roleId < 0 or roleId >= MAX_ROLE then return nil end

	local roleIdx = roleId + 1

	local actorVar = LActor.getStaticVar(actor)

	local actorGuildVar = actorVar.guildrole
	if actorGuildVar == nil then
		actorVar.guildrole = {}
		actorGuildVar = actorVar.guildrole
	end

	if actorGuildVar[roleIdx] == nil then
		actorGuildVar[roleIdx] = {}
	end
	return actorGuildVar[roleIdx]
end

function sendBasicInfo(actor)
	local actorGuildVar = getActorVar(actor)

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_BasicInfo)
    LDataPack.writeInt(pack, actorGuildVar.contrib or 0)
    LDataPack.writeInt(pack, LActor.getTotalGx(actor))
    LDataPack.writeByte(pack, LActor.getGuildPos(actor))
    LDataPack.flush(pack)
end

-- 增加公会贡献
function changeContrib(actor, value, log)
	if value == 0 then return end

	local actorGuildVar = getActorVar(actor)
	local newValue = (actorGuildVar.contrib or 0) + value
	if newValue < 0 then
		newValue = 0
	end
	actorGuildVar.contrib = newValue
	LActor.log(actor, "guildcommon.changeContrib", "make1", actorGuildVar.contrib)

	if value > 0 then
		LActor.changeTotalGx(actor, value)
	end

	sendBasicInfo(actor)

	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)), "guild", tostring(value), tostring(newValue), "contrib", log or "")
end

function getContrib(actor)
	local actorGuildVar = getActorVar(actor)
	return actorGuildVar.contrib or 0
end

-- 重置玩家的公会贡献
function resetContrib(actor)
	local actorGuildVar = getActorVar(actor)
	actorGuildVar.contrib = 0
	-- LActor.setTotalGx(actor, 0)
end

-- 修改公会资金
function changeGuildFund(guild, value, actor, log)
	if value == 0 then return end

	local guildVar = LGuild.getStaticVar(guild, true)
	local newValue = (guildVar.fund or 0) + value
	if newValue < 0 then
		newValue = 0
	end
	guildVar.fund = newValue
	LActor.log(actor, "guildcommon.changeGuildFund", "make1", LGuild.getGuildId(guild), guildVar.fund)

	--资金有变动广播
	broadcastGuildFund(guild)

	local guildId = LGuild.getGuildId(guild)
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)), "guild", tostring(value), "", "guildfund", log or "", tostring(guildId))
end

function getGuildFund(guild)
	local guildVar = LGuild.getStaticVar(guild)
	if guildVar == nil then return 0 end

	return guildVar.fund or 0
end

function broadcastGuildFund(guild)
	local guildVar = LGuild.getStaticVar(guild)
	if not guildVar then return end

	local actors = LGuild.getOnlineActor(LGuild.getGuildId(guild))
	for i = 1, #(actors or {})  do
		local pack = LDataPack.allocPacket(actors[i], systemId, Protocol.sGuildCmd_FundChanged)
	    LDataPack.writeInt(pack, guildVar.fund or 0)
	    LDataPack.flush(pack)
	end
end

function broadcastBuildLevel(guild, buildingLevel, index)
	if not guild then return end
	local pack = LDataPack.allocBroadcastPacket(systemId, Protocol.sGuildCmd_UpgradeBuilding)
	if not pack then return end
	LDataPack.writeByte(pack, index)
	LDataPack.writeByte(pack, buildingLevel)
	LGuild.broadcastData(guild, pack)
end

-- 修改公会篝火
function changeGuildBonFire(guild, value, actor)
	if value == 0 then return end

	local guildVar = LGuild.getStaticVar(guild, true)
	guildVar.bonFireValue = (guildVar.bonFireValue or 0) + value
	local conf = GuildBonFireConfig[guildVar.bonFireLevel or 0]

	if conf.value <= guildVar.bonFireValue then
		guildVar.bonFireLevel = (guildVar.bonFireLevel or 0) + 1

		--做个最高等级限制
		if #GuildBonFireConfig < (guildVar.bonFireLevel or 0) then guildVar.bonFireLevel = #GuildBonFireConfig end

		guildVar.bonFireValue = guildVar.bonFireValue - conf.value
	end

	LActor.log(actor, "guildcommon.changeBonFireValue", "make1", LGuild.getGuildId(guild), guildVar.bonFireValue)

	if actor ~= nil then
		local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_bonFireUpdate)
		LDataPack.writeShort(pack, guildVar.bonFireLevel or 0)
	    LDataPack.writeInt(pack, guildVar.bonFireValue or 0)
	    LDataPack.flush(pack)
	end
end

--重置篝火值
function resetBonFire(guild)
	local guildVar = LGuild.getStaticVar(guild, true)
	if not guildVar then return end

	local conf = GuildBonFireConfig[guildVar.bonFireLevel or 0]
	if 0 < conf.reward then guildVar.fund = (guildVar.fund or 0) + (conf.reward or 0) end

	if 0 < (guildVar.bonFireLevel or 0) or 0 < (guildVar.bonFireValue or 0) then
		guildVar.bonFireValue = 0
		guildVar.bonFireLevel = 0

		local actors = LGuild.getOnlineActor(LGuild.getGuildId(guild))
		for i = 1, #(actors or {})  do
			local pack = LDataPack.allocPacket(actors[i], systemId, Protocol.sGuildCmd_bonFireUpdate)
			LDataPack.writeShort(pack, guildVar.bonFireLevel or 0)
		    LDataPack.writeInt(pack, guildVar.bonFireValue or 0)
		    LDataPack.flush(pack)
		end

		broadcastGuildFund(guild)
	end
end

function initGuild(guild, buildingLevels)
	local guildVar = LGuild.getStaticVar(guild, true)
	guildVar.building = {}
	guildVar.buildinglevelup = {}

	local buildingVar = guildVar.building
	local levelupVar = guildVar.buildinglevelup
	local nowtime = System.getNowTime()
	for i=1,#buildingLevels do
		buildingVar[i] = buildingLevels[i] or 1
		levelupVar[i] = nowtime
		System.log("guildcommon", "initGuild", "mark1", LGuild.getGuildId(guild), buildingVar[i], nowtime)
	end

	LGuild.setGuildLevel(guild, buildingVar[1], nowtime)
	LGuild.setGuildAffairLevel(guild, buildingVar[4])
	LGuild.updateGuildRank(guild)
end

function getBuildingLevel(guild, index)
	local guildVar = LGuild.getStaticVar(guild)
	local building = guildVar.building
	if building == nil then return 1 end

	return building[index] or 1
end

function updateBuildingLevel(guild, index, level)
	local guildVar = LGuild.getStaticVar(guild, true)

	if guildVar.building == nil then guildVar.building = {} end
	if guildVar.buildinglevelup == nil then guildVar.buildinglevelup = {} end

	local building = guildVar.building
	local levelup = guildVar.buildinglevelup

	building[index] = level
	levelup[index] = System.getNowTime()

	System.log("guildcommon", "updateBuildingLevel", "mark1", LGuild.getGuildId(guild), building[index], levelup[index], index)
	if index == 1 then
		LGuild.setGuildLevel(guild, level, levelup[index])
		LGuild.updateGuildRank(guild)
	elseif index == 4 then
		LGuild.setGuildAffairLevel(guild, level)
	end
end

function getGuildLevel(guild)
	return getBuildingLevel(guild, 1)
end

function initBuildingLevel(guild,buildingLevels)
	local guildVar = LGuild.getStaticVar(guild)

	--这个是后加的
	if guildVar.building == nil then guildVar.building = {} end
	if guildVar.buildinglevelup == nil then guildVar.buildinglevelup = {} end

	local buildingVar = guildVar.building
	local levelupVar = guildVar.buildinglevelup

	for i=1,#buildingLevels do
		buildingVar[i] = buildingVar[i] or buildingLevels[i] or 1
		levelupVar[i] = levelupVar[i] or 0
	end
	System.log("guildcommon", "initBuildingLevel", "mark1", LGuild.getGuildId(guild), buildingVar[1], levelupVar[1], buildingLevels)
	LGuild.setGuildLevel(guild, buildingVar[1] or 1, levelupVar[1] or 0)
	LGuild.setGuildAffairLevel(guild, buildingVar[4] or 0)
end

function gmRefreshGuildLevelUpTime(guild, time)
	local guildVar = LGuild.getStaticVar(guild, true)

	if guildVar.building == nil then guildVar.building = {} end
	if guildVar.buildinglevelup == nil then guildVar.buildinglevelup = {} end

	local building = guildVar.building
	local levelup = guildVar.buildinglevelup

	levelup[1] = time
	local level = building[1] or 1
	LGuild.setGuildLevel(guild, level, time)
	LGuild.updateGuildRank(guild)
end
