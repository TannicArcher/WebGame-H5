module("systems.txmarket.txmarketbase", package.seeall)
setfenv(1, systems.txmarket.txmarketbase)

require("txmarket.txmarketconfig")
local webSys = require("systems.web.websystem")
local mailSys = require("systems.mail.mailsystem")
local actorevent       = require("actorevent.actorevent")

local System = System
local LActor = LActor
local tips = Lang.ScriptTips

function onMarketMissonFinish( actor, missonId, accountname, sid, step )
	if not missonId or not accountname or not sid or not step then
		print("onMarketMissonFinish called whith bad param", missonId, accountname, sid, step)
		return
	end

	--"TaskMarket/informCompletion/?contractid=浠诲姟ID&openid=openid&serverid=鏈嶅姟鍣╥d&step="
	SendUrl("/TaskMarket/informCompletion/?", 
		"&contractid="..missonId.."&openid="..accountname.."&serverid="..System.getServerId().."&actorid="..LActor.getActorId(actor).."&step="..step)
end

local function findMidx( missonId, step )
	local function tmp( conf )
		for i,v in ipairs(conf) do
			for j,k in ipairs(v.missonId) do
				if k == missonId and v.step[j] == step then
					return v.mIdx, v.mailTips, v.itemId[j]
				end
			end
		end
	end

	local ret, ret2, ret3 = tmp(TxMarkConfig.login)
	if ret then return ret, ret2, ret3 end
	ret, ret2, ret3 = tmp(TxMarkConfig.level)
	
	return ret or 0, ret2 or tips.jsrw001, ret3
end

local function getGlobalVar(  )
	local sys_var = System.getStaticVar()
	if not sys_var then return end

	if not sys_var.txmarketinfo then
		sys_var.txmarketinfo = {}
	end

	return sys_var.txmarketinfo
end

local function giveAward( actor, missonId, step )
	local mIdx, tips, itemId = findMidx(missonId, step)
	if mIdx == 0 then
		print("giveAward param error............", LActor.getAccountName(actor), missonId, step)
		return
	end

	local var = getActorStaticVar(actor)
	local record = var.record or 0

	if System.bitOPMask(record, mIdx - 1) then
		print("onMarketMissonAward:error............repeat award", mIdx)
		return
	end

	var.record = System.bitOpSetMask(record, mIdx - 1, true)
	local itemName = Item.getItemName(itemId)
	if itemName then
		sendGmMailByActorId(LActor.getActorId(actor), tips, mailSys.TYPE_ITEM, itemId, 1, 1, 0, 0, "onMarketMissonAward")
	end
end

local function onMarketMissonAward( accountname, p1, missonId, p3, step, actorid )
	actorid = tonumber(actorid)

	local actor = LActor.getActorById(actorid)
	if actor then
		giveAward( actor, missonId, tonumber(step) )
	else
		local sys_var = getGlobalVar()
		local cnt = sys_var.cnt or 0
		sys_var[cnt + 1] = {}

		local tmp = sys_var[cnt + 1]
		tmp.actorid = tonumber(actorid)
		tmp.missonId = missonId
		tmp.step = tonumber(step) 

		sys_var.cnt = cnt + 1

		if cnt > 10 then
			print("warning, onMarketMissonAward may too big:", cnt)
		end
	end
end

function getActorStaticVar(actor)
	local var = LActor.getSysVar(actor)
	if var.txmarketinfo == nil then
		var.txmarketinfo = {}
	end

	return var.txmarketinfo
end

local function onLogin( actor )
	local sys_var = getGlobalVar()
	local cnt = sys_var.cnt or 0
	local actorid = LActor.getActorId(actor)

	local findIdx = 0
	for i=1,cnt do
		local tmp = sys_var[i]
		if tmp and tmp.actorid == actorid then
			findIdx = i
			giveAward( actor, tmp.missonId, tmp.step )
			break
		end
	end

	if findIdx ~= 0 then
		for i=findIdx + 1, cnt do
			local tmp = sys_var[i-1]
			local tmp2 = sys_var[i]

			if tmp and tmp2 then
				tmp.actorid = tmp2.actorid
				tmp.missonId = tmp2.missonId
				tmp.step = tmp2.step
			else
				print("error, txmarket param is nil:", tmp, tmp2, i)
			end
		end

		sys_var[cnt] = nil
		sys_var.cnt = cnt - 1
	end
end

local function bugFix( ... )
	local sys_var = getGlobalVar()
	local cleared = sys_var.cleared or 0

	if cleared == 0 then
		print("txMarketMisson clean old data.......................")
		local cnt = sys_var.cnt or 0
		for i=1, cnt do
			sys_var[i] = nil
		end

		sys_var.cnt = 0
		sys_var.cleared = 1
	end
end

webSys.reg(webSys.APITYPE.TX_MARKET, onMarketMissonAward)
actorevent.reg(aeUserLogin, onLogin)
table.insert(InitFnTable, bugFix)
