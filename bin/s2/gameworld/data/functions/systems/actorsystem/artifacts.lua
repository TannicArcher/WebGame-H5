module("artifacts",package.seeall)

--[[
--个人数据
ArtifactsData = {
	bool is_finish_achievement; //是否完成所有成就、如果有   TODO 现在用1 和0 待替  直接用bool 会坑
	short rank; //有多少阶
}
]]


local function getArtifactsData(actor,id)
	local var = LActor.getStaticVar(actor)
	if var == nil then 
		return nil
	end
	if var.artifacts == nil then 
		var.artifacts = {}
	end
	if var.artifacts[id] == nil then 
		var.artifacts[id] = {}
	end
	return var.artifacts[id]
end

local function isActivationArtifacts(actor,id)
	local data = getArtifactsData(actor,id) 
	if data == nil then 
		return false
	end
	if data.rank == nil then 
		return false
	end
	return data.rank >= 1
end

local function showArtifactsData(actor)
	for i,v in pairs(ArtifactsConfig) do 
		local data = getArtifactsData(actor,i)
		--print("finish_achievement: " .. data.is_finish_achievement)
		--print("rank: " .. data.rank and data.rank or 0)
	end

end

local function initArtifactsData(actor)
	for i,v in pairs(ArtifactsConfig) do 
		local data = getArtifactsData(actor,i)
		if not isActivationArtifacts(actor,i) then 
			data.is_finish_achievement = 0
			data.rank                  = 0
			if v.activationAchievementIds ~= nil and next(v.activationAchievementIds) then 
				data.is_finish_achievement = 1
				for j,jv in pairs(v.activationAchievementIds) do 
					if not achievetask.isFinish(actor,jv.achieveId,jv.taskId)  then
						data.is_finish_achievement = 0
						break
					end
				end
			end
		end
	end
end

local function activationArtifacts(actor,id)
	local data = getArtifactsData(actor,id)
	if data == nil then 
		return false
	end
	if isActivationArtifacts(actor,id) then 
		log_print(LActor.getActorId(actor) .. " activationArtifacts: repeat activation " .. id)
		return false
	end
	local config = ArtifactsConfig[id]
	if config == nil then 
		return false
	end
	if config.activationItem ~= nil and next(config.activationItem) then

		if not LActor.consumeItem(actor,
			config.activationItem.id, 
			config.activationItem.count, 
			false, 
			"artifacts activation"
			) then 
			log_print(LActor.getActorId(actor) .. " activationArtifacts: consumeItem  " .. id)
			return false
		end
		data.rank = 1 
		log_print(LActor.getActorId(actor) .. " activationArtifacts: ok  " .. id)
		return true
	end
	if config.activationAchievementIds ~= nil and next(config.activationAchievementIds) then
		if data.is_finish_achievement == 1 then 
			data.rank = 1
			log_print(LActor.getActorId(actor) .. " activationArtifacts: ok  " .. id)
			return true
		end
	end
	log_print(LActor.getActorId(actor) .. " activationArtifacts: error  " .. id)
	return false
end

local function rankUpArtifacts(actor,id)
	local data = getArtifactsData(actor,id) 
	if data == nil then 
		return false
	end
	if not isActivationArtifacts(actor,id) then 
		log_print(LActor.getActorId(actor) .. " rankUpArtifacts: activation  " .. id)
		--print("not activation")
		return false
	end
	if ArtifactsRankConfig[id] == nil then 
		--print("not rank config")
		return false
	end
	local config = ArtifactsRankConfig[id][data.rank]
	if config == nil then 
		--print("not config")
		return false
	end
	if config.rankUpItem == nil then 
		--print("not rankUpItem")
		return false
	end
	
	if (LActor.getItemCount(actor,config.rankUpItem.id) < config.rankUpItem.count) then
		return false
	end

	if not LActor.consumeItem(actor,
		config.rankUpItem.id, 
		config.rankUpItem.count, 
		false, 
		"artifacts rank up"
		) then 
		log_print(LActor.getActorId(actor) .. " rankUpArtifacts: consumeItem  " .. id)
		return false
	end
	data.rank = data.rank + 1
	log_print(LActor.getActorId(actor) .. " rankUpArtifacts: ok  " .. id)
	actorevent.onEvent(actor,aeArtifactstage,1,false)
	return true
end

