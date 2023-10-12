--[[保存在玩家上的信息
	endTime 月卡结束时间
	count   可领取次数
	lastDay 最新领取月卡奖励时间
	sendEndMail 发送到期邮件,1表示未发送，2已发送
	privilege 1为没开通，2已开通
	updateDay 最新的发送特权日常奖励邮件天数
--]]


module("monthcard", package.seeall)

hourSec = 60 * 60
daySec = 24 * hourSec

--获取月卡信息
local function getData(actor) 
	local var = LActor.getStaticVar(actor)

	if nil == var.monthcard then
		var.monthcard = {}
	end

	if nil == var.monthcard.endTime then
		var.monthcard.endTime = 0
	end

	if nil == var.monthcard.lastDay then
		var.monthcard.lastDay = 0
	end

	if nil == var.monthcard.count then
		var.monthcard.count = 0
	end

	if nil == var.monthcard.sendEndMail then
		var.monthcard.sendEndMail = 1
	end

	if nil == var.monthcard.privilege then
		var.monthcard.privilege = 1
	end

	if nil == var.monthcard.updateDay then
		var.monthcard.updateDay = 0
	end

	return var.monthcard
end

--发送到期邮件,1表示已发送，0未发送
local function sendEndMall(actor)
	local mail_data = {}
	mail_data.head       = MonthCardConfig.monthCardEndMailHead
	mail_data.context    = MonthCardConfig.monthCardEndMailContext
	mail_data.tAwardList = {}
	mailsystem.sendMailById(LActor.getActorId(actor),  mail_data)
end

--是否已开通月卡
function isOpenMonthCard(actor) 
	local var = getData(actor)
	return System.getNowTime() < var.endTime
end

--是否已开通特权
function isOpenPrivilege(actor) 
	local var = getData(actor)
	return var.privilege == 2
end

--更新月卡挂机属性
function updateAttributes(actor, sysType) 
	if false == isOpenMonthCard(actor) then return end

	for i,iv in pairs(MonthCardConfig.specialAttributes) do 
		specialattribute.add(actor,  iv.type, iv.value, sysType)
	end
end

--发送月卡信息
local function sendMonthCardData(actor)
	local var = getData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_MonthCardData)

	local leftTime = var.endTime - System.getNowTime()
	if 0 > leftTime then leftTime = 0 end

	LDataPack.writeUInt(npack, leftTime)
	LDataPack.writeInt(npack, var.privilege)
	LDataPack.flush(npack)
end

--增加月卡属性
local function addMonthCardAttr(actor)
	if false == isOpenMonthCard(actor) then return end

	local attr = LActor.getMonthCardAttr(actor)
	attr:Reset()

	local tAttrList = {}
	local attrConfig = MonthCardConfig.monthCardAttr

	for _, tAttr in pairs(attrConfig or {}) do
		tAttrList[tAttr.type] = (tAttrList[tAttr.type] or 0) + tAttr.value
	end	

	for type, value in pairs(tAttrList) do
		attr:Set(type, value)
	end

	LActor.reCalcAttr(actor)
end

--移除月卡属性
local function removeMonthCardAttr(actor)
	local attr = LActor.getMonthCardAttr(actor)
	attr:Reset()

	LActor.reCalcAttr(actor)
end

--更新背包数量信息
local function updateGridNumber(actor)
	--1为已购买，2为过期
	local basicData = LActor.getActorData(actor)

	if true == isOpenMonthCard(actor) then
		basicData.monthcard = 1
	else
		basicData.monthcard = 2
	end

	LActor.updataEquipBagCapacity(actor)
end

--月卡到期判断，一分钟跑一次
local function onRun(actor)
	local var = getData(actor)

	--没开通跳出
	if 0 == var.endTime then return end

	--没到期就跳出
	if true == isOpenMonthCard(actor) then return end

    --到期处理
	if 1 == var.sendEndMail then 
		updateGridNumber(actor)
		sendEndMall(actor)

		var.sendEndMail = 2

		removeMonthCardAttr(actor)

		print("monthcard is over,actorId:"..tostring(LActor.getActorId(actor)))
	end
