-- 邮件系统测试
module("test.test_mailsystem" , package.seeall)
setfenv(1, test.test_mailsystem)
local mailsys    = require("systems.mail.mailsystem") --邮件系统
local checkFunc  = require("test.assert_func") --测试方法
local actormoney = require("systems.actorsystem.actormoney")

local LDataPack = LDataPack
local LActor    = LActor

local mtBindCoin     = mtBindCoin
local TYPE_MONEY     = mailsys.TYPE_MONEY
local MAIL_BOX_MAX   = mailsys.MAIL_BOX_MAX
local SEND_MAIL_COST = mailsys.SEND_MAIL_COST

--随机的物品ID
local itemIdAtts = {
	1100, 7100, 6121, 3121, 2121, 9121
}

local boolAtts = {
	true, false
}

--***********************************************
--README-------------基本方法组------------------
--***********************************************
--发送一封GM邮件给玩家
local function sendGMMailToActor(actor, isLite)
	local mailType = 1
	if isLite then mailType = 0 end
	local mailSort = checkFunc.getRandomOne(itemIdAtts)
	local num = 1
	sendGmMailByActor(actor, "TEST", mailType, mailSort, num)
end

--获取邮件数量
local getMailCount = mailsys.getMailCount

--清空玩家所有邮件
local function clearAllMail(actor)
	local mailList = mailsys.initMailList(actor)
	local delMailId = {}
	for _,mail in pairs(mailList) do
		table.insert(delMailId, mail.mailId)
	end
	mailsys.sendDbByFunc(actor, delMailId, mailsys.SendDbDeleteMail)
	mailList = {}
	coroutine.yield()
end

--清空玩家的背包
local function clearDepot(actor)
	LActor.cleanDepot(actor, ipBag)
end

local function setDepotNilBox(actor, nilBox)
	clearDepot(actor)
	--只塞武器快速控制格子的剩余数量
	local resCount = LActor.getStoreRestCount(actor)
	if nilBox >= resCount then return end
	for i=1,resCount - nilBox do
		LActor.addItemByPosition(actor, ipBag, 1200, 0, 0, 0, 0) --塞武器进去
	end
end

--发送邮件给玩家
--lite 无附件 --full带附件
local function sendToMailBox(actor, lite, full)
	for i=1,lite do
		sendGMMailToActor(actor, true)
	end
	for i=1,full do
		sendGMMailToActor(actor, false)
	end
	coroutine.yield()
end

--***********************************************
--README------------通用测试环境-----------------
--***********************************************

--初始化邮件测试环境
local function initMailBox(actor, lite, full)
	clearAllMail(actor)
	sendToMailBox(actor, lite, full)
end

--获取初始化lite,full参数
local function getLiteAndFull()
	local MAIL_BOX_MAX = mailsys.MAIL_BOX_MAX
	local lite = math.random(50, 140) --无附件
	local full = MAIL_BOX_MAX - lite --带附件
	return lite, full
end

--设置背包的剩余空格数量
local function initBagresCount(actor, lite, full, mod)
	--全空
	if mod == 1 then
		clearDepot(actor)
	--相同
	elseif mod == 2 then
		setDepotNilBox(actor, full)
	--不足
	elseif mod == 3 then
		local half_full = math.ceil(full / 2)
		local count = math.random(half_full, full)
		setDepotNilBox(actor, count)
	--全满
	else
		setDepotNilBox(actor, 0)
	end
	coroutine.yield()
end

--对不同的邮件数量状态下进行方法检测
local function test_mailGroup(actor, check_func, ...)
	local lite, full = getLiteAndFull()
	local initAtts = {
		{0, 0}, --空仓
		{lite, full}, --满仓
		{lite - math.random(10, 30), full - math.random(10, 30)}, --非满仓
		{lite, 0}, --非满仓(全lite)
		{0, full}, --非满仓(全full)
		{MAIL_BOX_MAX, 0}, --满仓(全lite)
		{0, MAIL_BOX_MAX}, --满仓(全full)
	}

	for _,params in pairs(initAtts) do
		for mod = 1, 4 do
			initMailBox(actor, params[1], params[2])            --设置邮箱状态
			initBagresCount(actor, params[1], params[2], mod)     --设置背包状态
			check_func(actor, params[1], params[2], mod, unpack(arg))--调用测试方法
		end
	end
end

--***********************************************
-------------------基本&测试 END-----------------
--***********************************************
--***********************************************
--README---------------基本测试------------------
--***********************************************

