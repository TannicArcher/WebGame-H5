-- 公会聊天

module("guildchat", package.seeall)

local LActor = LActor
local LDataPack = LDataPack
local systemId = Protocol.CMD_Guild
--local common = guildcommon --需要保证加载顺序
local global_chat_cd = 3 -- 公会聊天CD(秒)
local global_chat_char_len = 160 -- 文字最大长度

function handleChat(actor, packet)
	if not System.isCommSrv() then
		local pack = LDataPack.allocPacket()
		if pack then
			LDataPack.writeByte(pack, CrossSrvCmd.SCGuildCmd)
			LDataPack.writeByte(pack, CrossSrvSubCmd.SCGuildCmd_CrossChat)
			LDataPack.writeInt(pack, LActor.getActorId(actor))
			LDataPack.writePacket(pack,packet,false)
			System.sendPacketToAllGameClient(pack, LActor.getServerId(actor))
		end		
		return
	end
	local content = LDataPack.readString(packet)
	handleChatContent(actor, content)
end
-- 
function handleChatContent(actor, content)
	
	local guild = LActor.getGuildPtr(actor)
	if guild == nil then print("guild is nil") return end

	local nowTime = System.getNowTime()
	local actorVar = guildcommon.getActorVar(actor)

	if actorVar.lastchat ~= nil and (nowTime - actorVar.lastchat < global_chat_cd) then
		print("guild chat cd : "..actorVar.lastchat)
		return 
	end

	if System.getStrLenUtf8(content) > global_chat_char_len then
		print("max chat len, actorId : "..LActor.getActorId(actor))
		return 
	end

	content = System.filterText(content)

	local actorData = LActor.getActorData(actor)
	if actorData == nil then return end

	local actors = LGuild.getOnlineActor(LGuild.getGuildId(guild))
	for i = 1, #(actors or {})  do
		local pack = LDataPack.allocPacket(actors[i], systemId, Protocol.sGuildCmd_Chat)
		LDataPack.writeByte(pack, enGuildChatChat)
		LDataPack.writeString(pack, content)
		LDataPack.writeInt(pack, LActor.getActorId(actor))
		LDataPack.writeString(pack, actorData.actor_name)
		LDataPack.writeByte(pack, actorData.job)
		LDataPack.writeByte(pack, actorData.sex)
		LDataPack.writeInt(pack, actorData.vip_level)
		LDataPack.writeByte(pack, actorData.monthcard)
		LDataPack.writeByte(pack, LActor.getGuildPos(actor))
		--LDataPack.writeInt(pack, System.getNowTime())
		LDataPack.writeByte(pack,actorData.zhuansheng_lv)
		LDataPack.writeShort(pack,actorData.level)
		LDataPack.writeString(pack,LGuild.getGuildName(guild))
		
		LDataPack.flush(pack)
	end

	LGuild.addChatLog(guild, enGuildChatChat, content, actor)

	actorVar.lastchat = nowTime
	LActor.log(actor, "guildchat.handleChat", "make1", actorVar.lastchat)
	--发到跨服
	if System.isCommSrv() then
		local pack = LDataPack.allocPacket()
		if pack then
			LDataPack.writeByte(pack, CrossSrvCmd.SCGuildCmd)
			LDataPack.writeByte(pack, CrossSrvSubCmd.SCGuildCmd_Broadcast)
			LDataPack.writeInt(pack, LGuild.getGuildId(guild))
			LDataPack.writeByte(pack, enGuildChatChat)
			LDataPack.writeString(pack, content)
			LDataPack.writeInt(pack, LActor.getActorId(actor))
			LDataPack.writeString(pack, actorData.actor_name)
			LDataPack.writeByte(pack, actorData.job)
			LDataPack.writeByte(pack, actorData.sex)
			LDataPack.writeInt(pack, actorData.vip_level)
			LDataPack.writeByte(pack, actorData.monthcard)
			LDataPack.writeByte(pack, LActor.getGuildPos(actor))
			--LDataPack.writeInt(pack, System.getNowTime())
			LDataPack.writeByte(pack,actorData.zhuansheng_lv)
			LDataPack.writeShort(pack,actorData.level)
			LDataPack.writeString(pack,LGuild.getGuildName(guild))
			System.sendPacketToAllGameClient(pack, csbase.GetMainBattleSvrId())
		end
	end
end

-- 获取聊天记录
function handleChatLog(actor, packet)
	local guild = LActor.getGuildPtr(actor)
	if guild == nil then return end

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_ChatLog)
	LGuild.writeChatLog(guild, pack)
	LDataPack.flush(pack)
end

-- 发送帮派公告
function sendNotice(guild, content)
	local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, systemId)
	LDataPack.writeByte(pack, Protocol.sGuildCmd_Chat)
	LDataPack.writeByte(pack, enGuildChatSystem)
	LDataPack.writeString(pack, content)
	LDataPack.writeInt(pack, System.getNowTime())
	LGuild.broadcastData(guild, pack)

	LGuild.addChatLog(guild, enGuildChatSystem, content)
end

-- 发送帮派公告（该公告会显示在公会图标上）
function sendNoticeEx(guild, content)
	local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, systemId)
	LDataPack.writeByte(pack, Protocol.sGuildCmd_Chat)
	LDataPack.writeByte(pack, enGuildChatShow)
	LDataPack.writeString(pack, content)
	LDataPack.writeInt(pack, System.getNowTime())
	LGuild.broadcastData(guild, pack)

	LGuild.addChatLog(guild, enGuildChatSystem, content)
end

function onLogin(actor)
	-- local guild = LActor.getGuildPtr(actor)
	-- if guild == nil then return end
end

--跨服收到单服公会的信息广播
local function onBroadcastPack(sId, sType, dp)
	local guild_id = LDataPack.readInt(dp)
	if guild_id and guild_id ~= 0 then
		local actorlist = System.getOnlineActorList()
		if actorlist then
			for i=1,#actorlist do
				if actorlist[i] and LActor.getGuildId(actorlist[i]) == guild_id then
					print("onBroadcastPack guild:"..guild_id)
					local pack = LDataPack.allocPacket(actorlist[i], systemId, Protocol.sGuildCmd_Chat)
					LDataPack.writePacket(pack,dp,false)
					LDataPack.flush(pack)
				end
			end
		end
	end
end

--游戏服收到跨服来的公会聊天包
local function onCrossChatPack(sId, sType, dp)
	local actorid = LDataPack.readInt(dp)
	local content = LDataPack.readString(dp)
	asynevent.reg(actorid,function(imageActor,content)
		handleChatContent(imageActor, content)
	end, content)
end

--启动初始化
local function initGlobalData()
	actorevent.reg(aeUserLogin, onLogin)
	netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_Chat, handleChat)
	netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_ChatLog, handleChatLog)

	if not System.isCommSrv() then
		csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_Broadcast, onBroadcastPack)
	else
		csmsgdispatcher.Reg(CrossSrvCmd.SCGuildCmd, CrossSrvSubCmd.SCGuildCmd_CrossChat, onCrossChatPack)
	end
end
table.insert(InitFnTable, initGlobalData)