end

--更新特权属性
local function updatePrivilegeAttr(actor)
	if false == isOpenPrivilege(actor) then return end

	local attr = LActor.getPrivilegeAttr(actor)
	attr:Reset()

	local tAttrList = {}
	local attrConfig = MonthCardConfig.privilegeAttr

	for _, tAttr in pairs(attrConfig or {}) do
		tAttrList[tAttr.type] = (tAttrList[tAttr.type] or 0) + tAttr.value
	end	

	for type, value in pairs(tAttrList) do
		attr:Set(type, value)
	end

	LActor.reCalcAttr(actor)
end

--发送月卡日常奖励邮件
local function sendMonthCardRewardMail(actor)
	local var = getData(actor)

	--判断是否还可以领取
	if 0 >= var.count then return end

	local days = 0
	if 0 == var.lastDay then 
		days = 1
	else
		days = utils.getDay(os.time()) - var.lastDay
	end 

	if 0 >= days then return end

	--不能大于可领取次数
	if days >= var.count then days = var.count end

	local actorId = LActor.getActorId(actor)

	local reward = nil
	if true == isOpenPrivilege(actor) then
		reward = MonthCardConfig.monthCardMailAwardB
	else
		reward = MonthCardConfig.monthCardMailAwardA
	end

	--print("utils.getDay(System.getNowTime())utils.getDay(System.getNowTime()):"..utils.getDay(os.time()))
	--print("var.lastDayvar.lastDayvar.lastDayvar.lastDay:"..var.lastDay)
	--print("daysdaysdaysdaysdays:"..days)

	var.lastDay = utils.getDay(os.time())
	var.count = var.count - days
	if 0 > var.count then var.count = 0 end

	
	while (0 < days) do 
		local mail_data = {}
		mail_data.head = MonthCardConfig.monthCardRewardMailHead
		mail_data.context = MonthCardConfig.monthCardRewardMailContext
		mail_data.tAwardList = reward
		mailsystem.sendMailById(actorId, mail_data)

		days = days - 1
	end
end

--发送特权日常奖励邮件
local function sendPrivilegeRewardMail(actor)
	if false == isOpenPrivilege(actor) then return end

	local actorId = LActor.getActorId(actor)
	local var = getData(actor)
	local days = 0
	if 0 == var.updateDay then 
		days = 1
	else
		days = utils.getDay(os.time()) - var.updateDay
	end

	while (0 < days) do 
		local mail_data = {}
		mail_data.head = MonthCardConfig.privilegeRewardMailHead
		mail_data.context = MonthCardConfig.privilegeRewardMailContext
		mail_data.tAwardList = MonthCardConfig.privilegeMailAward
		mailsystem.sendMailById(actorId, mail_data)

		days = days - 1
	end

	var.updateDay = utils.getDay(os.time())
end

--发送月卡首购奖励邮件
local function sendMonthCardFirstBuyRewardMail(actor)
	local actorId = LActor.getActorId(actor)
	local mail_data = {}
	mail_data.head = MonthCardConfig.monthCardOpenMailHead
	mail_data.context = MonthCardConfig.monthCardOpenContext
	mail_data.tAwardList = MonthCardConfig.monthCardFirstReward
	mailsystem.sendMailById(actorId, mail_data)
end

--发送开通特权奖励邮件
local function sendPrivilegeOpenRewardMail(actor)
	local actorId = LActor.getActorId(actor)
	local mail_data = {}
	mail_data.head = MonthCardConfig.privilegeOpenMailHead
	mail_data.context = MonthCardConfig.privilegeOpenMailContext
	mail_data.tAwardList = MonthCardConfig.privilegeOpenReward
	mailsystem.sendMailById(actorId, mail_data)
end