--**测试清空邮件和获取数量是否正常**--
local function test_baseFuncCheck(actor)
	clearAllMail(actor)
	Assert(getMailCount(actor) == 0,"clearAllMail or getMailCount func haven err.")
	local lite = math.random(50, 80)
	local full = math.random(50, 80)
	initMailBox(actor, lite, full)
	Assert((lite + full) == getMailCount(actor), "initMailBox or getMailCount func haven err.")
	clearAllMail(actor)
end

--***********************************************
-------------------最大约束测试------------------
--***********************************************

--**使用GM邮件塞满邮箱**
--overflow 是否插入超过最大上限的邮件
local function setMailBoxFull(actor, overflow)
	local count    = getMailCount(actor)
	local maxCount = mailsys.MAIL_BOX_MAX
	local addCount = maxCount - count
	if overflow then addCount = math.random(maxCount * 2, maxCount * 4) end
	local isLite
	for i=1, addCount do
		--随机产生一个带或者不带附件的邮件
		isLite = checkFunc.getRandomOne(boolAtts)
		sendGMMailToActor(actor, isLite)
		if i % 10 == 0 then
			coroutine.yield()
		end
	end
	coroutine.yield()
end

local function test_min_mailBoxMaxConstraint(actor, overflow)
	clearAllMail(actor)
	local maxCount = mailsys.MAIL_BOX_MAX
	setMailBoxFull(actor, overflow)
	local endMailCount = getMailCount(actor)
	Assert(endMailCount == maxCount, string.format("MAIL_BOX_MAX Constraint maybe haven some error.count = %s",endMailCount))
end

--**测试最大约束**
local function test_mailBoxMaxConstraint(actor)
	local maxCount = mailsys.MAIL_BOX_MAX
	Assert(maxCount >= 100 and maxCount < 255,"MAIL_BOX_MAX must > 100 and < 255.")
	test_min_mailBoxMaxConstraint(actor, false)
	test_min_mailBoxMaxConstraint(actor, true)
	clearAllMail(actor)
end

--***********************************************
--README------------发送邮件测试-----------------
--***********************************************
--**检测在线人数，至少要2个人**
--返回一个非自己的actor用于测试否则返回nil
local function getOhterActor(actor)
	local actorId = LActor.getActorId(actor)
	local actors  = LuaHelp.getAllActorList()

	for _,act in pairs(actors) do
		local t_actorId = LActor.getActorId(act)
		if t_actorId ~= actorId then
			return act
		end
	end
end

--**发送邮件给玩家(toActor)**
local function test_sendMailToActor(actor, toActor, context)
	local name = LActor.getName(toActor)
	local pack = LDataPack.test_allocPack()
	LDataPack.writeData(pack, 2,
		dtString, name,
		dtString, context)
	LDataPack.setPosition(pack, 0)
	clearAllMail(toActor)
	local mailCount = getMailCount(toActor)
	mailsys.clientSendMail(actor, pack)
	coroutine.yield()
	local n_mailCount = getMailCount(toActor)
	-- print("mailCount:"..mailCount)
	-- print("n_mailCount:"..n_mailCount)
	return mailCount, n_mailCount
end

--**禁发邮件配置测试**
local function test_mailForBidTimeCheck(actor)
	mailsys.setForbidTime(actor, math.random(1800, 3600))
	Assert(mailsys.isForbid(actor), "set mail For BidTime failed!")

	mailsys.setForbidTime(actor, 0)
	Assert(not mailsys.isForbid(actor), "set Unlock Mail bidTime failed!")
	local binTime = mailsys.getForbidTime(actor)
	mailsys.setForbidTime(actor, math.random(1800, 3600))
	local n_binTime = mailsys.getForbidTime(actor)
	Assert(binTime~= n_binTime, "mail binTime is a err number.")
	--取消禁发
	mailsys.setForbidTime(actor, 0)
end

--**检测在不可发信的情况下是否还能发邮件**
--todo search one actor
local function test_sendMailWhenGag(actor, toActor)
	mailsys.setForbidTime(actor, 3600)
	local mailCount, n_mailCount = test_sendMailToActor(actor, toActor, "TEST_Gag")
	Assert_eq(0, n_mailCount - mailCount, "[ERR]:Actor still can send mail in bidTime.")
	mailsys.setForbidTime(actor, 0)
end

--**检测能否发邮件给自己**
local function test_sendMailToSelf(actor)
	local mailCount, n_mailCount = test_sendMailToActor(actor, actor, "TEST_MYSELF")
	Assert_eq(0, n_mailCount - mailCount, "[ERR]:Actor can send mail to itself.")
