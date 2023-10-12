module("systems.txmarket.txmarketmisson", package.seeall)
setfenv(1, systems.txmarket.txmarketmisson)

require("txmarket.txmarketconfig")

local base = require("systems.txmarket.txmarketbase")
local actorevent       = require("actorevent.actorevent")
local gmsystem  = require("systems.gm.gmsystem")
gmCmdHandlers = gmsystem.gmCmdHandlers

local System = System
local LActor = LActor

local function getRealContinueDay( continueDay )
	local tmp = System.bitOpSetMask(continueDay, 31, false)

	return tmp
end

local function canSendToPhp( record, mIdx )
	--已经领过就不再发了，目前最多支持32个
	return not System.bitOPMask(record, mIdx - 1)
end

local function onContinueDayChange( actor, days )
	local conf = TxMarkConfig.login
	if not conf then return end

	local var = base.getActorStaticVar(actor)
	local record = var.record or 0
	local sendRecord = var.sendRecord or 0

	for i, v in ipairs(conf) do
		if v.val <= days then
			if canSendToPhp(record, v.mIdx) and canSendToPhp(sendRecord, v.mIdx) then
				var.sendRecord = System.bitOpSetMask(sendRecord, v.mIdx - 1, true)
				for j,k in ipairs(v.missonId) do
					base.onMarketMissonFinish(actor, k, LActor.getAccountName(actor), LActor.getServerId(actor), v.step[j])
				end
			end
		else
			break
		end
	end
end

local function addContinueDay( actor, day, force, zero )
	local sended = false 
	if force or not System.bitOPMask(day, 31) then
		day = getRealContinueDay(day)
		if zero then
			day = 1
		else
			day = day  + 1
		end

		onContinueDayChange( actor, day )
		day = System.bitOpSetMask(day, 31, true)

		sended = true
	end

	return day, sended
end

local function onLogin( actor )
	local var = base.getActorStaticVar(actor)
	local days = var.continueDay or 0

	local now = System.getNowTime()
	local logoutTime = LActor.getLastLogoutTime(actor)
	local diff = System.getDayDiff(now, logoutTime)

	local zero = false
	if diff >= 2 then
		zero = true
	end

	local sended = false
	var.continueDay, sended = addContinueDay( actor, days, false, zero )

	if not sended then
		onContinueDayChange( actor, 1 )  --登录没发过就就要发一次
	end
end

local function onlineNewDay( actor, login )
	local var = base.getActorStaticVar(actor)
	local days = var.continueDay or 0
	var.continueDay = System.bitOpSetMask(days, 31, false)

	if login == 1 then return end

	local sended = false
	var.continueDay, sended = addContinueDay( actor, var.continueDay, true )
end

local function onLevelUp( actor )
	local level = LActor.getRealLevel(actor)

	local conf = TxMarkConfig.level
	if not conf then return end

	local var = base.getActorStaticVar(actor)
	local record = var.record or 0
	local sendRecord = var.sendRecord or 0

	for i,v in ipairs(conf) do
		if v.val <= level then
			if canSendToPhp(record, v.mIdx) and canSendToPhp(sendRecord, v.mIdx) then
				var.sendRecord = System.bitOpSetMask(sendRecord, v.mIdx - 1, true)
				for j,k in ipairs(v.missonId) do
					base.onMarketMissonFinish(actor, k, LActor.getAccountName(actor), LActor.getServerId(actor), v.step[j])
				end
			end
		else
			break
		end
	end
end

gmCmdHandlers.addcontinueday = function ( actor )
	local var = base.getActorStaticVar(actor)
	local days = var.continueDay or 0
	local sended = false
	var.continueDay, sended = addContinueDay( actor, days, true )

	return true
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onlineNewDay)
actorevent.reg(aeLevel, onLevelUp)
