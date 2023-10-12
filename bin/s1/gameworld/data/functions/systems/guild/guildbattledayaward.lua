module("guildbattledayaward", package.seeall)

local function getData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then 
		return nil
	end
	if var.guild_battle_day_award == nil then 
		var.guild_battle_day_award = {}
	end
	return var.guild_battle_day_award
end

local function initData(actor)
	local var = getData(actor)
	if var.bit_map == nil then 
		var.bit_map = 0
		--领取位图
	end
	if var.day == nil then 
		var.day = 1
		--签到了多少天
	end
	if var.time == nil then 
		var.time = os.time()
	end
	if var.today_get == nil then 
		var.today_get = 0 
		--今天是否领取
	end
	if var.open_size == nil then 
		var.open_size = 0
	end
end


function getAward(actor,day)
	if not guildbattlefb.isWinGuild(actor) then 
		return
	end
	local var = getData(actor)
	if var.today_get == 1 then 
		print(LActor.getActorId(actor) .. " 今天领取了")
		return
	end
	if var.day < day then 
		--签到时间不足
		print(LActor.getActorId(actor) .. " 签到时间不足 ")
		return false
	end

	if System.bitOPMask(var.bit_map,day) then 
		print(LActor.getActorId(actor) .. " 重复领取 ")
		return false
	end
	local conf = GuildBattleDayAward[day]
	if conf == nil then 
		print("guildbattledayaward no has config " .. day)
		return false
	end
	LActor.giveAwards(actor, conf.award, "guild battle day award")
	var.bit_map = System.bitOpSetMask(var.bit_map,day,true)

	var.today_get = 1
	return true
end

function update(actor)
	if not guildbattlefb.isWinGuild(actor) then 
		return
	end
	local var = getData(actor)
	local curr = os.time()
	if utils.getDay(curr) ~= utils.getDay(var.time) then 
		var.day = var.day + 1
		var.time = curr
		var.today_get = 0
		LActor.log(actor, "guildbattledayaward.update", "mark1", var.day, var.time)
	end
	if var.day > GuildBattleConst.maxDay then 
		var.day = GuildBattleConst.maxDay
		LActor.log(actor, "guildbattledayaward.update", "mark2",  var.day)
	end
end

function rsfData(actor)
	local var   = getData(actor)
	if var.open_size == nil or var.open_size ~= guildbattle.getOpenSize() then 
		var.day       = 1
		var.time      = os.time()
		var.bit_map   = 0
		var.open_size = guildbattle.getOpenSize()
	end
end

function rsfOnlineActor()
	local actors = System.getOnlineActorList()
	if actors == nil then
		return
	end
	for i = 1,#actors do 
		rsfData(actors[i])
		sendData(actors[i])
	end
end

function sendData(actor)
	local var = getData(actor)
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_SignInData)
	if npack == nil then 
		return
	end
	if guildbattlefb.isWinGuild(actor)  then 
		local is_get = true
		if System.bitOPMask(var.bit_map,var.day)  then 
			is_get = false
		end
		if var.today_get == 1 then 
			is_get = false
		end
		LDataPack.writeByte(npack, is_get and 1 or 0)
		LDataPack.writeByte(npack,is_get and 0 or 1)
	else 
		LDataPack.writeByte(npack,0)
		LDataPack.writeByte(npack,0)
	end
	--print(guildbattlefb.isWinGuild(actor))
	LDataPack.writeInt(npack,var.day or 0)
	LDataPack.flush(npack)
end


local function onGetAward(actor,pack)
	if not guildbattlefb.isWinGuild(actor) then 
		return
	end
	local day = LDataPack.readInt(pack)
	getAward(actor,day)
	sendData(actor)
end

function onInit(actor)
	initData(actor)
	--if not guildbattlefb.isWinGuild(actor) then 
	rsfData(actor);
	--end
end

function onLogin(actor)
	sendData(actor)
end

local function onNewDay(actor)
	update(actor)
	sendData(actor)
end

netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_GetSignInAward,onGetAward)

actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit,onInit)
