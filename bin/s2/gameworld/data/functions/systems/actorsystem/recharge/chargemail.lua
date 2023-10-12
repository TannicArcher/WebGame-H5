--充值邮件发送
module("chargemail", package.seeall)

local function getMailVar(actor)
	local var = LActor.getDynamicVar(actor)
	if var == nil then return nil end
	var.chargemail = var.chargemail or {}
	return var.chargemail
end

local function setMailFlag(actor,flag)
	local var = getMailVar(actor)
	
	if var ~= nil then
		var.flag = flag
	end
end

local function getMailFlag(actor)
	local var = getMailVar(actor)
	if var == nil then
		return
	end
	var.flag = var.flag or false
	return var.flag
end

local function fillinAndSendMail(actor, val, id, ...)
	local content = string.format(ChargeConfig[id].content,val,...)
	local mailData = {
		head=ChargeConfig[id].title,
		context=content,
		tAwardList={}
	}
	mailsystem.sendMailById(LActor.getActorId(actor), mailData)
end

--普通充值邮件
function sendMailByRecharge(actor, val)
    fillinAndSendMail(actor, val, 1)
end

--首冲邮件
function sendMailByFirstCharge(actor, val, ...)
	setMailFlag(actor,true)
	fillinAndSendMail(actor, val, 2, ...)
end

--充值套餐邮件
function sendMailByChargeItem(actor, val, ...)
	setMailFlag(actor,true)
	fillinAndSendMail(actor, val, 3, ...)
end

function sendRechargeMail(actor, val)

	--已发邮件的，不用再发
	local flag = getMailFlag(actor)
	setMailFlag(actor,false)
	if flag == nil or flag == false then
		--默认邮件
		sendMailByRecharge(actor, val)
		return
	end
end

function onRecharge(actor, val)
	--推迟执行,保证执行順序,确认普通充值邮件在首冲已发邮件情况下不重复发送
	LActor.postScriptEventLite(actor,300,sendRechargeMail,val)
end

actorevent.reg(aeRecharge, onRecharge)