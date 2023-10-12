--[[
	author = 'Roson'
	time   = 11.04.2014
	name   = 经验怪物系统
	mod    = 经验
	ver    = 0.1
]]

module("systems.superexptime.expmonmgr" , package.seeall)
setfenv(1, systems.superexptime.expmonmgr)

local sbase      = require("systems.superexptime.sbase")
local pTimer     = require("base.scripttimer.postscripttimer")
local mainevent  = require("systems.superexptime.mainevent")
local fubenevent = require("actorevent.fubenevent")
local actorexp   = require("systems.actorsystem.actorexp")
local act_base   = require("systems.actorsystem.actorbase")

local netmsgdispatcher = sbase.netmsgdispatcher
local actorevent       = sbase.actorevent

local sysId    = sbase.sysId
local protocol = sbase.protocol

local GameLog             = act_base.GameLog
local clKillMonsterExp    = GameLog.clKillMonsterExp
local SuperExpTimeConf    = sbase.SuperExpTimeConf
local buyConf             = SuperExpTimeConf.buyConf
local CAN_BUY_COUNT       = #buyConf
local addExpMonCountByDay = SuperExpTimeConf.addExpMonCountByDay
local maxExpMonCount      = SuperExpTimeConf.maxExpMonCount
local buyMoneyType        = SuperExpTimeConf.buyMoneyType
local FUBEN_ID            = SuperExpTimeConf.fubenId
local sceneExpConf        = SuperExpTimeConf.sceneExpConf

local Langs = Lang.SuperExpTime

--********************************************--
--README ---------- * 数据接口 * ---------------
--********************************************--

function getSysVar(actor)
	local var = sbase.getSysVar(actor)
	if not var then return end

	if var.main == nil then var.main = {} end
	return var.main
end

function getDyanmicVar(actor)
	local var = sbase.getDyanmicVar(actor)
	if not var then return end

	if var.main == nil then var.main = {} end
	return var.main
end

function getExpMonCount(actor)
	local var = getSysVar(actor)
	if not var then return end

	return var.expMonCount or 0
end

function expMonMoreThanOne(actor)
	local var = getSysVar(actor)
	if not var then return end

	if not var.expMonCount then return end

	if var.expMonCount <= 0 then return end

	var.expMonCount = var.expMonCount - 1
	return true
end

--********************************************--
--README ---------- * 经济系统 * ---------------
--********************************************--

function buyMonCount(actor)
	local var = getSysVar(actor)
	if not var or not var.canBuyCount or not var.buyCount then return false, Langs.err001 end

	local conf = buyConf[var.buyCount + 1]

	if not conf then
		return false, Langs.err001
	end

	local buyMoneyType = buyMoneyType
	local nMoneyVal    = conf.money
	local addCount     = conf.addCount

	if not buyMoneyType or not nMoneyVal then return false, Langs.err001 end

	if LActor.getMoneyCount(actor, buyMoneyType) < nMoneyVal then
		return false, Langs.err002
	end

	var.canBuyCount = var.canBuyCount - 1
	var.buyCount    = var.buyCount + 1

	LActor.changeMoney(actor, buyMoneyType, -nMoneyVal, 1, true, "superExpTime", "buy_exp_count", tostring(addCount))

	var.expMonCount = math.max(var.expMonCount or 0, 0)
	var.expMonCount = var.expMonCount + addCount

	mainevent.onSendSupAtt(actor)

	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)), "fuben", "", "userid:"..LActor.getActorId(actor), "supertime", tostring(var.buyCount), tostring(var.expMonCount), tostring(addCount), "buy", lfBI)

	return true
end

--购买高经验怪物数量
function onBuyMonCount(actor)
	local ret, msg = buyMonCount(actor)

	if msg then
		LActor.sendTipmsg(actor, msg, ttMessage)
	end

	local LDataPack = LDataPack

	local pack = LDataPack.allocPacket(actor, sysId, protocol.sBuyExpMonCntRet)
	if not pack then return end

	LDataPack.writeData(pack, 1,
		dtChar, ret and 1 or 0)

	LDataPack.flush(pack)
end

--重置
function resetByDay(actor)
	local var = getSysVar(actor)
	if not var then return end

	--重置购买次数
	var.canBuyCount = CAN_BUY_COUNT
	var.buyCount = 0

	local oldExpMonCount = var.expMonCount or 0

	--增加数量
	if not var.expMonCount or var.expMonCount <= 0 then
		var.expMonCount = addExpMonCountByDay
	else
		local aftCount = var.expMonCount + addExpMonCountByDay
		if var.expMonCount < maxExpMonCount then
			var.expMonCount = (aftCount >= maxExpMonCount) and maxExpMonCount or aftCount
		end
	end

	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)), "fuben", "", "userid:"..LActor.getActorId(actor), "supertime", "local", tostring(oldExpMonCount), tostring(var.expMonCount), "reset", lfBI)
end

function resetMonExpVal(actor, nExpVal, nExpWay)
	if not actor or not nExpVal or not nExpWay or nExpWay ~= clKillMonsterExp then return end

	local var = getSysVar(actor)
	if not var then return end

	if var.expMonCount and var.expMonCount <= 0 then return end

	local sceneId = LActor.getSceneId(actor)
	if sceneId == 0 then return end

	local val = sceneExpConf[sceneId]
	if not val then return end

	return val
end

actorexp.regBaseExpResetEvent(FUBEN_ID, resetMonExpVal)
mainevent.regResetFunc(resetByDay)
netmsgdispatcher.reg(sysId, protocol.cBuyExpMonCnt, onBuyMonCount)
