--[[
	author = 'Roson'
	time   = 11.04.2014
	name   = 拾取系统
	mod    = 拾取
	ver    = 0.1
]]

module("systems.superexptime.loot" , package.seeall)
setfenv(1, systems.superexptime.loot)

local sbase      = require("systems.superexptime.sbase")
local pTimer     = require("base.scripttimer.postscripttimer")
local mainevent  = require("systems.superexptime.mainevent")
local fubenevent = require("actorevent.fubenevent")
local mailsystem = require("systems.mail.mailsystem")
local lootevent  = require("systems.lootsys.lootevent")

local table = table
local LActor = LActor

local netmsgdispatcher = sbase.netmsgdispatcher
local actorevent       = sbase.actorevent

local sysId    = sbase.sysId
local protocol = sbase.protocol

local SuperExpTimeConf = sbase.SuperExpTimeConf
local sceneExpConf     = SuperExpTimeConf.sceneExpConf
local monsterIds       = SuperExpTimeConf.monsterIds

local Langs    = Lang.SuperExpTime
local FUBEN_ID = SuperExpTimeConf.fubenId

local TYPE_ITEM  = mailsystem.TYPE_ITEM
local TYPE_MONEY = mailsystem.TYPE_MONEY

local UPDATE_ALL, UPDATE_ITEM = 0, 1
local MAIL_ATT_MAX_COUNT = 3

local sendGmMailByActorIdEx = _G.sendGmMailByActorIdEx

--动态数据 # 下线删除
function getDyanmicVar(actor)
	local var = sbase.getDyanmicVar(actor)
	if not var then return end

	var.loot = var.loot or {}
	return var.loot
end

function sendItemsInfo(actor, addInfo)
	local var = addInfo or getDyanmicVar(actor)
	if not var then return end

	local packType = addInfo and UPDATE_ITEM or UPDATE_ALL
	local count = table.getnEx(var)

	local pack = LDataPack.allocPacket(actor, sysId, protocol.sSendDepotRefresh)
	if not pack then return end

	local writeData = LDataPack.writeData
	writeData(pack, 2,
		dtChar, packType,
		dtChar, count)

	for _,v in pairs(var) do
		writeData(pack, 3,
			dtChar, v.type,
			dtInt, v.param,
			dtInt, v.num)
	end

	LDataPack.flush(pack)
end

--增加到临时仓库
function addAwardToDepot(actor, sceneId, typeId, itemId, count)
	local var = getDyanmicVar(actor)
	if not var then return end

	local item = var[itemId]

	if item then
		item.num = item.num + count
	else
		var[itemId] =	--邮件数据格式
			{
				type    = typeId,
				param   = itemId,
				num     = count,
				bind    = 1,
				quality = 0,
			}

		item = var[itemId]
	end

	sendItemsInfo(actor, {item})
end

--发送一封邮件
function sendOneMail(actor, attachmentList)
	local actorId = LActor.getActorId(actor)

	local attStr = mailsystem.getMailAttachmentString(attachmentList)
	local context = string.format(Langs.mail001, attStr)

	sendGmMailByActorIdEx(actorId, context, attachmentList, nil, LActor.getServerId(actor), nil, nil, "superexpitem_award")
end

--使用邮件去发送奖励
function sendAwardByMail(actor)
	local var = getDyanmicVar(actor)
	if not var then return end

	local deepcopy = table.deepcopy
	local insert = table.insert

	--邮件附件拆包
	local attList = {}
	for _,item in pairs(var) do
		if item.type == TYPE_MONEY then
			insert(attList, item)
		else
			local srcData = deepcopy(item) --clone一份表
			local param   = item.param
			local dupCnt  = Item.getItemPropertyById(param, Item.ipItemDupCount) --查询堆叠数量
			local count   = math.ceil(item.num / dupCnt) --拆包

			for i=1,count do
				local tmpData = deepcopy(srcData) --clone一份表

				tmpData.num = (item.num >= dupCnt) and dupCnt or item.num
				insert(attList, tmpData)

				if item.num <= dupCnt then break end
				item.num = item.num - dupCnt
			end
		end
	end

	--清理数据
	local dVar = sbase.getDyanmicVar(actor)
	if dVar then dVar.loot = {} end

	sendItemsInfo(actor)

	--三个附件一封邮件发掉
	local attachmentList = {}
	for _,item in pairs(attList) do
		insert(attachmentList, item)
		if #attachmentList >= MAIL_ATT_MAX_COUNT then
			sendOneMail(actor, attachmentList)
			attachmentList = {}
		end
	end

	if #attachmentList > 0 then
		sendOneMail(actor, attachmentList)
	end

	return true, Langs.msg007
end

function onSendAwardByMail(actor)
	local ret, msg = sendAwardByMail(actor)

	if msg then
		LActor.sendTipmsg(actor, msg, ttMessage)
	end
end

--退出副本时奖励直接走邮件发送
function onFubenExit(actor)
	sendAwardByMail(actor)
end

--注册拾取的事件
function regLootEvent()
	for sceneId,_ in pairs(sceneExpConf) do
		lootevent.regLootEvent(sceneId, addAwardToDepot)
	end
end

mainevent.regResetAftFunc(sendAwardByMail)
fubenevent.registerFubenExit(FUBEN_ID, onFubenExit)

netmsgdispatcher.reg(sysId, protocol.cSendAwardToMail, onSendAwardByMail)
table.insert(InitFnTable, regLootEvent)