end

--**检测空内容是否可以发送**
local function test_sendMailContextNull(actor, toActor)
	local mailCount, n_mailCount = test_sendMailToActor(actor, toActor, "")
	Assert_eq(0, n_mailCount - mailCount, "[ERR]:Actor still can send mail then context null.")
end

--**发送邮件给玩家时的检测和金钱操作的检测**
local function test_sendMailRetAndChangeMoney(actor, toActor)
	local mailCount, n_mailCount  --前一邮件数量，当前邮件数量
	local oldMoney = LActor.getMoneyCount(actor, mtBindCoin)
	--当前值减掉submoney后会无法发送邮件
	local subMoney = oldMoney - math.random(0, SEND_MAIL_COST)
	if subMoney < 0 then subMoney = 0 end

	local sameMoney = function ()
		return oldMoney == n_money
	end

	local oneMailCount = function ()
		return 1 == n_mailCount - mailCount
	end

	local moneyAtts = {
		{	beg     = -subMoney,  --修正金钱
			after   = subMoney ,  --重置金钱
			m_check = true,       --金币是否没有变化
			m_num   = 0,          -- 成功发送邮件数量
			m_err   = "still",
			status  = "money not enough."}, --测试金钱不足时发送情况

		{   beg     = 5 * SEND_MAIL_COST,
			after   = - (4 * SEND_MAIL_COST),
			m_check = false,
			m_num   = 1,
			m_err   = "can't",
			status  = "money enough."}, --测试金钱充足时发送情况
	}

	for _,conf in pairs(moneyAtts) do
		--修改金钱满足测试条件
		LActor.changeMoney( actor, mtBindCoin, conf.beg, 1, true, "mailsystem","test", "","")
		local nb_money = LActor.getMoneyCount(actor, mtBindCoin) --当前金钱
		--*********
		--发信
		--*********
		mailCount, n_mailCount = test_sendMailToActor(actor, toActor, "TEST_MAIL")
		local n_money = LActor.getMoneyCount(actor, mtBindCoin) --当前金钱
		--金币扣除检测
		Assert((n_money == nb_money) == conf.m_check, string.format("MONEY_ERR:Actor %s send mail when %s", conf.m_err, conf.status))
		--邮件发送状态检测
		Assert(n_mailCount == mailCount + conf.m_num, string.format("MAIL_ERR:Actor %s send mail when %s", conf.m_err, conf.status))
		--***********
		--不正常发信
		--***********
		mailCount, n_mailCount = test_sendMailToActor(actor, toActor, "")
		local err_money = LActor.getMoneyCount(actor, mtBindCoin) --当前金钱
		Assert(n_money == err_money, string.format("ERR_MAIL_MONEY:Actor %s send mail when %s", conf.m_err, conf.status))
		Assert(n_mailCount == mailCount, string.format("ERR_MAIL_COUNT:Actor %s send mail when %s", conf.m_err, conf.status))
		--完成后将金钱修正
		LActor.changeMoney( actor, mtBindCoin, conf.after, 1, true, "mailsystem","test", "","")
	end
	--充足时是否可以发送
	--发送失败是否会扣除
end

local function test_sendMail(actor)
	test_mailForBidTimeCheck(actor) --禁发邮件测试
	test_sendMailToSelf(actor) --邮件发送给自己测试
	local toActor = getOhterActor(actor)
	--当不存在其它玩家时，将无法进行该测试
	if not toActor then
		Assert(toActor, "Can't find other actor!")
		return
	end
	test_sendMailWhenGag(actor, toActor) --禁发信检测
	test_sendMailContextNull(actor, toActor) --空内容发信检测
	test_sendMailRetAndChangeMoney(actor, toActor) --发送邮件是否成功和金币扣除检测
end

--***********************************************
--README------------私人邮件测试-----------------
--***********************************************
local function test_sendMailContext(actor)
	local ohterActor = getOhterActor(actor)
	Assert(ohterActor ~= nil, "can't search other actor.")
	if ohterActor == nil then return end
	local testStr = "TEST MAIL"
	clearAllMail(actor)
	clearAllMail(ohterActor)
	coroutine.yield()
	test_sendMailToActor(actor, ohterActor, testStr)
	coroutine.yield()
	local maillist = mailsys.getMailList(ohterActor)
	for _,v in pairs(maillist) do
		Assert_eq(v.context, testStr, "mail context is diff.(actor->ohterActor)")
	end
