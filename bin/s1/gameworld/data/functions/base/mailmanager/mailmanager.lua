--邮件管理器
module("base.mailmanager.mailmanager", package.seeall)
setfenv(1, base.mailmanager.mailmanager)

local dbretdispatcher = require("utils.net.dbretdispatcher")
local lianfuutils     = require("systems.lianfu.lianfuutils")
local lianfumanager   = require("systems.lianfu.lianfumanager")
local centerservermsg = require("utils.net.centerservermsg")
-- local crossutils      = require("utils.cross.crossutils")

require("protocol")

local dbCmd = DbCmd.MailMgrCmd
local addByActorId = 1
local addByActorName = 2
local addByAcountName = 3

local sysId = SystemId.enMailSystemID
local protocol = MailSystemProtocol
local centerProtocol = protocol.centerProtocol
local LianfuGbCmd = LianfuGbCmd

--=======================================
--README        ** DATA **
--=======================================
--数据内的qualtiy字段将保存多个数据
--这里将用于合并数据和拆解数据
local MIX_BASE = 0xFF
local OFFSET_QUALITY, OFFSET_STRONG = 0, 8

function mixData(quality, strong)
	quality = quality or 0
	strong  = strong or 0

	quality = System.bitOpAnd(quality, MIX_BASE)
	strong  = System.bitOpAnd(strong, MIX_BASE)

	--位移
	strong = System.bitOpLeft(strong, OFFSET_STRONG)

	return quality + strong
end

function unpackData(val)
	val = val or 0

	local quality = System.bitOpAnd(val, MIX_BASE)
	local strongVal = System.bitOpRig(val, OFFSET_STRONG)
	local strong = System.bitOpAnd(strongVal, MIX_BASE)

	return quality, strong
end

local function makeMailSendTable(mail)
	local sendTable = {
		dtInt64, mail.mailId,
		dtInt, mail.actorId or 0,
		dtByte, mail.mailType,
		dtByte, mail.status,
		dtInt, mail.senderId,
		dtUint, mail.sendTick,
		dtString, mail.sendName,
		dtString, mail.context,
		dtInt, #mail.attachmentList
	}

	--插入附件
	for _, attachment in ipairs(mail.attachmentList) do
		table.insert(sendTable, dtByte)
		table.insert(sendTable, attachment.type)
		table.insert(sendTable, dtInt)
		table.insert(sendTable, attachment.param)
		table.insert(sendTable, dtInt)
		table.insert(sendTable, attachment.count)
		table.insert(sendTable, dtByte)
		table.insert(sendTable, attachment.bind)
		table.insert(sendTable, dtInt)
		table.insert(sendTable, attachment.quality)
	end

	return sendTable
end