local function loadAttrs(actor)
	local attrs = {}
	local attr = LActor.getArtifactsAttr(actor)
	attr:Reset()
	for i,v in pairs(ArtifactsConfig) do 
		local data = getArtifactsData(actor,i)
		if data == nil then 
			--print("not data")
			return false
		end
		if isActivationArtifacts(actor,i) then 
			if ArtifactsRankConfig[i] == nil then 
				--print("not rank config")
				return false
			end
			if ArtifactsRankConfig[i][data.rank] == nil then 
				--print("not rank")
				return false
			end
			local config = ArtifactsRankConfig[i][data.rank] 

			if config.attrs == nil or not next(config.attrs) then 
				--print("not attrs config")
				return false
			end

			for j,jv in pairs(config.attrs) do
				--print(utils.t2s(jv))
				if attrs[jv.type] == nil then 
					table.insert(attrs,jv.type,jv.value)
				else 
					attrs[jv.type] = attrs[jv.type] + jv.value
				end
			end
		end

	end
	--print(utils.t2s(attrs))
	for i,v in pairs(attrs) do
		attr:Set(i,v)
	end
	LActor.reCalcAttr(actor)
	return true
end

--net begin
local function sendArtifactsData(actor)
	local data = {}
	for i,v in pairs(ArtifactsConfig) do 
		local tmp = getArtifactsData(actor,i)
		if tmp ~= nil then 
			table.insert(data,{i,tmp.rank or 0 })
		end
	end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Artifacts, Protocol.sArtifactsCmd_ArtifactsData)
	if npack == nil then 
		return 
	end
	local sum = #data
	LDataPack.writeInt(npack,sum)
	for i = 1,#data do 
		LDataPack.writeInt(npack,data[i][1]) -- id 
		LDataPack.writeShort(npack,data[i][2]) -- rank
	end
	LDataPack.flush(npack)
end

local function onArtifactsRankUp(actor, packet)
	local id = LDataPack.readInt(packet)
	if ArtifactsConfig[id] == nil then
		return
	end
	local function sendPack(is_ok)
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Artifacts, Protocol.sArtifactsCmd_ArtifactsRankUpResult)
		if npack == nil then 
			return 
		end
		LDataPack.writeByte(npack,is_ok and 1 or 0)
		if not is_ok then
			LDataPack.flush(npack)
			return
		end
		local data = getArtifactsData(actor,id)
		if data == nil then 
			return 
		end
		LDataPack.writeInt(npack,id)
		LDataPack.writeShort(npack,data.rank)
		LDataPack.flush(npack)

		if is_ok then 
			loadAttrs(actor)
			specialattribute.updateAttribute(actor)
		end

	end
	if not isActivationArtifacts(actor,id) then 
		initArtifactsData(actor)
		local ret = activationArtifacts(actor,id)
		sendPack(ret)
		--发广播
		local config = ArtifactsConfig[id] 
		if config == nil then 
			return
		end
		if config.activationBroadcast == nil or config.activationBroadcast == 0 or config.artifactsName == nil then 
			return
		end
		if not ret then 
			return 
		end
		noticemanager.broadCastNotice(config.activationBroadcast,
			LActor.getActorName(LActor.getActorId(actor))
			,config.artifactsName)
		actorevent.onEvent(actor,aeArtifact,id,false)
		actorevent.onEvent(actor,aeArtifactstage,1,false)
	else 
		local ret = rankUpArtifacts(actor,id)
		sendPack(ret)
	end
end

--net end
local function onBeforeLogin( actor )
	initArtifactsData(actor)
	loadAttrs(actor)
end

local function onLogin(actor)
	sendArtifactsData(actor)
end

local function onAchievetaskFinish(actor,id)
	initArtifactsData(actor)
end


function updateAttribute( actor, sysType )
	for i,iv in pairs(ArtifactsConfig) do 
		if isActivationArtifacts(actor,iv.id) then
			for j,jv in pairs(iv.specialAttributes) do 
				specialattribute.add(actor,jv.type,jv.value,sysType)
			end
		end
	end
end

local function init()
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeAchievetaskFinish, onAchievetaskFinish)
	actorevent.reg(aeInit, onBeforeLogin)
	netmsgdispatcher.reg(Protocol.CMD_Artifacts, Protocol.cArtifactsCmd_ArtifactsRankUp, onArtifactsRankUp)
end

table.insert(InitFnTable, init)
