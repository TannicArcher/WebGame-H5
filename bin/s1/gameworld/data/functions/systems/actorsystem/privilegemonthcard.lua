module("privilegemonthcard", package.seeall)

local hourSec = 60 * 60
local daySec = 24 * hourSec

-- 特权信息
--[[保存在玩家上的信息
	endTime 特权的过期时间
	isRec 是否领取过每日奖励
	isSendExpired 是否发送了过期消息
--]]
local function getData(actor) 
	local var = LActor.getStaticVar(actor)
	if nil == var.PrivilegeData then
		var.PrivilegeData = {}
	end
	return var.PrivilegeData
end

--是否已开通特权
function isOpenPrivilegeCard(actor) 
	local var = getData(actor)
	return var and var.endTime and System.getNowTime() < var.endTime
end

--向客户端发送最新的特权数据
local function sendPrivilegeData(actor)
	local var = getData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Recharge, Protocol.sRechargeCmd_PrivilegeMonthCardData)
	--获取剩余时间
	local leftTime = 0
	if var.endTime then 
		leftTime = var.endTime - System.getNowTime() 
	end
	if 0 > leftTime then leftTime = 0 end

	LDataPack.writeUInt(npack, leftTime)
	LDataPack.writeByte(npack, 1 - (var.isRec or 0))
	LDataPack.writeByte(npack, (not var.endTime) and 1 or 0)
	LDataPack.flush(npack)
end

-- 发送开通邮件
local function sendMailOpenPrivi( actor )
	local mail_data = {}
	mail_data.head       = PrivilegeData.priviOpenMailHead
	mail_data.context    = PrivilegeData.priviOpenMailContext
	mail_data.tAwardList = {}
	mailsystem.sendMailById(LActor.getActorId(actor),  mail_data)
end

-- 发送到期邮件
local function sendEndMail(actor)
	local mail_data = {}
	mail_data.head       = PrivilegeData.priviEndMailHead
	mail_data.context    = PrivilegeData.priviEndMailContext
	mail_data.tAwardList = {}
	mailsystem.sendMailById(LActor.getActorId(actor),  mail_data)
end

-- 更新背包容量
local function updateBagCapacity( actor )
	-- 未购买或已过期为0
	local flag = isOpenPrivilegeCard(actor) and 1 or 0
	-- 更新数值
	local basicData = LActor.getActorData(actor)
	basicData.privilege_monthcard = flag
	LActor.updataEquipBagCapacity(actor)
end

-- 添加称号
local function addPriviTitle( actor, tid, endTime)
	titlesystem.addTitle(actor, PrivilegeData.priviBoss)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Title, Protocol.sTitleCmd_Add)
	LDataPack.writeInt(npack, tid)
	LDataPack.writeInt(npack, endTime)
	LDataPack.flush(npack)
end

-- 失去称号
local function delPriveTitle( actor, tid )
	titlesystem.delitle(actor, tid)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Title, Protocol.sTitleCmd_Del)
	LDataPack.writeInt(npack, tid)
	LDataPack.flush(npack)
end

--购买特权月卡
local function buyPrivilegeMonthCard(actor)
	local var = getData(actor)
	local isOpen = isOpenPrivilegeCard(actor)
	if not var.endTime then
		print('actorid:' .. LActor.getActorId(actor) .. ' privilegemonthcard.buyPrivilegeMonthCard first rewards')
		-- 首次开通邮件奖励
		local mail_data = {}
		mail_data.head       = PrivilegeData.firstMailHead
		mail_data.context    = PrivilegeData.firstMailContex
		mail_data.tAwardList = PrivilegeData.priviOpenReward
		mailsystem.sendMailById(LActor.getActorId(actor),  mail_data)
	end
	if not isOpen then
		var.endTime = System.getNowTime() + PrivilegeData.priviCardDays * daySec
	else
		var.endTime = var.endTime + PrivilegeData.priviCardDays * daySec
	end
	-- 添加称号
	addPriviTitle(actor, PrivilegeData.priviBoss, var.endTime)
	-- 发送邮件
	sendMailOpenPrivi(actor)
	-- 重置过期标志
	var.isSendExpired = nil
	-- 向客户端发送消息
	sendPrivilegeData(actor)
	-- 更新背包
	updateBagCapacity(actor)

	--临时推下特戒信息
	actorexringfuben.sendFubenInfo(actor)
end


--在玩家登录的时候
local function onLogin(actor)
	sendPrivilegeData(actor)
end

--客户端发请求过来要求领取特权奖励了
local function onGetReward(actor, packet)
	if not isOpenPrivilegeCard(actor) then
		print(LActor.getActorId(actor).." privilegemonthcard.onGetReward is not Open Privilege")
		return
	end
	local var = getData(actor)
	if var.isRec then 
		print(LActor.getActorId(actor).." privilegemonthcard.onGetReward is Rec")
		return
	end
	LActor.giveAwards(actor, PrivilegeData.priviDailyAward, "privilege")
	var.isRec = 1
	sendPrivilegeData(actor)
end

--第二天到来的时候
local function onNewDayArrive(actor, login)
	local var = getData(actor)
	var.isRec = nil
	if not login then
		sendPrivilegeData(actor)
	end
end

-- 购买特权
function buyPrivilegeMonth(actorid) 
	local actor = LActor.getActorById(actorid)
	if actor then
		buyPrivilegeMonthCard(actor)
	else
		System.buyPrivilegeCard(actorid)
	end
end

-- 发送过期消息
local function sendExpired( actor )
	--最新消息发给客户端	
	sendPrivilegeData(actor)
	sendEndMail(actor)
	updateBagCapacity(actor)
	-- 删除称号
	delPriveTitle(actor, PrivilegeData.priviBoss)
end

-- 检测是否有效，过期更新数据
local function onCheckValid(actor)
	local var = getData(actor)
	--没开通跳出
	if 0 == (var.endTime or 0) then return end
	-- 过期
	if not isOpenPrivilegeCard(actor) then 
		var.endTime = 0
		-- 已发送过过期消息
		if var.isSendExpired then
			return
		end
		-- 发送过期消息
		sendExpired(actor)
		var.isSendExpired = 1
	end
end


--烈焰副本增加次数
function getExringFubenCount(actor)
	if isOpenPrivilegeCard(actor) then return PrivilegeData.exringFubenCount or 0 end

	return 0
end

--采矿增加次数
function getKuangAddCount(actor)
	if isOpenPrivilegeCard(actor) then return PrivilegeData.addKuangCount or 0 end

	return 0
end

--采矿减少时间
function getKuangReduceTime(actor)
	if isOpenPrivilegeCard(actor) then return PrivilegeData.reduceKuangTime or 0 end

	return 0
end

-- 初始化
local function onInit(actor)
	updateBagCapacity(actor)
end

_G.onCheckPrivilegeMonthCardValid = onCheckValid  -- C调用检测
_G.buyPrivilegeMonthCard = buyPrivilegeMonthCard -- gm

actorevent.reg(aeNewDayArrive, onNewDayArrive)
actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_Recharge, Protocol.cRechargeCmd_GetPrivilegeAward, onGetReward)

