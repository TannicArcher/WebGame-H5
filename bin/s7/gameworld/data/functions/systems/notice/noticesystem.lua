module("noticemanager", package.seeall)

global_notice_list_max = 50


local function getNoticeData()
	local var = System.getStaticChatVar()
	if var == nil then 
		return nil
	end
	if var.Notice == nil then 
		var.Notice = {}
	end
	if var.Notice.notice_list_begin == nil then 
		var.Notice.notice_list_begin = 0
	end
	if var.Notice.notice_list_end == nil then
		var.Notice.notice_list_end = 0;
	end
	if var.Notice.notice_list == nil then
		var.Notice.notice_list = {}
	end
	return var.Notice;
end

local function addNoticeList(type, content)
	if type == 3 then return end --2017年7月4日 17:15:07 策划说,type==3不保存到公告列表里面,登陆时也不需要下发, 彪
	local tbl   = {}
	tbl.type    = type
	tbl.content = content

	local var = getNoticeData()
	var.notice_list[var.notice_list_end] = tbl
	var.notice_list_end = var.notice_list_end + 1
	while (var.notice_list_end - var.notice_list_begin) > global_notice_list_max do 
		var.notice_list[var.notice_list_begin] = nil
		var.notice_list_begin = var.notice_list_begin + 1
	end
end

local function sendNoticeList(actor)
	local var = getNoticeData()

	local b = var.notice_list_begin 
	local e = var.notice_list_end

	--避免死循环（理论上不可能出现）
	if b > e then 
		print("ERROR: SendNoticeList fall into endless loop")
		return 
	end  

	while (b ~= e) do 
		local tbl = var.notice_list[b]
		if tbl then 
			local npack = LDataPack.allocPacket(actor, Protocol.CMD_Notice, Protocol.sNoticeCmd_NoticeSync)
			if npack then
				LDataPack.writeShort(npack,tbl.type)
				LDataPack.writeString(npack,tbl.content)
				LDataPack.writeByte(npack, 1)
				LDataPack.flush(npack)
			end
		end
		b = b + 1
	end
end

local function getData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then 
		return nil
	end
	if var.notice == nil then 
		var.notice = {}
	end
	if var.notice.time == nil then 
		var.notice.time = 1 --防止被除0
	end
	return var.notice
end

local function sendTodayLook(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Notice, Protocol.sNoticeCmd_TodayLook)
	if npack == nil then 
		return
	end
	local var = getData(actor)
	local curr_time = os.time()
	LDataPack.writeByte(npack,utils.getDay(var.time) ~= utils.getDay(curr_time) and 1 or 0)
	LDataPack.flush(npack)
end

local function onSetTodayLook(actor,packet)
	local var = getData(actor)
	var.time = os.time()
end

local function onNoticeLogin(actor)
	sendTodayLook(actor)
	LActor.postScriptEventLite(actor,5000,sendNoticeList,actor)
end 

function getNoticeConfigById(id)
	return NoticeConfig[id]
end

function broadCastNotice(id, ...)
	local config = getNoticeConfigById(id)
	if (not config) then
		return
	end
	local content = string.format(config.content, unpack({...}))
	broadcastNotice(config.type, content)
end

function broadCastNoticeToSrv(id, sid, ...)
	local config = getNoticeConfigById(id)
	if (not config) then
		return
	end
	local content = string.format(config.content, unpack({...}))
	broadcastNotice(config.type, content, sid)
end

function broadCastNoticeToAllSrv(id, ...)
	if not System.isCommSrv() then return end
	local config = getNoticeConfigById(id)
	if (not config) then
		return
	end
	local content = string.format(config.content, unpack({...}))
	local pack = LDataPack.allocPacket()
	if pack then
		LDataPack.writeByte(pack, CrossSrvCmd.SCrossNetCmd)
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCrossNetCmd_AnnoTips)
		LDataPack.writeShort(pack, config.type)
		LDataPack.writeString(pack, content)
		System.sendPacketToAllGameClient(pack, csbase.GetBattleSvrId(bsBattleSrv))
	end
end

function broadcastNotice(type, content, sid)
   if not System.isCommSrv() then
		local pack = LDataPack.allocPacket()
		if pack then
			LDataPack.writeByte(pack, CrossSrvCmd.SCrossNetCmd)
			LDataPack.writeByte(pack, CrossSrvSubCmd.SCrossNetCmd_AnnoTips)
			LDataPack.writeShort(pack, tonumber(type))
			LDataPack.writeString(pack, content)
			System.sendPacketToAllGameClient(pack, sid or 0)
		end
   else
		addNoticeList(type, content)
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, Protocol.CMD_Notice)
		LDataPack.writeByte(npack, Protocol.sNoticeCmd_NoticeSync)
		LDataPack.writeShort(npack, tonumber(type))
		LDataPack.writeString(npack, content)
		LDataPack.writeByte(npack, 0)
		System.broadcastData(npack)
   end
end

_G.broadCastNotice = broadCastNotice
_G.broadcastNotice = broadcastNotice

actorevent.reg(aeUserLogin, onNoticeLogin)
netmsgdispatcher.reg(Protocol.CMD_Notice, Protocol.cNoticeCmd_SetTodayLook, onSetTodayLook)
local function onCrossServerBroadNotice(sId, sType, dp)
	local stype = LDataPack.readShort(dp)
	local content = LDataPack.readString(dp)
	broadcastNotice(stype, content)
end
csmsgdispatcher.Reg(CrossSrvCmd.SCrossNetCmd, CrossSrvSubCmd.SCrossNetCmd_AnnoTips, onCrossServerBroadNotice)