--购买月卡
function buyMonthCard(actor)
	local var = getData(actor)
	local isOpen = isOpenMonthCard(actor)
	local endTimes = System.getNowTime()

	--如果还处于开通状态，说明是续期
	if isOpen then endTimes = var.endTime end

	--月卡首购发奖励
	if 0 == var.endTime then sendMonthCardFirstBuyRewardMail(actor) end

	var.endTime = endTimes + MonthCardConfig.monthCardDays * daySec
	var.count = var.count + MonthCardConfig.monthCardDays

	--开通后发第一天的奖励
	if not isOpen then 
		var.lastDay = 0
		var.sendEndMail = 1
		updateGridNumber(actor)

		sendMonthCardRewardMail(actor)
	end

	sendMonthCardData(actor)
	actorevent.onEvent(actor, aeOpenMonthCard)

	--local data = LActor.getActorData(actor)
	--data.recharge = data.recharge + MonthCardConfig.monthCardMoney
	--actorevent.onEvent(actor, aeRecharge, MonthCardConfig.monthCardMoney)

	--开通才加属性,续期不加属性
	if not isOpen then addMonthCardAttr(actor) end

	noticemanager.broadCastNotice(MonthCardConfig.monthCardNotice, LActor.getName(actor))
end

--购买特权
function buyPrivilege(actor)
	--购买了月卡才可以购买特权
	local actorId = LActor.getActorId(actor)
	if false == isOpenMonthCard(actor) then print("monthcard.buyPrivilege: privilege is not open, actorId:"..tostring(actorId)) return end

	--不能重复购买
	if true == isOpenPrivilege(actor) then print("monthcard.buyPrivilege: privilege is already open, actorId:"..tostring(actorId)) return end

	local var = getData(actor)
	var.privilege = 2

	--发送开通奖励
	sendPrivilegeOpenRewardMail(actor)
	sendPrivilegeRewardMail(actor)

	sendMonthCardData(actor)

	--local data = LActor.getActorData(actor)
	--data.recharge = data.recharge + MonthCardConfig.privilegeMoney
	--actorevent.onEvent(actor, aeRecharge, MonthCardConfig.privilegeMoney)

	updatePrivilegeAttr(actor)
end

function buyMonth(actorid) 
	local actor = LActor.getActorById(actorid)
	if actor then
		buyMonthCard(actor)
	else
		System.buyMonthCard(actorid)
	end
end

function buyPrivilegeCard(actorid) 
	local actor = LActor.getActorById(actorid)
	if actor then
		buyPrivilege(actor)
	else
		System.buyPrivilege(actorid)
	end
end

--获取贵族加成
function getSmeltPrecent(actor)
	if true == isOpenPrivilege(actor) then return MonthCardConfig.smeltPrecent or 0 end

	return 0
end

--贵族副本经验加成
function updateFubenExp(actor, exp)
	if false == monthcard.isOpenPrivilege(actor) then return exp end

	return exp + math.ceil(exp * (MonthCardConfig.expFubenPrecent or 0) / 100)
end

--内功消耗金币减少
function updateNeiGongGold(actor, gold)
	if false == monthcard.isOpenPrivilege(actor) then return gold end

	return gold - math.ceil(gold * (MonthCardConfig.neiGongGoldPrecent or 0) / 100)
end

--副本扫荡折扣
function updateSweepCost(actor, gold)
	if false == monthcard.isOpenMonthCard(actor) then return gold end

	return gold - math.ceil(gold * (MonthCardConfig.sweepPrecent or 0) / 100)
end

local function onLogin(actor) 
	sendMonthCardData(actor)
	sendMonthCardRewardMail(actor)
	sendPrivilegeRewardMail(actor)
	updateGridNumber(actor)
end

local function onBeforeLogin(actor)
	addMonthCardAttr(actor)
	updatePrivilegeAttr(actor)
end

local function onNewDayArrive(actor)
	sendMonthCardRewardMail(actor)
	sendPrivilegeRewardMail(actor)
end

_G.onMonthCardRun = onRun
_G.buyMonthCard = buyMonthCard
_G.buyPrivilege = buyPrivilege
_G.getSmeltPrecent = getSmeltPrecent

actorevent.reg(aeNewDayArrive, onNewDayArrive)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onBeforeLogin)