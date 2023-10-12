module("activity.qqplatform.ljczbase" , package.seeall)
setfenv(1, activity.qqplatform.ljczbase)

local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local mailsystem = require("systems.mail.mailsystem")
local postscripttimer = require("base.scripttimer.postscripttimer")
local abase = require("systems.awards.abase")
local actorevent = require("actorevent.actorevent")
local gmsystem    = require("systems.gm.gmsystem")

local operations = require("systems.activity.operations")
local rbase = require("activity.qqplatform.rechargebase")

require("activity.operationsconf")

local protocol = YunyingActivityProtocal
local systemId = SystemId.yunyingActivitySystem 
local subActId = SubActConf.LJ_RECHARGE
local ActivityConfig = operations.getSubActivitys(subActId)
local cmd = protocol.sRechargeValue

function openActivity(actId, begintime, endtime)
	rbase.rechargeInit(actId, begintime, endtime)
end

function closeActivity(actId)
	rbase.rechargeClose(actId, 0, 0, subActId)
end

function onUserLogin(actor)
	for actId, info in pairs(ActivityConfig) do
		rbase.loginCheck(actor, actId, info.config)
	end
end

function rechargeVal(actor, val)
	if not System.isCommSrv() then return end

	for actId, info in pairs(ActivityConfig) do
		rbase.rechargeVal(actor, val, actId, systemId, cmd)
	end
end

function initOperations()
	for actId, info in pairs(ActivityConfig) do
		operations.regStartEvent(actId, openActivity)
		operations.regCloseEvent(actId, closeActivity)
	end
end

function getAward(actor, packet)
	if not System.isCommSrv() then return end

	local actId = LDataPack.readInt(packet)
	local idx = LDataPack.readInt(packet)

	local config = ActivityConfig[actId].config
	if not config then return end

	if rbase.checkSendAward(actor, actId, idx, config) then
		rbase.sendBaseInfo(actor, actId, systemId, cmd)
	end
end

function getRechargeInfo(actor, packet)
	if not System.isCommSrv() then return end

	if not actor or not packet then return end

	local actId = LDataPack.readInt(packet)

	rbase.sendBaseInfo(actor, actId, systemId, cmd)
end

actorevent.reg(aeRecharge, rechargeVal)

actorevent.reg(aeUserLogin, onUserLogin, true)

table.insert(InitFnTable, initOperations)

netmsgdispatcher.reg(systemId, protocol.cGetRechargeAward, getAward)
netmsgdispatcher.reg(systemId, protocol.cRechargeValue, getRechargeInfo)

local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.rechargeOpen = function(actor, args)
	if not System.isCommSrv() then return end
	
	local begintime = "2015-9-1 0:0:0"
	local endTime = "2015-11-30 0:0:0"
	operations.onSetOperTime(2, begintime, endTime)
end

gmCmdHandlers.rechargeClose = function(actor)
	if not System.isCommSrv() then return end

	local begintime = "2010-9-1 0:0:0"
	local endTime = "2010-11-30 0:0:0"
	operations.onSetOperTime(2, begintime, endTime)
end