end

--***********************************************
--README------------删除邮件测试-----------------
--***********************************************
--**删除带不带附件的邮件并检查删除的情况**
local function test_delMail_noAtt(actor)
	local pack = LDataPack.test_allocPack()
	--删除不带附件的邮件
	LDataPack.writeData(pack, 1,
		dtByte, 0)
	LDataPack.setPosition(pack, 0)
	mailsys.clientDeleteMail(actor, pack)
	coroutine.yield()
	local mailList = mailsys.initMailList(actor)
	local noAttCount = 0
	local flag
	for _, mail in pairs(mailList) do
		if #mail.attachmentList > 0 then
			flag = true
			break
		end
	end
	Assert(not flag, "Still have mail with an attachment")
end

--根据列表删除并检查删除的情况
local function test_delMail_list(actor, delMailIds)
	local count = #delMailIds
	local pack = LDataPack.test_allocPack()
	LDataPack.writeChar(pack, count)
	for _,mailId in pairs(delMailIds) do
		LDataPack.writeInt64(pack, mailId)
	end
	LDataPack.setPosition(pack, 0)
	mailsys.clientDeleteMail(actor, pack)
	coroutine.yield()
	local mailList = mailsys.initMailList(actor)
	local flag
	for _, mail in pairs(mailList) do
		for _, mailId in pairs(delMailIds) do
			if mail.mailId == mailId then
				flag = true
				break
			end
		end
		if flag then break end
	end
	Assert(not flag,"Still have err mail after delMailIds.")
end

--func->检测用的方法
--lite->不带附件邮件数量
--full->带附件邮件数量
-->isList->是否是删除某组mailId的方式,false为删除带附件的邮件
local function test_delMail_base(actor, lite, full, mod, func, isList)
	local ret
	if isList then
		local delMailIds = {}
		local mailList = mailsys.initMailList(actor)
		--随机抽点邮件ID出来删除=。=
		for _, mail in pairs(mailList) do
			if checkFunc.getRandomOne(boolAtts) then
				table.insert(delMailIds, mail.mailId)
			end
		end
		ret = func(actor, delMailIds)
	else
		ret = func(actor)
	end
end

local function test_delMail(actor)
	test_mailGroup(actor, test_delMail_base, test_delMail_noAtt, false)
	test_mailGroup(actor, test_delMail_base, test_delMail_list, true)
end

