module("chat", package.seeall)


global_chat_cd         = ChatConstConfig.chatCd
global_chat_list_max   = ChatConstConfig.saveChatListSize
global_chat_char_len   = ChatConstConfig.chatLen
global_chat_send_level = ChatConstConfig.openLevel


local function chsize(char)
	if not char then
		print("not char")
		return 0
	elseif char > 240 then
		return 4
	elseif char > 225 then
		return 3
	elseif char > 192 then
		return 2
	else
		return 1
	end
end

-- 计算utf8字符串字符数, 各种字符都按一个字符计算
-- 例如utf8len("1你好") => 3
function utf8len(str)
	local len = 0
	local currentIndex = 1
	while currentIndex <= #str do
		local char = string.byte(str, currentIndex)
		currentIndex = currentIndex + chsize(char)
		len = len +1
	end
	return len
end


local function getData(actor)
	local var = LActor.getStaticVar(actor) 

	if var == nil then 
		return nil
	end
	if var.chat == nil then
		var.chat = {}
	end
	if var.chat.cd == nil then 
		var.chat.global_chat_cd = os.time()
	end
	if var.chat.shutup == nil then 
		var.chat.shutup = 0
	end
	if var.chat.chat_size == nil then 
		var.chat.chat_size = 0
	end
	return var.chat
end

local function rsfData(actor)
	local var = getData(actor)
	var.chat_size = 0
end

local function getConfig(actor)
	local power = LActor.getActorData(actor).total_power
	local id = 0
	for i = 1,#(ChatLevelConfig) do 
		local conf = ChatLevelConfig[i]
		if power >= conf.power then 
			id = i
		else 
			break
		end
	end
	return ChatLevelConfig[id]
end

local function getGlobalData()
	local var = System.getStaticChatVar()
	if var == nil then 
		return nil
	end
	if var.chat == nil then 
		var.chat = {}
	end
	if var.chat.chat_list_begin == nil then 
		var.chat.chat_list_begin = 0
	end
	if var.chat.chat_list_end == nil then
		var.chat.chat_list_end = 0;
	end
	if var.chat.chat_list == nil then
		var.chat.chat_list = {}
	end
	return var.chat;
end

local function addGlobalList(tbl)
	if tbl ~= nil then 

		local var = getGlobalData()
		var.chat_list[var.chat_list_end] = tbl
		var.chat_list_end = var.chat_list_end + 1
		while (var.chat_list_end - var.chat_list_begin) > global_chat_list_max do 
			var.chat_list[var.chat_list_begin] = nil
			var.chat_list_begin = var.chat_list_begin + 1
		end
	end

end

local function sendGlobalList(actor)

	local var = getGlobalData()

	local b = var.chat_list_begin 
	local e = var.chat_list_end

	while (b ~= e) do 
		local tbl = var.chat_list[b]
		if tbl ~= nil then 
			local npack = LDataPack.allocPacket(actor, Protocol.CMD_Chat, Protocol.sChatCmd_ChatMsg)
			if npack == nil then 
				break
			end

			LDataPack.writeByte(npack,tbl.channe)
			LDataPack.writeUInt(npack,tbl.actor_id)
			LDataPack.writeInt(npack,tbl.sid or 0)
			LDataPack.writeString(npack,tbl.actor_name)
			LDataPack.writeByte(npack,tbl.job)
			LDataPack.writeByte(npack,tbl.sex)
			LDataPack.writeByte(npack,tbl.vip_level)
			LDataPack.writeByte(npack,tbl.monthcard)
			LDataPack.writeByte(npack,tbl.last_tianti_level and tbl.last_tianti_level or 0)
			LDataPack.writeByte(npack,tbl.is_last_tianti_first and tbl.is_last_tianti_first or 0)
			LDataPack.writeByte(npack,tbl.zhuansheng_lv or 0)
			LDataPack.writeShort(npack,tbl.level or 0)
			LDataPack.writeString(npack,tbl.guildName or "")
			LDataPack.writeUInt(npack,tbl.target_actor_id)
			LDataPack.writeString(npack,tbl.msg)
			LDataPack.flush(npack)
		end
		b = b + 1
	end

end

local function addBasicData(actor,npack,tbl)
	local data = LActor.getActorData(actor)
	local guild = LActor.getGuildPtr(actor)
	LDataPack.writeUInt(npack,data.actor_id)
	LDataPack.writeInt(npack, LActor.getServerId(actor))
	LDataPack.writeString(npack,data.actor_name)
	LDataPack.writeByte(npack,data.job)
	LDataPack.writeByte(npack,data.sex)
	LDataPack.writeByte(npack,data.vip_level)
	LDataPack.writeByte(npack,data.monthcard)
	LDataPack.writeByte(npack,tianti.getLastTiantiLevel(actor))
	LDataPack.writeByte(npack,tiantirank.isLastWeekFirst(actor) and 1 or 0)
	LDataPack.writeByte(npack,data.zhuansheng_lv)
	LDataPack.writeShort(npack,data.level)
	local guildName = ""
	if guild then guildName = LGuild.getGuildName(guild) end
	LDataPack.writeString(npack,guildName)
	
	if tbl ~= nil then 
		tbl.actor_id = data.actor_id
		tbl.sid = LActor.getServerId(actor)
		tbl.actor_name = data.actor_name
		tbl.job = data.job
		tbl.sex = data.sex
		tbl.vip_level = data.vip_level
		tbl.monthcard = data.monthcard
		tbl.last_tianti_level = tianti.getLastTiantiLevel(actor)
		tbl.is_last_tianti_first = tiantirank.isLastWeekFirst(actor) and 1 or 0
		tbl.zhuansheng_lv = data.zhuansheng_lv
		tbl.level = data.level
		tbl.guildName = guildName
	end


