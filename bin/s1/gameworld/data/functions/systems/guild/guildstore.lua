-- 公会商店
module("guildstore", package.seeall)

local LActor = LActor
local LDataPack = LDataPack
local LGuild = LGuild

local guildStoreIndex = 3  -- 公会商店索引
local logType = 9          --guildsystem.GuildLogType.ltStore


local function getGuildStoreLevel(actor)
	local guild = LActor.getGuildPtr(actor)
	if guild == nil then return -1 end

	local storeLevel = guildcommon.getBuildingLevel(guild, guildStoreIndex)
	return storeLevel
end

local function initVar(actor, var)
	var.lastGuildId = LActor.getGuildId(actor)
	local storeLevel = getGuildStoreLevel(actor)
	var.lastTime = GuildStoreConfig.time[storeLevel] or 0
	var.curDayTime = 0
	var.sumTime = var.sumTime or GuildStoreConfig.initTime
end

local function getGuildStoreVar(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then
        return nil
    end

    if var.guildstoreVare == nil then
        var.guildstoreVare = {}
        var.guildstoreVare.lastGuildId = 0 --上一个公会id
        var.guildstoreVare.lastTime = 0 --上一个公会次数
        var.guildstoreVare.curDayTime = 0 --当天已用次数
        var.guildstoreVare.sumTime = GuildStoreConfig.initTime    --已用次数统计

        initVar(actor, var.guildstoreVare)
    end
    return var.guildstoreVare
end

local function isOpen(actor)
	if System.getOpenServerDay() + 1 < GuildStoreConfig.day then
		return false
	end
	return true
end

local function getGuildStoreConfDayTime(actor)
	local var = getGuildStoreVar(actor)
	if var == nil then return 0 end

	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then return end

	if var.lastGuildId ~= 0 and var.lastGuildId ~= guildId then
		return var.lastTime
	end

	local storeLevel = getGuildStoreLevel(actor)
	return GuildStoreConfig.time[storeLevel] or 0
end

-- 
local function handleGetCommInfo(actor, packet)
	local var = getGuildStoreVar(actor)
	if var == nil then return end

	local storeLevel = getGuildStoreLevel(actor)
	if storeLevel == -1 then return end

	local confTime = getGuildStoreConfDayTime(actor)
	local dayTime = confTime - var.curDayTime
	if dayTime < 0 then dayTime = 0 end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_GuildStore, Protocol.sGuildStoreCmd_CommInfo)
	if pack == nil then return end
	LDataPack.writeData(pack, 2,
						dtByte, storeLevel,
						dtByte, dayTime)
	LDataPack.flush(pack)
	-- print("===============",var.lastGuildId,var.lastTime,storeLevel,confTime,var.curDayTime,dayTime)
end

-- 获取记录
local function handleGetLog(actor, packet)
	local lastTime = LDataPack.readUInt(packet)

	local guild = LActor.getGuildPtr(actor)
	if guild == nil then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_GuildStore, Protocol.sGuildStoreCmd_Log)
	LGuild.writeStoreLog(guild, lastTime, pack)
	LDataPack.flush(pack)
end

local function getdropGroupId(actor,var)
	local level = 0 
	if LActor.getZhuanShengLevel(actor) ~= 0 then 
		level = LActor.getZhuanShengLevel(actor) * 1000
	else 
		level = LActor.getLevel(actor)
	end

	local config = GuildStoreLevelConfig[level]
	if config == nil or not next(config) then 
		print("not level config " .. level);
		return 0
	end
	local index = 0
	for i,v in pairs(config.cumulativeDropGroupId) do 
		if math.floor(var.sumTime % v.count) == 0 then 
			index = i
		end
	end

	if index == 0 then
		return config.dropGroupId
	else 
		return config.cumulativeDropGroupId[index].dropGroupId
	end
end

