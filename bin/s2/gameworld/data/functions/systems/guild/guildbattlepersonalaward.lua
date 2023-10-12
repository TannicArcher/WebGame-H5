module("guildbattlepersonalaward", package.seeall)


local function getData(actor)
	local var = LActor.getStaticVar(actor) 
	if var == nil then 
		return nil 
	end
	if var.guild_battle_personal_award == nil then 
		var.guild_battle_personal_award = {}
	end
	return var.guild_battle_personal_award
end

local function initData(actor)
	--LActor.log(actor, "guildbattlepersonalaward.initData", "call")
	local var = getData(actor)
	if var.integral == nil then 
		var.integral = 0
	end
	if var.id == nil then 
		var.id = 1
	end
	if var.open_size == nil then 
		var.open_size = 0
	end
end

function rsfData(actor)
	--LActor.log(actor, "guildbattlepersonalaward.rsfData", "call")
	local guild_id = LActor.getGuildId(actor) 
	if guild_id == 0 then 
		return
	end
	local var = getData(actor)
	if var.open_size ~= guildbattle.getOpenSize() then 
		sendPersonalAward(actor)
		var.open_size = guildbattle.getOpenSize()
		var.id = 1
		var.integral = 0
	end
end

function sendPersonalAward(actor) 
	local var = getData(actor)
	if var.open_size == (guildbattle.getOpenSize() - 1) then 
		while getPersonalAward(actor,true) do 
		end
	end
end

function sendAllPersonalAward()
	local actors = System.getOnlineActorList() or {}
	for i=1,#actors do 
		while getPersonalAward(actors[i],true) do 
		end
	end

end

function rsfAllData()
	--System.log("guildbattlepersonalaward", "rsfAllData", "call")
	local actors = System.getOnlineActorList() or {}
	for i=1,#actors do 
		rsfData(actors[i])
	end
end

local function getGlobalData()
	local var = System.getStaticVar() 
	if var == nil then 
		return nil
	end
	if var.guild_battle_personal_award == nil then 
		var.guild_battle_personal_award = {}
	end
	return var.guild_battle_personal_award
end

local function initGlobalData()
	System.log("guildbattlepersonalaward", "initGlobalData", "call")
	local var = getGlobalData()
	if var.ranking == nil then 
		var.ranking = {}
	end
	if var.ranking_guild == nil then 
		var.ranking_guild = {}
	end
	if var.guild_data == nil then 
		var.guild_data = {}
		--[[
			total_integral 总积分
			actors 
			{
				actor_name 名字
				scene_name 场景名字
				integral 积分
				total_power 总战力
				pos 职位
				job 职业 
				sex 性别 
			}
			guild_name 公会名
			leader_name 会长名
		]]
	end
	if var.imperial_palace == nil then 
		var.imperial_palace = {}
	end
	if var.imperial_palace_attribution == nil then 
		var.imperial_palace_attribution = ""
		--皇宫归属帮派名字
	end
	if var.imperial_palace_attribution_guild_id == nil then 
		var.imperial_palace_attribution_guild_id = 0
	end
end

function rsfGlobalData()
	System.log("guildbattlepersonalaward", "rsfGlobalData", "call")
	local var									= getGlobalData()
	var.ranking									= {}
	var.ranking_guild							= {}
	var.guild_data								= {}
	var.imperial_palace							= {}
	var.imperial_palace_attribution				= ""
	var.imperial_palace_attribution_guild_id	= 0
	guildbattleintegralrank.resetRankingList()
end


