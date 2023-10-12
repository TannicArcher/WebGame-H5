module("monevent.monevent", package.seeall)
setfenv(1, monevent.monevent)

local monDie = {}
local monCreate = {}
local gatherFinish = {}
local gatherCheck = {}
local monAttack = {}
local monKillAll = {}
local monHpChange = {}
local monDamage = {}
local monTrap = {}
local monVestChange = {}

-- 通用的注册事件的函数， 其中tab是各个事件的函数表，比如 monDie,
-- cFunc是c++提供的时间注册函数
local function reg(monId, proc, tab, cFunc)
	if not proc then
		print("regEvent is nil with monId ".. monId)
	end
	monId = tonumber(monId)
	local callTbl = tab[monId]
	if not callTbl or type(callTbl) ~= "table" then
		tab[monId] = {}
		callTbl = tab[monId]
		--注册这个怪物死亡需要触发脚本 
		if cFunc ~= nil then cFunc(monId, true) end
	end

	for _, func in ipairs(callTbl) do
		if func == proc then
			return false
		end
	end
	table.insert(callTbl, proc)

	return true
end

local function onEvent(tbl, monId, ...)
	local callTbl = tbl[monId]

	if callTbl == nil then return end

	for _, func in ipairs(callTbl) do
		if tbl ~= gatherCheck then
			func(unpack(arg))
		else
			if not func(unpack(arg)) then return false end
		end
	end
	return true
end

function regDieEvent(monId, proc)
	reg(monId, proc, monDie, System.regMonsterDie)
end

function onMonDieEvent(monster, killer, monId)
	onEvent(monDie, monId, monster, killer, monId)
end

function regCreateEvent(monId, proc)
	reg(monId, proc, monCreate, System.regMonsterCreate)
end

function onMonCreateEvent(monster, monId)
	onEvent(monCreate, monId, monster, monId)
end

function regGatherFinish(monId, proc)
	reg(monId, proc, gatherFinish, System.regGatherFinish)
end

function onGatherFinish(monster, killer, monId)
	onEvent(gatherFinish, monId, monster, killer, monId)
end

function regGatherCheck(monId, proc)
	reg(monId, proc, gatherCheck, nil)
end

function onGatherCheck(monster, killer, monId)
	return onEvent(gatherCheck, monId, monster, killer, monId)
end

function regMonAttack(monId, proc)
	reg(monId, proc, monAttack, System.regMonsterAttacked)
end

function onMonAttack(monster, status, attacker, monId)
	onEvent(monAttack, monId, monster, status, attacker, monId)
end

function regMonKillAll(sceneId, proc)
	reg(sceneId, proc, monKillAll, nil)
end

function onMonKillAll(sceneId, scenePtr, flag, et)
	onEvent(monKillAll, sceneId, scenePtr, flag, et, sceneId)
end

function regMonHpChange(monId, proc)
	reg(monId, proc, monHpChange, System.regMonsterHpChange)
end

function onMonHpChange(monster, rate, monId, attacker)
	onEvent(monHpChange, monId, monster, rate, monId, attacker, monId)
end

function regMonDamage(monId, proc)
	reg(monId, proc, monDamage, System.regMonsterDamage)
end

function onMonDamage(monster, val, et, monId)
	onEvent(monDamage, monId, monster, val, et, monId)
end

function regMonTrapTakeEffect(monId, proc)
	reg(monId, proc, monTrap)
end

function onTrapTakeEffect( monster, monId, et, trapTimes )
	onEvent(monTrap, monId, monster, monId, et, trapTimes, monId)
end

function regMonsterVestChange(monId, proc)
	reg(monId, proc, monVestChange)
end

function onMonsterVestChange(monster, monId, hVest)
	onEvent(monVestChange, monId, monster, monId, hVest, monId)
end

function parseMonsterName(monstername)
	if not monstername then return end
	local findpos = string.find(monstername, "%d")
	if not findpos then
		return monstername
	else
		return string.sub(monstername, 1, findpos-1) or ""
	end
end

_G.OnMonsterKilled = onMonDieEvent
_G.OnMonsterAttacked = onMonAttack
_G.OnMonsterCreate = onMonCreateEvent
_G.OnGatherFinished = onGatherFinish
_G.onGatherCheck = onGatherCheck
_G.OnMonsterAllKilled = onMonKillAll
_G.OnMonsterHpChanged = onMonHpChange
_G.OnMonsterDamage = onMonDamage
_G.onMyTrapTakeEffect = onTrapTakeEffect
_G.OnMonsterVestChange = onMonsterVestChange
System.parseMonsterName = parseMonsterName



