--[[
	author = 'Roson'
	time   = 11.04.2014
	name   = 多倍挂机系统
	mod    = 主逻辑包
	ver    = 0.1
]]

module("systems.superexptime.mainevent" , package.seeall)
setfenv(1, systems.superexptime.mainevent)

local sbase       = require("systems.superexptime.sbase")
local actornetmsg = require("utils.actornetmsg")
local lianfuutils = require("systems.lianfu.lianfuutils")
local fubenevent  = require("actorevent.fubenevent")

local netmsgdispatcher = sbase.netmsgdispatcher
local actorevent       = sbase.actorevent

local sysId    = sbase.sysId
local protocol = sbase.protocol

local SuperExpTimeConf = sbase.SuperExpTimeConf
local FUBEN_ID         = SuperExpTimeConf.fubenId
local buffConf         = SuperExpTimeConf.buffConf
local openLevel        = SuperExpTimeConf.openLevel

local System    = System
local LDataPack = LDataPack
local LActor    = LActor

local resetFuncs = {}
local resetAftFuncs = {}

local MONDAY_NUM = 1

--********************************************--
--README ---------- * 数据接口 * ---------------
--********************************************--

function getSysVar(actor)
	local var = sbase.getSysVar(actor)
	if not var then return end

	if var.main == nil then var.main = {} end
	return var.main
end

--********************************************--
--README ---------- * 主逻辑 * -----------------
--********************************************--

--Comments:发送数据
function writeSupAttData(pack, expMonCount, buyCount)
	local System = System
	local time_now = System.getNowTime()
	LDataPack.writeData(pack, 2,
		dtUint, expMonCount or 0,
		dtChar, buyCount or 0)
end

function onSendSupAtt(actor, pack)
	local var = getSysVar(actor)
	if not var then return end

	local rePack = LDataPack.allocPacket(actor, sysId, protocol.sGetSysAtts)
	if not rePack then return end
	writeSupAttData(rePack, var.expMonCount, var.buyCount)
	LDataPack.flush(rePack)
end

function onRecieveSendSupAtt(actorId)
	local var = getSysVar(actorId)
	if not var then return end

	local rePack = LDataPack.allocBroadcastPacket(sysId, protocol.sGetSysAtts)
	if not rePack then return end

	writeSupAttData(rePack, var.expMonCount, var.buyCount)
	LianfuFun.sendToActor(actorId, rePack)
end

--Comments:重置数据
function onReset(actor)
	local actorLv = LActor.getRealLevel(actor)
	if actorLv < openLevel then return end

	local var = getSysVar(actor)
	if not var then return end

	for _,func in pairs(resetFuncs) do
		func(actor)
	end
	--------------------------------------------
	--BI：怪物数量更新
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)), "fuben", "", "userid:"..LActor.getActorId(actor), "supertime", "local", isFirst and "true" or "false", tostring(var.expMonCount), "reset", lfBI)
	--------------------------------------------

	onSendSupAtt(actor)

	for _,func in pairs(resetAftFuncs) do
		func(actor)
	end

	print(string.format("[TIMESMGR][RESET][%s]-->expMonCount %s", LActor.getActorId(actor), var.expMonCount or 0))
end

function regResetFunc(func)
	for _,f in pairs(resetFuncs) do
		if f == func then return end
	end

	table.insert(resetFuncs, func)
end

function regResetAftFunc(func)
	for _,f in pairs(resetAftFuncs) do
		if f == func then return end
	end

	table.insert(resetAftFuncs, func)
end

--Comments:第一次登陆的判定
function onLogin(actor)
	local var = getSysVar(actor)
	if not var then return end

	if var.expMonCount == nil then
		onReset(actor)
	else
		onSendSupAtt(actor)
	end
end

function onLevelOpen(actor)
	local actorLv = LActor.getRealLevel(actor)
	if actorLv ~= openLevel then return end

	onReset(actor)
end

function onFubenExit(actor)
	local actorId = LActor.getActorId(actor)
	local count = 0
	local var = getSysVar(actor)
	if var and var.expMonCount then
		count = var.expMonCount
	end
	--------------------------------------------
	--BI:退出副本
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)), "fuben", "", "userid:"..LActor.getActorId(actor), "supertime", "local", "", tostring(count), "out", lfBI)
	--------------------------------------------
	print(string.format("[TIMESMGR][OUT][%s]-->onFubenExit", actorId))
	print(string.format("[TIMESMGR][OUT][%s]-->expMonCount %s", actorId, count))
end

function onFubenEnter(actor)
	local actorId = LActor.getActorId(actor)

	local count = 0
	local var = getSysVar(actor)
	if var and var.expMonCount then
		count = var.expMonCount
	end
	--------------------------------------------
	--BI:进入副本
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)), "fuben", "", "userid:"..LActor.getActorId(actor), "supertime", "local", "", tostring(count), "in", lfBI)
	--------------------------------------------
	print(string.format("[TIMESMGR][IN][%s]-->expMonCount %s", actorId, count))
end

---------------- reg -------------------
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onReset)
actorevent.reg(aeLevel, onLevelOpen)

fubenevent.registerFubenExit(FUBEN_ID, onFubenExit)
fubenevent.registerFubenEnter(FUBEN_ID, onFubenEnter)

netmsgdispatcher.reg(sysId, protocol.cGetSysAtts, onSendSupAtt)
actornetmsg.reg(sysId, protocol.cGetSysAtts, onRecieveSendSupAtt)