local function initGuildData(guild_id)
	--System.log("guildbattlepersonalaward", "initGuildData", "call", guild_id)
	if guild_id == 0 then 
		return
	end
	local var = getGlobalData() 
	local guild_data = var.guild_data
	if guild_data[guild_id] == nil then 
		guild_data[guild_id] = {}
	end
	if guild_data[guild_id].total_integral == nil then 
		guild_data[guild_id].total_integral = 0
	end
	if guild_data[guild_id].actors == nil then 
		guild_data[guild_id].actors = {}
		--[[
		]]
	end
	if guild_data[guild_id].guild_name == nil then 
		guild_data[guild_id].guild_name = LGuild.getGuildName(LGuild.getGuildById(guild_id))
	end
	if guild_data[guild_id].leader_name == nil then 
		guild_data[guild_id].leader_name = LGuild.getLeaderName(LGuild.getGuildById(guild_id))
	end
end

function getGuildData(guild_id)
	if guild_id == 0 then 
		return nil
	end
	initGuildData(guild_id)
	local var = getGlobalData()
	return var.guild_data[guild_id]
end

local function initActorData(guild_id,actor_id)
	--LActor.log(actor, "guildbattlepersonalaward.initGuildData", "call", guild_id)
	if guild_id == 0 then 
		return
	end
	local var = getGuildData(guild_id) 
	if var.actors[actor_id] == nil then 
		var.actors[actor_id] = {}
	end
	if	var.actors[actor_id].actor_id == nil then 
		var.actors[actor_id].actor_id = actor_id
	end
	if var.actors[actor_id].actor_name == nil then 
		var.actors[actor_id].actor_name = ""
	end
	if var.actors[actor_id].scene_name == nil then 
		var.actors[actor_id].scene_name = ""
	end
	if var.actors[actor_id].integral == nil then 
		var.actors[actor_id].integral = 0
	end
	if var.actors[actor_id].total_power == nil then 
		var.actors[actor_id].total_power = 0
	end
	if var.actors[actor_id].pos == nil then 
		var.actors[actor_id].pos = 0
	end
	if var.actors[actor_id].job == nil then 
		var.actors[actor_id].job = 0
	end
	if var.actors[actor_id].sex == nil then 
		var.actors[actor_id].sex = 0
	end

end


function getTotalIntegral(guild_id)
	if guild_id == 0 then 
		return 0
	end
	local var = getGuildData(guild_id) 
	return var.total_integral
end



function getIntegral(actor)
	local var = getData(actor)
	return var.integral
end

function updateTotalIntegral(guild_id) 
	--System.log("guildbattlepersonalaward", "updateTotalIntegral", "call", guild_id)
	if guild_id == 0 then 
		return
	end
	local var = getGuildData(guild_id)
	var.total_integral = 0
	for i,v in pairs(var.actors) do 
		var.total_integral = var.total_integral + v.integral
		--System.log("guildbattlepersonalaward", "updateTotalIntegral", "mark1", var.total_integral)
	end
	sortGuild()
end


function showRanking()
	local var = getGlobalData()
	for i,v in pairs(var.ranking) do 
		print(i .. ": " .. var.ranking[i] .."--".. var.guild_data[v].total_integral)
	end
end

function getImperialPalaceAttribution()
	local var = getGlobalData()
	return var.imperial_palace_attribution
end

function getImperialPalaceAttributionGuildId()
	local var = getGlobalData()
	return var.imperial_palace_attribution_guild_id
end

function setCastellanGuild(gId)
	local var = getGlobalData()
	var.imperial_palace_attribution = LGuild.getGuildName(LGuild.getGuildById(gId))
	var.imperial_palace_attribution_guild_id = gId
end