--***********************************************
--README------------阅读邮件测试-----------------
--***********************************************
local function test_readMailCheck(actor, mailList, readMailIds)
	local pack = LDataPack.test_allocPack()
	LDataPack.writeInt(pack, #readMailIds)
	for _,mailId in pairs(readMailIds) do
		LDataPack.writeInt64(mailId)
	end
	LDataPack.setPosition(pack, 0)
	local mailCount = #mailList
	mailsys.clientReadMail(actor, pack)
	local unReadCount = mailsys.getUnReadCount(actor)
	return (mailCount - unReadCount == #readMailIds)
end

local function test_readMail_base(actor, lite, full)
	local readIds = {}
	local mailList = mailsys.initMailList(actor)
	--随机抽取要读取的邮件
	for _, mail in pairs(mailList) do
		if checkFunc.getRandomOne(boolAtts) then
			table.insert(readIds, mail.mailId)
		end
	end
	local ret = test_readMailCheck(actor, mailList, readIds)
	Assert(ret, string.format("clientReadMail have sth err when lite = %s and full = %s", lite, full))
end

local function test_readMail(actor)
	test_mailGroup(actor, test_readMail_base)
end

--***********************************************
--README----------领取邮件附件测试---------------
--***********************************************
--获取邮件附件领取所需的格子数量
local function getAttCounts(actor, mailList)
	local count = 0
	for _, mail in pairs(mailList) do
		count = count + mailsys.getMailItemCount(actor, mail)
	end
	return count
end

--根据ID获取邮件列表
local function getmailListByIds(actor, Ids)
	local t_mailList = {}
	local mail
	for _,mailId in pairs(Ids) do
		mail = mailsys.getMail(actor, mailId)
		if mail then table.insert(t_mailList, mail) end
	end
	return t_mailList
end

--检查是否还有带附件的邮件
local function getAttFlag(actor)
	local mailList = mailsys.initMailList(actor)
	local flag
	for _, mail in pairs(mailList) do
		if #mail.attachmentList > 0 then
			flag = true
		break end
	end
	return flag
end

--**领取附件的邮件并检查领取的情况**
local function test_getMailAtt_att(actor, lite, full ,mod)
	local resCount = LActor.getStoreRestCount(actor)
	local mailList = mailsys.initMailList(actor)
	local attCount = getAttCounts(actor, mailList)
	local pack = LDataPack.test_allocPack()
	--获取邮件的附件
	LDataPack.writeData(pack, 1,
		dtByte, 0)
	LDataPack.setPosition(pack, 0)
	mailsys.clientGetAttachment(actor, pack)
	coroutine.yield()
	local flag = getAttFlag(actor)
	--空格足够
	if resCount >= attCount and full > 0 then
		Assert(not flag, "【GetAttErr】Still some mail attachments are not received.resCount > attCount and full > 0 ")
	elseif resCount < attCount and full > 0 then
		Assert(flag,"【GetAttErr】Still some mail attachments are not received.resCount < attCount and full > 0")
	end
end

--根据列表领取并检查获取的情况
local function test_delMail_list(actor, getMailAttIds, lite, full, mod)
	local resCount = LActor.getStoreRestCount(actor)
	local mailList = getmailListByIds(actor, getMailAttIds)
	local attCount = getAttCounts(actor, mailList)
	local pack = LDataPack.test_allocPack()
	LDataPack.writeData(pack, 1,
		dtByte, #getMailAttIds)
	for _,mailId in pairs(getMailAttIds) do
		LDataPack.writeInt64(pack, mailId)
	end
	LDataPack.setPosition(pack, 0)
	mailsys.clientGetAttachment(actor, pack)
	coroutine.yield()
	local flag = getAttFlag(actor)
	--空格足够
	if resCount >= attCount and full > 0 then
		Assert(not flag, "【GetAttErr】Still have err mail after delMailIds.resCount > attCount and full > 0 ")
	elseif resCount < attCount and full > 0 then
		Assert(flag,"【GetAttErr】Still have err mail after delMailIds.resCount < attCount and full > 0")
	end
end

--func->检测用的方法
--lite->不带附件邮件数量
--full->带附件邮件数量
--mod ->当前的背包
-->isList->是否是使用某组mailId的方式,false为所有附件有获取
local function test_getMailAtt_base(actor, lite, full, mod, func, isList)
	local ret
	if isList then
		local delMailIds = {}
		local mailList = mailsys.initMailList(actor)
		--随机抽点邮件ID出来获取附件=。=
		for _, mail in pairs(mailList) do
			if checkFunc.getRandomOne(boolAtts) then
				table.insert(delMailIds, mail.mailId)
			end
		end
		ret = func(actor, delMailIds, lite, full, mod)
	else
		ret = func(actor, lite, full, mod)
	end
	coroutine.yield()
	-- Assert_eq(liteMailCount, ret, string.format("Delete mail haven sth err. when lite:%s and full:%s", lite, full))
end

local function test_getMailAtt(actor)
	test_mailGroup(actor, test_getMailAtt_base, test_getMailAtt_att, false)
	test_mailGroup(actor, test_getMailAtt_base, test_delMail_list, true)
end

--***********************************************
--README----------领取邮件金钱测试---------------
--***********************************************

function test_getMailAttMoney(actor)
	clearAllMail(actor)
	sendGmMailByActor(actor, "TEST", 2, mtBindCoin, 10000)
	coroutine.yield()

	local def_money = actormoney.getMoney(actor, mtBindCoin)
	local mail_list = mailsys.getMailList(actor)

	local mailId
	for k,mail in pairs(mail_list) do
		mailId = k
		if k ~= 0 then break end
	end

	local pack = LDataPack.test_allocPack()
	LDataPack.writeData(pack, 2,
		dtByte, 1,
		dtInt64, mailId)
	LDataPack.setPosition(pack, 0)

	mailsys.clientGetAttachment(actor, pack)
	coroutine.yield()

	local aft_money = actormoney.getMoney(actor, mtBindCoin)
	Assert(aft_money - def_money == 10000, "get money haven some err from mail.")
end



TEST("mailsys", "maxMail", test_mailBoxMaxConstraint, true)
TEST("mailsys", "sendMail", test_sendMail, true)
TEST("mailsys", "deleteMail", test_delMail, true)
TEST("mailsys", "readMail", test_readMail, true)
TEST("mailsys", "getMail", test_getMailAtt, true)
TEST("mailsys", "mailcontext", test_sendMailContext, true)
TEST("mailsys", "getmoney", test_getMailAttMoney, true)


