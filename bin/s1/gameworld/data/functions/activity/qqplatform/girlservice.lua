--[[
	author  = 'Roson'
	time    = 10.15.2015
	name    = 美女客服
	ver     = 0.1
]]

module("activity.qqplatform.girlservice" , package.seeall)
setfenv(1, activity.qqplatform.girlservice)

local operations       = require("systems.activity.operations")
local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local actorevent       = require("actorevent.actorevent")

require("protocol")
local sysId    = SystemId.yunyingActivitySystem
local protocol = YunyingActivityProtocal

require("activity.operationsconf")
local SubActConf        = SubActConf
local GIRL_SERVRICE     = SubActConf.GIRL_SERVRICE
local GIRL_SERVRICE_STR = tostring(GIRL_SERVRICE)

local function getConf(operId)
	local conf, isOnTime = operations.getConf(operId, GIRL_SERVRICE)
	if not conf or not conf.config then return end

	return conf.config, isOnTime
end


local function getPlatVar(actor, operId, isClear)
	if not operId or operId <= 0 then return end

	local var = LActor.getPlatVar(actor)
	if not var then return end

	if var.girlservice == nil then var.girlservice = {} end
	local sVar = var.girlservice

	if sVar[operId] == nil or isClear then sVar[operId] = {} end
	return sVar[operId]
end

function clearPlatVar(actor, operId)
	if operId then
		getPlatVar(actor, operId, true)
	else
		local var = LActor.getPlatVar(actor)
		if not var then return end

		var.girlservice = nil
	end
end

local function sendFlagToActor(actor, operId)
	local conf, isOnTime = getConf(operId)
	if not conf or not isOnTime then return end

	local var = getPlatVar(actor, operId)
	if not var or not var.srvflag then return end

	local pack = LDataPack.allocPacket(actor, sysId, protocol.sSendGirlServiceNumber)
	if not pack then return end

	LDataPack.writeData(pack, 2,
		dtInt, operId,
		dtString, tostring(conf.qqNumber or 0))

	LDataPack.flush(pack)
end

local function setFlag(actor, operId, cnt, conf, isOnTime)
	if cnt < conf.minRecharge then return end

	local var = getPlatVar(actor, operId)
	if not var or var.srvflag == isOnTime then return end

	var.srvflag = isOnTime
end

local function onRecharge(actor, cnt)
	local ids = operations.getOnTimeOperIds()
	if not ids then return end

	for _,operId in pairs(ids) do
		local conf, isOnTime = getConf(operId)
		if conf and isOnTime then
			setFlag(actor, operId, cnt, conf, isOnTime)
			sendFlagToActor(actor, operId)
		end
	end
end

function onStarOper(operId, begTime, endTime)
	local players = LuaHelp.getAllActorList()
	if not players or #players <= 0 then return end

	-- 同运营确认该活动不需要进行数据清理 10.26.2015
	for _,player in ipairs(players) do
		-- clearPlatVar(player, operId)
	end
end

function regEvent( ... )
	local subConfs = operations.getSubActivitys(GIRL_SERVRICE)
	if not subConfs then return end

	for operId,_ in pairs(subConfs) do
		operations.regStartEvent(operId, onStarOper)
	end
end

function onLogin(actor)
	local ids = operations.getOnTimeOperIds()
	if not ids then return end

	for _,operId in pairs(ids) do
		local conf, isOnTime = getConf(operId)
		if conf and isOnTime then
			sendFlagToActor(actor, operId)
		end
	end
end

table.insert(InitFnTable, regEvent)

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeRecharge, onRecharge)