function sortGuild() --排序
	local var = getGlobalData()
	local ranking_tbl = {}
	for i,v in pairs(var.guild_data) do 
		table.insert(ranking_tbl,i)
	end
	local function comps(a,b)
		local avar = getGuildData(a)
		local bvar = getGuildData(b)
		return avar.total_integral > bvar.total_integral
	end
	table.sort(ranking_tbl,comps)
	var.ranking = {}
	var.ranking_guild = {}
	var.ranking = ranking_tbl
	for i,v in pairs(ranking_tbl) do 
		var.ranking_guild[v] = i
	end

	local guild_id = ranking_tbl[1] or 0
	-- local tmp = (#ranking_tbl + 1)
	-- for i,v in pairs(var.imperial_palace) do 
	-- 	if var.ranking_guild[i] < tmp then 
	-- 		tmp = var.ranking_guild[i]
	-- 		guild_id = i
	-- 	end
	-- end
	if guild_id ~= 0 then 
		var.imperial_palace_attribution = LGuild.getGuildName(LGuild.getGuildById(guild_id))
		var.imperial_palace_attribution_guild_id = guild_id
	else
		var.imperial_palace_attribution = ""
		var.imperial_palace_attribution_guild_id = 0
	end

	guildbattlefb.broadcastImperialPalaceAttributionData()
end

function initImperialPalace(guild_id)
	local var = getGlobalData()
	local d = var.imperial_palace
	if d[guild_id] == nil then 
		d[guild_id] = {}
	end
	if d[guild_id].actors == nil then 
		d[guild_id].actors = {}
	end
end

function getImperialPalaceData(guild_id)
	if guild_id == 0 then 
		return nil
	end
	local var = getGlobalData()
	initImperialPalace(guild_id)
	return var.imperial_palace[guild_id]
end

function enterImperialPalace(actor) -- 进入了皇宫
	--LActor.log(actor, "guildbattlepersonalaward.enterImperialPalace", "call")
	local guild_id = LActor.getGuildId(actor) 
	local actor_id = LActor.getActorId(actor)
	if guild_id == 0 then 
		return
	end
	local var = getImperialPalaceData(guild_id) 
	if var.actors[actor_id] == nil then 
		var.actors[actor_id] = true
		sortGuild()
	end
end

function exitImperialPalace(actor) -- 退出了皇宫
	--LActor.log(actor, "guildbattlepersonalaward.exitImperialPalace", "call")
	local guild_id = LActor.getGuildId(actor) 
	local actor_id = LActor.getActorId(actor)
	if guild_id == 0 then 
		return
	end
	local var = getImperialPalaceData(guild_id)
	var.actors[actor_id] = nil
	if not next(var.actors) then 
		local gvar = getGlobalData()
		gvar.imperial_palace[guild_id] = nil
		sortGuild()
	end
end

function getGuildIntegralRanking()
	local var = getGlobalData()
	return var.ranking
end


function getRanking(guild_id) 
	if guild_id == 0 then 
		-- print(guild_id .. " 没有排名 1")
		return -1
	end
	local var = getGlobalData()
	if var.ranking_guild[guild_id] == nil then 
		-- print(guild_id .. " 没有排名 2")
		return -1
	end
	return var.ranking_guild[guild_id]
end

function gerRankingTbl()
	local var = getGlobalData()
	return var.ranking
end


function updateSceneName(actor,name)
	local actor_id = LActor.getActorId(actor)
	local guild_id = LActor.getGuildId(actor)
	if guild_id == 0 then 
		return
	end
	addIntegral(actor,0)
	local gvar = getGuildData(guild_id)
	gvar.actors[actor_id].scene_name = name
	-- print(actor_id .. " 当前场景 " .. name)
	--LActor.log(actor, "guildbattlepersonalaward.updateSceneName", name)
end

function addIntegral(actor,num)
	--LActor.log(actor, "guildbattlepersonalaward.addIntegral", "call", num)
	local guild_id = LActor.getGuildId(actor) 
	local actor_id = LActor.getActorId(actor)
	if guild_id == 0 then 
		return
	end
	local var = getData(actor)
	var.integral = var.integral + num
	if var.integral < 0 then 
		var.integral = 0
	end
	initActorData(guild_id,actor_id)
	local gvar = getGuildData(guild_id)
	gvar.actors[actor_id].integral    = var.integral
	gvar.actors[actor_id].actor_name  = LActor.getName(actor)
	gvar.actors[actor_id].total_power = LActor.getActorPower(actor_id)
	gvar.actors[actor_id].pos         = LActor.getGuildPos(actor)
	gvar.actors[actor_id].job         = LActor.getJob(actor)
	gvar.actors[actor_id].sex         = LActor.getSex(actor)
	updateTotalIntegral(guild_id)
	-- print(LActor.getActorId(actor) .. "  addIntegral " .. var.integral  .. " " .. num)
	--LActor.log(actor, "guildbattlepersonalaward.addIntegral", "mark", addIntegral, var.integral, num)
	guildbattleintegralrank.updateRankingList(actor,var.integral)
	sendGuileAndActorIntegral(actor,num)
	broadcastIntegral(guild_id)
	sendPersonalAwardData(actor)
end

function broadcastIntegral(guild_id) --广播数据到所有在线帮员
	local actors = guildbattle.getOnlineActor(guild_id)
	for i,v in pairs(actors) do 
		sendGuileAndActorIntegral(v,num)
	end
end

function checkGetPersonalAward(actor) 
	local var = getData(actor)
	local conf = GuildBattlePersonalAward[var.id] 
	if conf == nil then 
		print("getPersonalAward no has conf " .. var.id)
		return false
	end
	if conf.integral > var.integral then 
		return false
	end

	return true

end

function sendPersonalAwardData(actor) 
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_PersonalAwardData)
	if npack == nil then 
		return
	end
	local var = getData(actor)
	LDataPack.writeByte(npack,checkGetPersonalAward(actor) and 1 or 0)
	LDataPack.writeInt(npack,var.id)
	LDataPack.writeInt(npack,var.integral)
	LDataPack.flush(npack)

