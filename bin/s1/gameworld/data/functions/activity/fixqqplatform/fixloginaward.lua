--[[
	author  = 'Roson'
	time    = 09.22.2015
	name    = 登录有礼
	ver     = 0.1
]]

--[[
** 修复规则 **
1.刷了11次以上的玩家，默认让玩家扣掉70%。
2.平均扣除已经添加的属性
]]

module("activity.fixqqplatform.fixloginaward" , package.seeall)
setfenv(1, activity.fixqqplatform.fixloginaward)

local actorevent = require("actorevent.actorevent")

local fixbase    = require("activity.fixqqplatform.fixbase")
local petfeed    = require("systems.pet.petfeed")
local petbase    = require("systems.pet.petbase")

local petConf  = petConf
local ATTRFROM = 0  --性格属性

require("activity.fixqqplatform.fixloginawardconf")
local FixLoginAwardConf = FixLoginAwardConf
local SRV_ID, ACCOUNT_ID, AWARD_COUNT = 1, 2, 3

function initKillList( ... )
	local killList = {}
	for _,c in ipairs(FixLoginAwardConf) do
		local srvId = c[SRV_ID]
		local account = c[ACCOUNT_ID]
		local count = c[AWARD_COUNT]
		if srvId and account and count then
			killList[srvId] = killList[srvId] or {}
			local srvKillList = killList[srvId]
			srvKillList[account] = count
		end
	end
	return killList
end

local killList = initKillList()

function getFixVar(actor)
	local var = fixbase.getFixVar(actor)
	if not var then return end

	if var.fixloginaward == nil then var.fixloginaward = {} end
	return var.fixloginaward
end

function getPetFeedVar(actor)
	local var = petbase.getPetSysVar(actor)
	if not var then return end

	return var.petFeed
end

--扣除属性
function removeAttr(actor, delCnt)
	if not actor or not delCnt then return end

	local petFeedVar = getPetFeedVar(actor)
	if not petFeedVar then return end

	local attrs = {}
	for i,conf in ipairs(petConf.petFeed.attrsRange) do
		local midVal = math.ceil((conf.rangeMin + conf.rangeMax)/2)
		attrs[i] = midVal
	end

	--修正数据
	for i=1,(delCnt * #attrs) do
		for k,v in pairs(attrs) do
			if delCnt <= 0 then break end
			local attrVal = petFeedVar[k] or 0
			local fitVal = attrVal - v
			if attrVal > 0 and fitVal >= 0 then
				petFeedVar[k] = fitVal
				delCnt = delCnt - 1
			end
		end
	end

	petfeed.refreshAttr(actor)
end

--扣除亲密度
function removeFeed(actor, delCnt)
	local defCount = LActor.petGetQmd(actor)
	LActor.petSetQmd(actor, math.max(0, defCount - delCnt))
end

function getdelCount(actor)
	local srvId = LActor.getServerId(actor)
	local account = LActor.getAccountName(actor)

	local srvKillList = killList[srvId]
	if not srvKillList then return end

	local count = srvKillList[account]
	if not count or count <= 10 then return end

	return math.ceil((count - 10) * 5 * 0.7)
end

--登录扣除
function onLogin(actor)
	local var = getFixVar(actor)
	if not var then return end
	if var.fixDay_10_1 ~= nil then return end

	local delCount = getdelCount(actor)
	if not delCount then return end

	local account   = LActor.getAccountName(actor)
	local timeNow   =  System.getNowTime()
	var.fixDay_10_1 = timeNow

	print(string.format("[FIX_LOGIN_AWARD] [%s] [%s] [%s]", account or "NA", timeNow or 0, delCount or 0))

	removeFeed(actor, delCount)
	removeAttr(actor, delCount)

	LActor.refreshAbility(actor)
	petbase.sendPetInfo(actor, actor)
end

actorevent.reg(aeUserLogin, onLogin)

