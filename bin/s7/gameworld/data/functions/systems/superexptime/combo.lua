--[[
	author = 'Roson'
	time   = 24.03.2015
	name   = 连斩管理
	ver    = 0.1
]]

module("systems.superexptime.combo" , package.seeall)
setfenv(1, systems.superexptime.combo)

local sbase      = require("systems.superexptime.sbase")
local pTimer     = require("base.scripttimer.postscripttimer")
local actorexp   = require("systems.actorsystem.actorexp")
local act_base   = require("systems.actorsystem.actorbase")
local fubenevent = require("actorevent.fubenevent")
local actorevent = require("actorevent.actorevent")
local monevent   = require("monevent.monevent")
local expmonmgr  = require("systems.superexptime.expmonmgr")

local SuperExpTimeConf = sbase.SuperExpTimeConf
local monsterIds       = SuperExpTimeConf.monsterIds
local comboRangeConf   = SuperExpTimeConf.comboRangeConf
local GameLog          = act_base.GameLog
local clKillMonsterExp = GameLog.clKillMonsterExp
local FUBEN_ID         = SuperExpTimeConf.fubenId
local LDataPack        = LDataPack
local LActor           = LActor

local INT_MAX_NUM = INT_MAX_NUM

local sysId    = sbase.sysId
local protocol = sbase.protocol

local getNowTime = System.getNowTime

function getSysVar(actor)
	local var = sbase.getSysVar(actor)
	if not var then return end

	if var.combo == nil then var.combo = {} end

	local varCombo = var.combo
	if varCombo.comboCnt == nil  then varCombo.comboCnt = 0 end

	return varCombo
end

function getComboCnt(actor)
	local var = getSysVar(actor)
	if not var then return 0 end
	return var.comboCnt or 0
end

function sendComboPack(actor, comboCnt, isEnter, expMonCount)
	comboCnt = comboCnt or getComboCnt(actor)

	local pack = LDataPack.allocPacket(actor, sysId, protocol.sUpdateComboCnt)
	if not pack then return end

	expMonCount = expMonCount or expmonmgr.getExpMonCount(actor)
	LDataPack.writeData(pack, 3,
		dtUint, comboCnt or 0,
		dtChar, isEnter and 1 or 0,
		dtUint, expMonCount)
	LDataPack.flush(pack)
end

function getResetInfo(comboCnt)
	for _,v in ipairs(comboRangeConf) do
		if v.begIndx <= comboCnt and v.endIndx >= comboCnt then
			return v
		end
	end
end

function checkComboAndReset(actor)
	local var = getSysVar(actor)
	if not var or not var.resetTime then return end

	if var.resetTime > getNowTime() then return end

	local fubenId = LActor.getFubenId(actor)
	if fubenId ~= FUBEN_ID then
		var.resetTime = INT_MAX_NUM	--设置不再重置
		if var.resetId then
			local resetId = var.resetId
			var.resetId = nil
			pTimer.cancelScriptTimer(actor, resetId)
		end
		return
	end

	if var.isLock then return end

	var.comboCnt = 0
	sendComboPack(actor, 0, true)
end

function addCombo(monster, actor, monId)
	local var = getSysVar(actor)
	if not var then return end

	if var.comboCnt == nil then var.comboCnt = 0 end
	var.comboCnt = var.comboCnt + 1
	var.isLock = nil

	local info = getResetInfo(var.comboCnt)
	var.resetTime = getNowTime() + (info and info.resetTime or 0)

	--发送连斩更新包
	sendComboPack(actor, var.comboCnt)
	--击杀后启动定时器（如果不存在）
	if not var.resetId then
		var.resetId = pTimer.postScriptEvent(actor, 1 * 1000, function ( ... )
			checkComboAndReset(...)
		end, 1 * 1000, -1)
	end
end

--这里处理经验的加成计算
function fixKillMonsterExp(actor, expVal, expWay)
	if not actor or not expVal or not expWay or expWay ~= clKillMonsterExp then return end

	--减掉一个怪物
	expmonmgr.expMonMoreThanOne(actor)

	local comboCnt = getComboCnt(actor)
	if not comboCnt then return end

	--这里进行连斩加成
	local info = getResetInfo(comboCnt)
	if not info then return end

	local multiple = info.multiple - 1
	if multiple < 0 then return 0 end

	return multiple
end

--关闭定时器
function clearTimer(actor)
	local var = getSysVar(actor)
	if not var then return end

	var.resetTime = INT_MAX_NUM	--设置不再重置
	var.isLock = true

	if not var.resetId then return end

	local resetId = var.resetId
	var.resetId = nil
	pTimer.cancelScriptTimer(actor, resetId)
end

function enterFuben(actor)
	sendComboPack(actor, nil, true)
end

actorevent.reg(aeUserLogout, clearTimer)
fubenevent.registerFubenExit(FUBEN_ID, clearTimer)
fubenevent.registerFubenEnter(FUBEN_ID, enterFuben)

function initRegMonDieEvent( ... )
	for _,id in ipairs(monsterIds) do
		monevent.regDieEvent(id, addCombo)
	end
end

table.insert(InitFnTable, initRegMonDieEvent)
actorexp.regSuperExpTimeEvent(FUBEN_ID, fixKillMonsterExp)

