--[[
个人信息
integral  积分
id 		  当前已领取的id，0表示没领过
]]

module("campbattlepersonaward", package.seeall)

local function getData(actor)
	local var = LActor.getStaticVar(actor)
	if nil == var.camp_battle_award then var.camp_battle_award = {} end
	return var.camp_battle_award
end

--检测奖励是否可以领取
local function checkGetPersonalAward(actor)
	local var = getData(actor)
	local conf = CampBattlePersonalAwardConfig[var.id or 1]
	if not conf then return false end

	if conf.integral > (var.integral or 0) then return false end

	return true
end

--发送个人积分奖励信息
function sendPersonalAwardData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_PersonalAwardData)

	local var = getData(actor)
	LDataPack.writeInt(npack, var.id or 0)
	LDataPack.writeInt(npack, var.integral or 0)
	LDataPack.flush(npack)
end

--获取个人积分奖励
local function getPersonalAward(actor)
	local actorId = LActor.getActorId(actor)
	local var = getData(actor)
	if (var.id or 0) >= #CampBattlePersonalAwardConfig then
		print("campbattlepersonaward.getPersonalAward: get all reward, actorId:"..tostring(actorId))
		return false
	end

	if false == checkGetPersonalAward(actor) then
		print("campbattlepersonaward.getPersonalAward: integral not enough, id:"..tostring(var.id)..", actorId:"..tostring(actorId))
		return false
	end

	local conf = CampBattlePersonalAwardConfig[var.id or 1]

	var.id = (var.id or 0) + 1
	LActor.giveAwards(actor, conf.award, "campBattle PersonalAward")
	sendPersonalAwardData(actor)

	LActor.sendTipmsg(actor, string.format(LAN.FUBEN.xzbq1, conf.count1), ttScreenCenter)

	return true
end

--发送自己的最新积分
local function sendActorIntegral(actor, num, flag, name)
	local var = getData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_ActorIntegral)
	LDataPack.writeInt(npack, var.integral or 0)
	LDataPack.writeInt(npack, num)
	LDataPack.writeString(npack, name or "")
	LDataPack.writeByte(npack, flag or 0)
	LDataPack.flush(npack)
end

--增加积分
function addIntegral(actor, num, flag, name)
	local var = getData(actor)
	var.integral = (var.integral or 0) + num

	sendActorIntegral(actor, num, flag, name)
end

local function onGetPersonalAward(actor)
	local ret = getPersonalAward(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_CampBattle, Protocol.sCampBattleCmd_GetPersonalAward)
	LDataPack.writeByte(npack, ret and 1 or 0)
	LDataPack.flush(npack)
end

local function onNewDay(actor)
	local var = getData(actor)
	var.id = nil
	var.integral = nil
end

local function initFunc()
	actorevent.reg(aeNewDayArrive, onNewDay)

	netmsgdispatcher.reg(Protocol.CMD_CampBattle, Protocol.cCampBattleCmd_GetPersonalAward, onGetPersonalAward)
end
table.insert(InitFnTable, initFunc)