function AddMailByActorId(mail, srvId)
	if not mail or not mail.actorId or mail.actorId == 0 then
		print("[Error] Add Mail By actorId error !!!!")
		return false
	end

	local mailTable = makeMailSendTable(mail)
	if not mailTable then return end

	System.SendToDb(srvId or 0, dbMail, dbCmd.dcAddMail, (#mailTable / 2), unpack(mailTable))
	return true
end

function AddMailByActorName(actorName, mail, srvId)
	if not actorName then
		print("[Error] Add Mail By ActorName error !!!!")
		return false
	end

	local mailTable = makeMailSendTable(mail)
	if not mailTable then return end

	System.SendToDb(srvId or 0, dbMail, dbCmd.dcAddMailByActorName, 2 + (#mailTable / 2), dtInt, System.getServerId(), dtString, actorName, unpack(mailTable))
	return true
end

function AddMailByAccountName(accountName, mail, srvId)
	if not accountName then
		print("[Error] Add Mail By accountName error !!!!")
		return false
	end

	local mailTable = makeMailSendTable(mail)
	if not mailTable then return end

	System.SendToDb(srvId or 0, dbMail, dbCmd.dcAddMailByAccountName, 2 + (#mailTable / 2), dtInt, System.getServerId(), dtString, accountName, unpack(mailTable))
	return true
end

function baseOnAddMailByActorIdDbReturn(reader)
	local actorId = LDataPack.readInt(reader)
	local senderId = LDataPack.readInt(reader)

	local err = LDataPack.readByte(reader)
	if err ~= 0 then return true end

	local actor = LActor.getActorById(actorId)
	local mailId = LDataPack.readInt64(reader)

	local accountName = ""
	local level = 0
	if actor then
		accountName = LActor.getAccountName(actor)
		level = LActor.getLevel(actor)
	end
	System.logCounter(actorId, tostring(accountName), tostring(level),
				"mail", "", "", "addmail", tostring(mailId), "", "", "add")

	if actor then
		ReloadMailFromDb(actor, mailId)
		return true
	end

	return false, actorId
end

function recieveOnAddMailByActorIdDbReturn(reader)
	baseOnAddMailByActorIdDbReturn(reader)
end

function OnAddMailByActorIdDbReturn(reader)
	-- local ret, actorId = baseOnAddMailByActorIdDbReturn(reader)

	-- if ret then return end

	-- if not lianfuutils.isOpenLianfu() then return end

	-- local onlineId = LianfuFun.getOnlineServerId(actorId)

	-- --转发到连服
	-- if onlineId > 0 then
	-- 	--转发数据到连服服务器上
	-- 	local pack = LDataPack.allocLianFuPacket(LianfuGbCmd.sRecieveByMailData)
	-- 	if not pack then return end
	-- 	LDataPack.writePacket(pack, reader)
	-- 	LianfuFun.sendServerPacket(onlineId, pack)

	-- --转发数据到跨服服务器上
	-- else
	-- 	local toServerId = crossutils.getMainBattleServerId()
	-- 	if toServerId <= 0 then return end

	-- 	local pack = LDataPack.allocCenterPacket(toServerId, sysId, centerProtocol.sReAddNewMail)
	-- 	if not pack then return end

	-- 	LDataPack.writePacket(pack, reader)
	-- 	System.sendDataToCenter(pack)
	-- end
end

local function makeGmMailUtil(context, attList, sendName, actorLevel, actorJob)
	local mail = {}
	mail.mailId = System.allocSeries()
	mail.mailType = 1
	mail.status = 0
	mail.senderId = 0
	mail.sendName = sendName or "GM"
	mail.sendTick = System.getNowTime()
	mail.context = context
	mail.attachmentList = {}

	if not attList then return mail end

	local realLevel
	if actorLevel then
		realLevel = System.makeLoInt16(actorLevel)
	end

	local count = math.min(3, #attList)
	for i=1,count do
		local info = attList[i]
		local lNum, pNum

		if realLevel and info.numByLevel and info.numByLevel[realLevel] then
			lNum = info.numByLevel[realLevel]
		end

		if actorJob and info.paramByJob and info.paramByJob[actorJob] then
			pNum = info.paramByJob[actorJob]
		end

		local mixQuaVal = mixData(info.quality, info.strong)
		local attachment =
 		{
			type    = info.type or 0,
			param   = pNum or info.param or 0,
			count   = lNum or info.count or info.num or 0,
			bind    = info.bind or 0,
			quality = mixQuaVal or 0
		 }
		 table.insert(mail.attachmentList, attachment)
	end

	return mail
end

local function makeGmMail(context, type, param, count, bind, quality, strong)
	local attachmentList = {}
	local attachment = {
		type    = type or 0,
		param   = param or 0,
		count   = count or 0,
		bind    = bind or 0,
		quality = quality or 0,
		strong  = strong or 0,
	}

	table.insert(attachmentList, attachment)
	return makeGmMailUtil(context, attachmentList)
end

local function logForMailByActor(actor, mail, logStr)
	if not logStr then return end

	if not mail.attachmentList or #mail.attachmentList <= 0 then return end

	local mailtt = mail.attachmentList[1]

	--这里需要拆解
	local quality, strong = unpackData(mailtt.quality)

	--增加打点
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)), "gm_mail", tostring(mail.mailId or 0), "userid:"..LActor.getActorId(actor), tostring(mailtt.type or ""), tostring(mailtt.param or ""), tostring(mailtt.count or ""), tostring(mailtt.bind or "").."_"..tostring(quality or "").."_"..tostring(strong or ""), logStr, lfBI)
end

local function logForMailByActorId(mail, actorLevel, logStr)
	if not logStr then return end

	if not mail.attachmentList or #mail.attachmentList <= 0 then return end

	local actorId = mail.actorId
	local actor = LActor.getActorById(actorId)
	local accountName = ""
	if actor then
		accountName = LActor.getAccountName(actor)
	end

	for k, matt in pairs(mail.attachmentList) do
		for _, matt in pairs(mail.attachmentList) do
			System.logCounter(actorId, accountName, tostring(actorLevel or 0), "gm_mail", tostring(mail.mailId or 0), "userid:"..actorId, tostring(matt.type or ""), tostring(matt.param or ""), tostring(matt.count or ""), tostring(matt.bind or "").."_"..tostring(matt.quality or ""), logStr, lfBI)
		end
	end
end

_G.sendGmMailByActor = function(actor, context, mType, param, count, bind, quality, logStr, strong)
	local mail = makeGmMail(context, mType, param, count, bind, quality, strong)
	mail.actorId = LActor.getActorId(actor)

	logForMailByActor(actor, mail, logStr)

	return AddMailByActorId(mail, LActor.getServerId(actor))
end

_G.sendGmMailByActorId = function(actorId, context, type, param, count, bind, quality, serverId, logStr, strong)
	local mail = makeGmMail(context, type, param, count, bind, quality, strong)
	mail.actorId = actorId

	logForMailByActorId(mail, 0, logStr)

	return AddMailByActorId(mail, serverId)
end

_G.sendGmMailByActorIdEx = function(actorId, context, attachmentList, sendName, serverId, actorLevel, actorJob, logStr)
	local mail = makeGmMailUtil(context, attachmentList, sendName, actorLevel, actorJob)
	mail.actorId = actorId

	--增加打点
	logForMailByActorId(mail, actorLevel, logStr)

	return AddMailByActorId(mail, serverId)
end

_G.sendGmMailByActorName = function(actorName, context, type, param, count, bind, quality, serverId, strong)
	local mail = makeGmMail(context, type, param, count, bind, quality, strong)
	return AddMailByActorName(actorName, mail, serverId)
end

_G.sendGmMailByAccount = function(accountName, context, type, param, count, bind, quality, serverId, strong)
	local mail = makeGmMail(context, type, param, count, bind, quality, strong)
	return AddMailByAccountName(accountName, mail, serverId)
end

dbretdispatcher.reg(dbMail, dbCmd.dcAddMail, OnAddMailByActorIdDbReturn)
dbretdispatcher.reg(dbMail, dbCmd.dcAddMailByActorName, OnAddMailByActorIdDbReturn)
dbretdispatcher.reg(dbMail, dbCmd.dcAddMailByAccountName, OnAddMailByActorIdDbReturn)
lianfumanager.regCmd(LianfuGbCmd.sRecieveByMailData, recieveOnAddMailByActorIdDbReturn)
centerservermsg.reg(sysId, centerProtocol.sReAddNewMail, recieveOnAddMailByActorIdDbReturn)