local function sendAwardList(actor, awardList)
	local guild = LActor.getGuildPtr(actor)
	if guild == nil then return end

	local itemList = {}
	for _,tb in pairs(awardList) do
		LActor.giveAward(actor, tb.type, tb.id, tb.count, "guildstore handleUnpack")
		if tb.type ~= AwardType_Numeric then
			table.insert(itemList, tb)
        end
        if tb.type == AwardType_Item and ItemConfig[tb.id] and ItemConfig[tb.id].quality >= 4 then
        	-- 追加公会事件
        	LGuild.addGuildLog(guild, logType, LActor.getName(actor),"", tb.id)
        	-- 公会频道
			local tips = string.format("[%s]在公会商店开启了玛法宝箱，获得极品道具[%s]", LActor.getName(actor), ItemConfig[tb.id].name)
			guildchat.sendNotice(guild, tips)
			-- 追加记录
			local time = System.getNowTime() - 1
			LGuild.addStoreLog(guild, actor, tb.id)
			-- 同步客户端记录
			local p = LDataPack.allocPacket(actor, Protocol.CMD_GuildStore, Protocol.sGuildStoreCmd_Log)
			LGuild.writeStoreLog(guild, time, p)
			LDataPack.flush(p)
        end
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_GuildStore, Protocol.sGuildStoreCmd_Unpack)
	if pack == nil then return end

	LDataPack.writeByte(pack, #itemList)
	for _,tb in ipairs(itemList) do
		LDataPack.writeData(pack, 2,
							dtInt, tb.id,
							dtInt, tb.count)
	end
	LDataPack.flush(pack)
end

-- 开箱
local function handleUnpack(actor, packet)
	if not isOpen() then return end

	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then return end
	
	local var = getGuildStoreVar(actor)
	if var == nil then return end

	local confTime = getGuildStoreConfDayTime(actor)
	local dayTime = confTime - var.curDayTime
	if dayTime <= 0 then
		LActor.sendTipmsg(actor, string.format("次数不足"), ttScreenCenter)
		return
	end

	local needContrib = GuildStoreConfig.needContrib
	local haveContrib = guildcommon.getContrib(actor)
	if needContrib > haveContrib then
		LActor.sendTipmsg(actor, string.format("贡献不足"), ttScreenCenter)
		return
	end

	local dropGroupId = getdropGroupId(actor,var)
	if DropGroupConfig[dropGroupId] == nil then return end

	if LActor.getEquipBagSpace(actor) < #DropGroupConfig[dropGroupId] then
		LActor.sendTipmsg(actor, string.format("背包空间不足"), ttScreenCenter)
		return
	end

	
	local awardList = drop.dropGroup(dropGroupId)
	if awardList == nil or next(awardList) == nil then return end
	
	if not LActor.canGiveAwards(actor, awardList) then
		LActor.sendTipmsg(actor, string.format("背包空间不足"), ttScreenCenter)
		return
	end

	--扣贡献，下发道具
	guildcommon.changeContrib(actor,-needContrib, "store")
	var.curDayTime = var.curDayTime + 1
	var.sumTime = var.sumTime + 1
	LActor.log(actor, "guildstore.handleUnpack", "make1", var.curDayTime, var.sumTime)
	sendAwardList(actor,awardList)
end

local function onNewDay(actor, login)
	local var = getGuildStoreVar(actor)
	if var == nil then return end

	local guildId = LActor.getGuildId(actor)
	--零点重置次数
	var.curDayTime = 0

	--公会当天零点重置
	if guildId ~= var.lastGuildId then
		initVar(actor, var)
		return 
	end
end

local function onJoinGuild(actor)
	local var = getGuildStoreVar(actor)
	if var == nil then return end

	if var.lastGuildId == 0 then
		initVar(actor, var)
		return
	end

	--
	local storeLevel = getGuildStoreLevel(actor)
	local curConfTime = GuildStoreConfig.time[storeLevel] or 0
	if curConfTime > var.lastTime then return end
	var.lastTime = curConfTime
	LActor.log(actor, "guildstore.onJoinGuild", "make1", var.lastTime)
end

local function onLeftGuild(actor)
	local var = getGuildStoreVar(actor)
	if var == nil then return end

	local oldGuild = LGuild.getGuildById(var.lastGuildId or 0)
	if oldGuild == nil then return end
	local oldStoreLevel = guildcommon.getBuildingLevel(oldGuild, guildStoreIndex)
	local lastTime = GuildStoreConfig.time[oldStoreLevel] or 0
	var.lastTime = lastTime
	LActor.log(actor, "guildstore.onLeftGuild", "make1", var.lastTime)
end

function storeLevelChange(actor)
	local var = getGuildStoreVar(actor)
	if var == nil then return 0 end

	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then return end

	if var.lastGuildId ~= 0 and var.lastGuildId ~= guildId then
		local storeLevel = getGuildStoreLevel(actor)
		local confTime = GuildStoreConfig.time[storeLevel] or 0
		local diff = confTime - var.lastTime
		if diff > 0 then var.lastTime = var.lastTime + diff end
	end
end


actorevent.reg(aeNewDayArrive, onNewDay)

actorevent.reg(aeJoinGuild, onJoinGuild)
actorevent.reg(aeLeftGuild, onLeftGuild)

netmsgdispatcher.reg(Protocol.CMD_GuildStore, Protocol.cGuildStoreCmd_CommInfo, handleGetCommInfo)
netmsgdispatcher.reg(Protocol.CMD_GuildStore, Protocol.cGuildStoreCmd_Log, handleGetLog)
netmsgdispatcher.reg(Protocol.CMD_GuildStore, Protocol.cGuildStoreCmd_Unpack, handleUnpack)

local gmsystem    = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.guildstore = function(actor, args)
	handleGetCommInfo(actor)
end

gmCmdHandlers.guildstorelog = function(actor, args)
	handleGetLog(actor)
end

gmCmdHandlers.guildstoreunpack = function(actor, args)
	handleUnpack(actor)
end