end

function getPersonalAward(actor,mall) --得到个人奖励
	--LActor.log(actor, "guildbattlepersonalaward.getPersonalAward", "call", mall)
	if not checkGetPersonalAward(actor) then 
		return false
	end
	local actor_id = LActor.getActorId(actor)
	local var = getData(actor)
	local conf =  GuildBattlePersonalAward[var.id]
	var.id = var.id + 1

	if mall ~= nil and mall == true then
		local mail_data = {}
		mail_data.head = GuildBattleConst.personalIntegralHead
		mail_data.context = string.format(GuildBattleConst.personalIntegralContext,conf.integral)
		mail_data.tAwardList = conf.award
		LActor.log(actor_id, "guildbattlepersonalaward.getPersonalAward", "mark1")
		mailsystem.sendMailById(actor_id,mail_data)
	else
		LActor.log(actor, "guildbattlepersonalaward.getPersonalAward", "mark2")
		LActor.giveAwards(actor, conf.award, "gb PersonalAward")
	end
	sendPersonalAwardData(actor)
	return true
end


function sendGuileAndActorIntegral(actor,num)
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_GuileAndActorIntegral)
	if npack == nil then 
		return
	end
	local guild_id = LActor.getGuildId(actor)
	LDataPack.writeInt(npack,getIntegral(actor))
	LDataPack.writeInt(npack,getTotalIntegral(guild_id))
	if num == nil then 
		LDataPack.writeInt(npack,0)
	else 
		LDataPack.writeInt(npack,num)
	end
	LDataPack.flush(npack)

end


function makeGuildRankingGtopThree(npack)
	--System.log("guildbattlepersonalaward", "makeGuildRankingGtopThree", "call")
	local count = 0
	local ranking = getGuildIntegralRanking()
	if #ranking >= 3 then 
		count = 3
	else 
		count = #ranking
	end
	LDataPack.writeInt(npack,count)
	for i = 1,count do 
		local data = getGuildData(ranking[i])
		LDataPack.writeString(npack,data.guild_name)
		LDataPack.writeInt(npack,data.total_integral)
	end
	--System.log("guildbattlepersonalaward", "makeGuildRankingGtopThree", "mark")
end

function sendGuildRankingGtopThree(actor) 
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_GuildRankingGtopThree)
	if npack == nil then 
		return
	end
	makeGuildRankingGtopThree(npack)
	LDataPack.flush(npack)
end