end

function sendSystemTips(actor,level,pos,tips)
	local l = LActor.getZhuanShengLevel(actor) * 1000
	l = l + LActor.getLevel(actor)
	if l < level then 
		return
	end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Chat, Protocol.sChatCmd_Tipmsg)
	if npack == nil then 
		return
	end
	LDataPack.writeInt(npack,level)
	LDataPack.writeInt(npack,pos)
	LDataPack.writeString(npack,tips)
	LDataPack.flush(npack)
end

function sendGlobalMsg(actor,channe,msg)
	if msg == nil then 
		print("not msg")
		return false
	end
	msg = System.filterText(msg)
	if utf8len(msg) > global_chat_char_len then 
		print("char len error ")
		return false
	end
	if channe == nil or (channe ~= ciChannelAll) then 
		return false
	end
	local var = getData(actor) 
	if channe == ciChannelAll and var.global_chat_cd > os.time() then 
		print("global chat cd " .. (os.time() - var.global_chat_cd))
		return false
	end
	if var.shutup > os.time() then 
		print("shutup  " .. (var.shutup - os.time()))
		return false
	end

	local level = LActor.getZhuanShengLevel(actor) * 1000
	level = level + LActor.getLevel(actor)
	if level < global_chat_send_level then 
		print("global chat level")
		return false
	end
	local conf = getConfig(actor) 
	if conf == nil then 
		print(LActor.getActorId(actor) .. "  chat not has conf ")
		return false
	end
	local var = getData(actor)
	if var.chat_size >= conf.chatSize then 
		sendSystemTips(actor,1,2,"没有发言次数")
		return false
	end
	local npack = LDataPack.allocPacket()
	if npack == nil then return end

	LDataPack.writeByte(npack,Protocol.CMD_Chat)
	LDataPack.writeByte(npack,Protocol.sChatCmd_ChatMsg)

	LDataPack.writeByte(npack,channe)
	if channe == ciChannelAll then 
		local tbl = {}
		addBasicData(actor,npack,tbl)
		LDataPack.writeUInt(npack,0)
		LDataPack.writeString(npack,msg)
		tbl.channe = channe
		tbl.target_actor_id = 0
		tbl.msg = msg
		addGlobalList(tbl)
	else
		addBasicData(actor,npack)
		LDataPack.writeUInt(npack,0)
		LDataPack.writeString(npack,msg)

	end
	System.broadcastData(npack)
	if channe == ciChannelAll then 
		var.global_chat_cd = os.time() + global_chat_cd
	end
	var.chat_size = var.chat_size + 1
	return true
end


--net
local function onChatMsg(actor,packet)
	local channe = LDataPack.readByte(packet)
	local target_actor_id = LDataPack.readUInt(packet)
	local msg = LDataPack.readString(packet)
	if channe == ciChannelAll then 
		local ret = sendGlobalMsg(actor,channe,msg)
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Chat, Protocol.sChatCmd_ChatMsgResult)
		if npack == nil then 
			return
		end
		LDataPack.writeByte(npack,ret and 1 or 0)
		LDataPack.flush(npack)
	end
end

local function sendShutUpTime(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Chat, Protocol.sChatCmd_ShutUpTime)
	if npack == nil then return end
	local var  = getData(actor)
	LDataPack.writeInt(npack, var.shutup or 0)
	LDataPack.flush(npack)
end

local function onLogin(actor) 
	LActor.postScriptEventLite(actor,6000,sendGlobalList,actor)
	sendShutUpTime(actor)
end

local function onNewDay(actor)
	rsfData(actor)
end

-- extern 
function shutup(actor,time)
	local var  = getData(actor)
	var.shutup = os.time() + (time * 60)
	sendShutUpTime(actor)
	print(LActor.getActorId(actor).." chat.shutup:"..var.shutup)
end

function releaseShutup(actor)
	local var  = getData(actor)
	var.shutup = 0
	sendShutUpTime(actor)
	print(LActor.getActorId(actor).." chat.releaseShutup:"..var.shutup)
end

_G.shutup        = shutup
_G.releaseShutup = releaseShutup
actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_Chat, Protocol.cChatCmd_ChatMsg,onChatMsg)
