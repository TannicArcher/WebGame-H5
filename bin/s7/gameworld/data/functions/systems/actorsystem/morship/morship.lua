--膜拜系统
module("morship", package.seeall)

--[[
    morshipData = {
		{
			record
		}
    }
--]]

--膜拜数据包缓存

local function getStaticData(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then return nil end

    if var.morshipData == nil then
        var.morshipData = {}
    end
    return var.morshipData
end

local function initData(actor)
	local var = getStaticData(actor)
	local i = 0
	while (i < RankingType_Count) do 
		if var[i] == nil then 
			var[i] = 
			{
				record = 0,
			}
		end
		i = i + 1
	end
end


local function sendReqMorshipData(actor,type)
	local var = getStaticData(actor)
	if var[type] == nil  then 
		return
	end
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_Ranking,Protocol.sRankingCmd_ResWorshipData)
	if npack == nil then 
		return
	end
	LDataPack.writeShort(npack,type)
	LDataPack.writeShort(npack,var[type].record)
	local cache = LActor.getRainingFirstCacheByType(type)
	if cache ~= nil then 
		if (LDataPack.getLength(cache) <= 0) then
			LDataPack.writeInt(npack,0)
		else
			LDataPack.writePacket(npack, cache)
		end
	else 
		LDataPack.writeInt(npack,0)
	end
	LDataPack.flush(npack)
end

local function sendMorshipData(actor,type)
	local var = getStaticData(actor)
	if var[type] == nil then 
		return
	end
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_Ranking,Protocol.sRankingCmd_UpdateWorship)
	if npack == nil then 
		return
	end
	LDataPack.writeShort(npack,type)
	LDataPack.writeShort(npack,var[type].record)
	LDataPack.flush(npack)
end

local function morship(actor,type)
	local var = getStaticData(actor)
	if var[type] == nil then 
		return
	end
	local level            = LActor.getLevel(actor)
	local zhuansheng_level = LActor.getZhuanShengLevel(actor)
	local conf             = nil
	if zhuansheng_level ~= 0 then 
		level = zhuansheng_level * 1000
	end
	if MorshipConfig[type] == nil then
		print("not config type " .. type)
		return
	end
	conf = MorshipConfig[type][level]
	if conf == nil then 
		print("no has config " .. type .. " " .. level)
		return
	end
	if conf.count <= var[type].record then
		log_print(LActor.getActorId(actor) .. "morship: record " .. conf.count .. ":" .. var[type].record)
		return
	end

	var[type].record = var[type].record + 1
	LActor.giveAwards(actor,conf.awards,"morship award")
	log_print(LActor.getActorId(actor) .. " morship " .. var[type].record .. " " .. conf.count)
	sendMorshipData(actor,type)
	actorevent.onEvent(actor, aeMorship, 1)
end

local function ReqAllMorship(actor)
	local var = getStaticData(actor)
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_Ranking,Protocol.sRankingCmd_ResAllWorshipData)
	if npack == nil then 
		return
	end 

	LDataPack.writeShort(npack,RankingType_Count)
	for i = 0, RankingType_Count do 
		if not var[i] then
			break
		end
		LDataPack.writeShort(npack,i)
		LDataPack.writeShort(npack,var[i].record)
		
	end
	LDataPack.flush(npack)

end



local function onInit(actor)
	initData(actor)
end

local function onNewDay(actor)
	local var = getStaticData(actor)
	local i = 0
	while (i < RankingType_Count) do 
		var[i].record = 0
		i = i + 1
	end
end

local function onReqMorshipData(actor,pack)
	local type = LDataPack.readShort(pack)
	sendReqMorshipData(actor,type)
end

local function onReqMorship(actor,pack)
	local type = LDataPack.readShort(pack)
	morship(actor,type)
end

local function onReqAllMorship(actor,pack)
	
	ReqAllMorship(actor)
end




--extern 



function updateDynamicFirstCache(actor_id,type)
	LActor.updateDynamicFirstCache(actor_id,type)
end

actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeInit,onInit)

netmsgdispatcher.reg(Protocol.CMD_Ranking, Protocol.cRankingCmd_ReqWorshipData, onReqMorshipData)
netmsgdispatcher.reg(Protocol.CMD_Ranking, Protocol.cRankingCmd_ReqWorship, onReqMorship)
netmsgdispatcher.reg(Protocol.CMD_Ranking, Protocol.cRankingCmd_ReqAllWorshipData, onReqAllMorship)

--_G.updateMorshipData = updateMorshipData