function broadcastGuildRankingGtopThree() 
	local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_GuildRankingGtopThree)
	if npack == nil then 
		return
	end
	makeGuildRankingGtopThree(npack)
	guildbattlefb.sendDataForScene(npack)
end

function autoBroadcastGuildRankingGtopThree()
	if not guildbattlefb.isOpen() then 
		return
	end
	broadcastGuildRankingGtopThree()
	LActor.postScriptEventLite(nil,(5)  * 1000,function() autoBroadcastGuildRankingGtopThree() end)
end

function sendGuildRanking(actor)
	--showRanking()
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_GuildRanking)
	if npack == nil then 
		return
	end
	local gvar = guildbattlefb.getOccupyData()
	LDataPack.writeString(npack, gvar.guild_name or "")
	LDataPack.writeByte(npack, gvar.endStat or 0)

	local ranking = getGuildIntegralRanking()
	local size = #ranking >= GuildBattleConst.guildIntegralRaningBoardSize  and GuildBattleConst.guildIntegralRaningBoardSize or #ranking 
	LDataPack.writeInt(npack,size)
	for i = 1,size do 
		local data = getGuildData(ranking[i])
		LDataPack.writeString(npack,data.guild_name)
		LDataPack.writeString(npack,data.leader_name)
		LDataPack.writeInt(npack,data.total_integral)
	end
	LDataPack.flush(npack)
end

function sendGuileActorIntegralList(actor)
	local guild_id = LActor.getGuildId(actor)
	if guild_id == 0 then 
		return
	end
	local gvar = getGuildData(guild_id)
	local tmp_arr = {}
	for i,v in pairs(gvar.actors) do 
		table.insert(tmp_arr,v)
	end
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_GuileActorIntegralList)
	if npack == nil then 
		return
	end
	LDataPack.writeInt(npack,#tmp_arr)
	for i=1,#tmp_arr do 
		local v = tmp_arr[i]
		LDataPack.writeInt(npack,v.actor_id or 0)
		LDataPack.writeString(npack,v.actor_name)
		LDataPack.writeString(npack,v.scene_name)
		LDataPack.writeInt(npack,v.integral)
		LDataPack.writeInt(npack,v.total_power)
		LDataPack.writeInt(npack,v.pos)
		LDataPack.writeInt(npack,v.job)
		LDataPack.writeInt(npack,v.sex)
	end
	LDataPack.flush(npack)

end

local function onSendGuildRanking(actor,pack)
	sendGuildRanking(actor)
end

local function onGuileActorIntegralList(actor,pack)
	sendGuileActorIntegralList(actor)
end

local function onPersonalAwardData(actor,pack)
	sendPersonalAwardData(actor)
end
local function onGetPersonalAward(actor,pack) 
	local ret = getPersonalAward(actor)
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_GetPersonalAward)
	if npack == nil then 
		return
	end
	LDataPack.writeByte(npack,ret and 1 or 0)
	LDataPack.flush(npack)

end

function onInit(actor)
	initData(actor)
	sendPersonalAward(actor)
	local var = getData(actor)
	if not guildbattlefb.isOpen() 
		and var.open_size == guildbattle.getOpenSize() 
	then 
		while getPersonalAward(actor,true) do 
		end
	end
	rsfData(actor)

end

function onLogin(actor)
	--[[
	print("/////////////////////////////////////////////////")
	addIntegral(actor,1000)
	print("/////////////////////////////////////////////////")
	]]
	if not System.isCommSrv() then return end

	local guild_id = LActor.getGuildId(actor)
	sendGuileAndActorIntegral(actor)
	sendPersonalAwardData(actor)
--	onSendGuildRanking(actor)
end

netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_GuildRanking,onSendGuildRanking)
netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_GuileActorIntegralList,onGuileActorIntegralList)
netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_PersonalAwardData,onPersonalAwardData)
netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_GetPersonalAward,onGetPersonalAward)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit,onInit)


initGlobalData()



