module("mailsystem", package.seeall)

local timeOut = 24 * 3600 * 15 --15天
local maxMailNum = 50

function getMailVar(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then
		return
	end

	if (var.mail == nil) then
		var.mail                = {}
		var.mail.id             = 0
		var.mail.max_global_uid = System.getGlobalMailMaxUid()
	end

	return var.mail
end


function getGlobalMailMaxUid(actor)
	local var = getMailVar(actor)

	if var == nil then
		return 0
	end

	if var.max_global_uid == nil then
		return 0
	end
	return var.max_global_uid
end
_G.getGlobalMailMaxUid = getGlobalMailMaxUid

function setGlobalMailMaxUid(actor,uid)
	local var = getMailVar(actor)
	if var == nil then
		return
	end
	var.max_global_uid = uid
end
_G.setGlobalMailMaxUid = setGlobalMailMaxUid
function getNextMailId(actor)
	local mailVar = getMailVar(actor)
	if (not mailVar) then
		return 0
	end

	local id = mailVar.id
	mailVar.id = mailVar.id + 1
	return id
end
_G.getNextMailId = getNextMailId

function readMail(actor, uid)
	local awardStatus, readStatus, time, head, context, tAwardList = LActor.getMailInfo(actor, uid)
	if (not awardStatus) then
		return
	end

	if (readStatus == 0) then
		LActor.changeMailReadStatus(actor, uid)
		readStatus = 1
	end

	mailInfoSync(actor, uid, awardStatus, readStatus, time, head, context, tAwardList)
end

function mailInfoSync(actor, uid, awardStatus, readStatus, time, head, context, tAwardList)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mail, Protocol.sMailCmd_ReqRead)
	if pack == nil then return end

	LDataPack.writeData(pack, 7,
						dtInt, uid,
						dtString, head,
						dtInt, time,
						dtInt, readStatus,
						dtInt, awardStatus,
						dtString, context,
						dtInt, #tAwardList)
	for _,tb in ipairs(tAwardList) do
		local id = tb[1]
		local nType = tb[2]
		local count = tb[3]
		LDataPack.writeData(pack, 3, dtInt, nType, dtInt, id, dtInt, count)
	end
	LDataPack.flush(pack)
end

function mailListSync(actor)
	local tMailList = LActor.getMailList(actor)
	if (not tMailList) then
		return
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mail, Protocol.sMailCmd_MailListSync)
	if pack == nil then return end

	LDataPack.writeData(pack, 1, dtInt, #tMailList)
	for index,tb in ipairs(tMailList) do
		local uid = tb[1]
		local head = tb[2]
		local sendtime = tb[3]
		local readStatus = tb[4]
		local awardStatus = tb[5]
		LDataPack.writeData(pack, 5, dtInt, uid, dtString, head,
							 dtInt, sendtime, dtInt, readStatus, dtInt, awardStatus)
	end
	LDataPack.flush(pack)
end

--发送邮件的接口
--tMailData = {}
--tMailData.head 		邮件标题，字符串
--tMailData.context 	邮件正文，字符串
--tMailData.tAwardList 	附件(不能超过10个)，表，{{type = xx,id = xx,count = xx},...}
function sendMailById(actorId, tMailData, serverId)
	--跨服的邮件
	if serverId and serverId ~= System.getServerId() then
		local pack = LDataPack.allocPacket()
		if pack == nil then return end
		LDataPack.writeByte(pack, CrossSrvCmd.SCrossNetCmd)
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCrossNetCmd_TransferMail)
		LDataPack.writeData(pack, 3, dtInt, actorId, dtString, tMailData.head or "", dtString, tMailData.context or "")
		LDataPack.writeInt(pack, #(tMailData.tAwardList or {}))
		for _,award in ipairs(tMailData.tAwardList or {}) do
			LDataPack.writeInt(pack, award.type)
			LDataPack.writeInt(pack, award.id)
			LDataPack.writeInt(pack, award.count)
		end
		System.sendPacketToAllGameClient(pack, serverId)
		return
	end
	--本服的邮件
    local actordata = LActor.getActorDataById(actorId)
    if actordata then
        local awardSize = 0
        if type(tMailData.tAwardList) == "table" then
            awardSize = #tMailData.tAwardList
        end
        System.logCounter(actorId, actordata.account_name, actordata.level,
            "sendmailbyid", tostring(tMailData.head), tostring(tMailData.context), "", awardSize, "", "")
    end

	if (not actorId or not tMailData) then
		return
	end

	if (not tMailData.head or type(tMailData.head) ~= "string") then
		tMailData.head = ""
	end

	if (not tMailData.context or type(tMailData.context) ~= "string") then
		tMailData.context = ""
	end

	if (not tMailData.tAwardList or type(tMailData.tAwardList) ~= "table") then
		tMailData.tAwardList = {}
	end

	local mailCount = math.ceil(#tMailData.tAwardList/10)
    if mailCount == 0 then mailCount = 1 end
	for num = 1,mailCount do
		local tAwardInfo = {}
		for i=10*(num-1)+1,10*num do
			if (tMailData.tAwardList[i]) then
				table.insert(tAwardInfo, tMailData.tAwardList[i].type or 0)
				table.insert(tAwardInfo, tMailData.tAwardList[i].id or 0)
				table.insert(tAwardInfo, tMailData.tAwardList[i].count or 0)
			end
		end

		local head = tMailData.head
		if (mailCount > 1) then
			head = head .. string.format("(%d)", num)
		end

		local time = os.time()
        System.sendMail(actorId, head, tMailData.context, time, #tAwardInfo, unpack(tAwardInfo))
	end
end

local function TransferMail(sId, sType, dp)
	local actorId = LDataPack.readInt(dp)
	local tMailData = {}
	tMailData.head = LDataPack.readString(dp)
	tMailData.context = LDataPack.readString(dp)
	tMailData.tAwardList = {}
	local count = LDataPack.readInt(dp)
	for i=1, count do
		local reward = {}
		reward.type = LDataPack.readInt(dp)
		reward.id = LDataPack.readInt(dp)
		reward.count = LDataPack.readInt(dp)
		table.insert(tMailData.tAwardList, reward)
	end
	sendMailById(actorId, tMailData)
end
csmsgdispatcher.Reg(CrossSrvCmd.SCrossNetCmd, CrossSrvSubCmd.SCrossNetCmd_TransferMail, TransferMail)

function mailAward(actor, uidList)
	local mailStatusList = {}
	for _,uid in ipairs(uidList) do
		local awardStatus, readStatus, time, head, context, tAwardList = LActor.getMailInfo(actor, uid)
		if (awardStatus) then
			if (awardStatus == 0 and giveAward(actor, uid, tAwardList)) then
				awardStatus = 1
			end

			if (readStatus == 0) then
				LActor.changeMailReadStatus(actor, uid)
				readStatus = 1
			end
			table.insert(mailStatusList,{uid = uid, readStatus = readStatus, awardStatus = awardStatus})
		end
	end

	ReAwardSync(actor, mailStatusList)
end

function giveAward(actor, uid, tAwardList)
	local needSpace = 0
	for _,tb in pairs(tAwardList) do
		local nType = tb[2]
		if (nType == AwardType_Item) then
			local itemId = tb[1]
			local config = ItemConfig[itemId]
			if config and ((config.type == ItemType_Equip) or (config.type == ItemType_WingEquip) or (config.type == ItemType_TogetherHit)) then
				needSpace = needSpace + 1
			end
		end
	end

	if needSpace ~= 0 and  (LActor.getEquipBagSpace(actor) < needSpace) then
		LActor.sendTipWithId(actor, 1)
		return false
	end

	LActor.changeMailAwardStatus(actor, uid)

	for _,tb in ipairs(tAwardList) do
		local id = tb[1]
		local nType = tb[2]
		local count = tb[3]
		LActor.giveAward(actor, nType, id, count, "mail award")
	end

	return true
end

function ReAwardSync(actor, mailStatusList)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mail, Protocol.sMailCmd_ReAward)
	if pack == nil then return end

	LDataPack.writeData(pack, 1, dtInt, #mailStatusList)
	for _,tb in ipairs(mailStatusList) do
		LDataPack.writeData(pack, 3,
							dtInt, tb.uid,
							dtInt, tb.readStatus,
							dtInt, tb.awardStatus)
	end
	LDataPack.flush(pack)
end

--删除过期邮件
--由于邮件貌似也不是什么很迫切要删除的东西
--所以目前是登录的时候删一次，以后需要再做定时器吧
function deleteTimeOutMail(actor)
	local tMailList = LActor.getMailList(actor)
	if (not tMailList) then
		return
	end

	for index,tb in ipairs(tMailList) do
		local uid = tb[1]
		local sendtime = tb[3]
		local curTime = os.time()
		if (curTime - sendtime >= timeOut) then
			LActor.deleteMail(actor, uid)
		end
	end
end

function deleteMailSync(actor, uid)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mail, Protocol.sMailCmd_DeleteMail)
	if pack == nil then return end

	LDataPack.writeData(pack, 1, dtInt, uid)

	LDataPack.flush(pack)
end

_G.deleteMailSync = deleteMailSync


function recvMail(actor, uid)
	local awardStatus, readStatus, time, head, context, tAwardList = LActor.getMailInfo(actor, uid)
	if (not awardStatus) then
		return
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Mail, Protocol.sMailCmd_AddMail)
	if pack == nil then
		return
	end

	LDataPack.writeData(pack, 5, dtInt, uid, dtString, head, dtInt, time, dtInt, readStatus, dtInt, awardStatus)

	LDataPack.flush(pack)
end

_G.recvMail = recvMail

function onLogin(actor)
	mailListSync(actor)
	deleteTimeOutMail(actor)
end

function readMail_c2s(actor, packet)
	local uid = LDataPack.readInt(packet)
	readMail(actor, uid)
end

function sendConfigMail(actorId, mailId)
	local config = mailcommon.getConfigByMailId(mailId)
	if (not config) then
		return
	end

	local tMailData = {}
	tMailData.head = config.title
	tMailData.context = config.content
	tMailData.tAwardList = config.attachment
	sendMailById(actorId, tMailData)
end

function mailAward_c2s(actor, packet)
	local count = LDataPack.readInt(packet)
	if count > maxMailNum then return end
	local uidList = {}
	for i=1,count do
		local uid = LDataPack.readInt(packet)
		table.insert(uidList, uid)
	end
	mailAward(actor, uidList)
end

local function sendLevelMail(actor, level)
	local conf = LevelMailConfig[level]
	if not conf then return end

	local var = getMailVar(actor)
	if not var.levelList then var.levelList = {} end

	--该等级领过不能再领了
	for i=1, #(var.levelList) do
		if level == var.levelList[i] then return end
	end

	for _, id in pairs(conf.idList or {}) do mailcommon.sendMailById(LActor.getActorId(actor), id) end

	var.levelList[#(var.levelList)+1] = level
end

local function onLevelUp(actor, level)
	if not actor then return end
	sendLevelMail(actor, level)
end

local function onZhuanShengUp(actor, zsLevel)
	if not actor then return end
	sendLevelMail(actor, zsLevel*1000)
end

local function onNewDay(actor)
	local var = getMailVar(actor)
	var.loginDay = (var.loginDay or 0) + 1

	if LoginDayMailConfig[var.loginDay] then
		local conf = LoginDayMailConfig[var.loginDay]
		for _, id in pairs(conf.idList or {}) do mailcommon.sendMailById(LActor.getActorId(actor), id) end
	end
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeLevel, onLevelUp)
actorevent.reg(aeZhuansheng, onZhuanShengUp)
actorevent.reg(aeNewDayArrive, onNewDay)
netmsgdispatcher.reg(Protocol.CMD_Mail, Protocol.cMailCmd_Read, readMail_c2s)
netmsgdispatcher.reg(Protocol.CMD_Mail, Protocol.cMailCmd_Award, mailAward_c2s)

--发送全服邮件的接口
--tMailData = {}
--tMailData.head 		邮件标题，字符串
--tMailData.context 	邮件正文，字符串
--tMailData.tAwardList 	附件(不能超过10个)，表，{{type = xx,id = xx,count = xx},...}
function gmSendMailToAll(tMailData)
	if (not tMailData) then
		return
    end

	if (not tMailData.head or type(tMailData.head) ~= "string") then
		tMailData.head = ""
	end

	if (not tMailData.context or type(tMailData.context) ~= "string") then
		tMailData.context = ""
	end

	if (not tMailData.tAwardList or type(tMailData.tAwardList) ~= "table") then
		tMailData.tAwardList = {}
	end

    --ly:暂时先这么做, 会导致大量假玩家同时登陆,上线前要改
    --所有玩家
    local actorDatas = System.getAllActorData()
    for _, data in ipairs(actorDatas) do
        local actorData = toActorBasicData(data)

        sendMailById(actorData.actor_id, tMailData)
    end
end

