--好友系统
module("friendsystem", package.seeall)

local LActor = LActor
local LDataPack = LDataPack
local LangFriend = LAN.Friend
local friendtodb = friendtodb

local ltUndefine      = friendcommon.ltUndefine
local ltFriend 		  = friendcommon.ltFriend
local ltChats 		  = friendcommon.ltChats
local ltApply   	  = friendcommon.ltApply
local ltApList		  = friendcommon.ltApList
local ltBlack  		  = friendcommon.ltBlack
local ltMax           = friendcommon.ltMax

local isFriendSystemOpen     = friendcommon.isFriendSystemOpen
local getFriendContentLimit  = friendcommon.getFriendContentLimit
local LoadDbFriend           = friendcommon.LoadDbFriend

local getList                = friendcommon.getList
local getListCount           = friendcommon.getListCount
local isListFull             = friendcommon.isListFull

local addToList              = friendcommon.addToList
local delFromList            = friendcommon.delFromList
local isInList               = friendcommon.isInList
local getListData            = friendcommon.getListData
local updateChatsTime        = friendcommon.updateChatsTime


local dbCmd = DbCmd.FriendCmd
local dbEntity = dbEntity or 1

local offlineFriendMsg = msgsystem.offlineFriendMsg

-- 发送离线消息待上线处理
local function offlineMsg(actor,pack)
end

-- 数据打包
local function setCommomDataToNpack(actor, npack, actorBId, lt, value)
	local actorPtr = LActor.getActorById(actorBId)
	local basicData = nil
	local online = 0
	if actorPtr then
		online = 1
		basicData = LActor.getActorData(actorPtr)
	else
		online = 0
		basicData = LActor.getActorDataById(actorBId)
	end
	if basicData == nil then
		return false
	end

	-- print("********************************")
	-- print(basicData.actor_id)
	-- print(basicData.actor_name)
	-- print(online)
	-- print(basicData.job)
	-- print(basicData.sex)
	-- print(basicData.vip_level)
	-- print(basicData.level)
	-- print(basicData.zhuansheng_lv)
	-- print(basicData.monthcard)
	-- print(basicData.tianti_level)
	-- print(basicData.total_power)
	-- print(basicData.last_online_time)
	-- print(value and value.addfriendtime or "")
	-- print(value and value.lastcontact or "")
	-- print("********************************")

	LDataPack.writeUInt(npack,basicData.actor_id)
	LDataPack.writeString(npack,basicData.actor_name)
	local guild_name = ""
	if basicData.guild_id_ and basicData.guild_id_ > 0 then
		local guild = LGuild.getGuildById(basicData.guild_id_)
		if guild then
			guild_name = LGuild.getGuildName(guild)
		end
	end
	LDataPack.writeString(npack,guild_name)
	LDataPack.writeByte(npack,online)
	LDataPack.writeByte(npack,basicData.job)
	LDataPack.writeByte(npack,basicData.sex)
	LDataPack.writeByte(npack,basicData.vip_level)
	LDataPack.writeByte(npack,basicData.level)
	LDataPack.writeByte(npack,basicData.zhuansheng_lv)
	LDataPack.writeByte(npack,basicData.monthcard)
	LDataPack.writeByte(npack,basicData.tianti_level)
	--*******************上周第一,暂时填0先
	LDataPack.writeByte(npack, 0)
	LDataPack.writeInt(npack,basicData.total_power)

	if ltFriend == lt then
		--最后上线时间
		LDataPack.writeInt(npack,System.getNowTime() - basicData.last_online_time)
	elseif ltChats == lt then
		--最后联系时间
		LDataPack.writeInt(npack,value.lastcontact or basicData.last_online_time)
	elseif ltApply == lt then
		--申请时间
		LDataPack.writeInt(npack,value.addfriendtime or basicData.last_online_time)
	elseif ltBlack == lt then
	end
	return true	
end

-- 下发列表数据
local function sendList(actor,lt)
	if not (lt > ltUndefine and lt < ltMax) then
		print(LActor.getActorId(actor) .. "friendsystem.sendList lt error ")
		return
	end

	local list = getList(actor,lt)
	if list == nil then 
		print("list is nil")
		return 
	end

	local protoId = Protocol.sFriendCmd_GetFriendList
	if ltFriend == lt then
		protoId = Protocol.sFriendCmd_GetFriendList
	elseif ltChats == lt then
		protoId = Protocol.sFriendCmd_GetChatsList
	elseif ltApply == lt then
		protoId = Protocol.sFriendCmd_GetApplyList
	elseif ltBlack == lt then
		protoId = Protocol.sFriendCmd_GetBlackList
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Friend, protoId)
	if npack == nil then return false end
	local pos = LDataPack.getPosition(npack)
	LDataPack.writeInt(npack, 0)
	local count = 0
	for actorBId, value in pairs(list.data) do
		if setCommomDataToNpack(actor, npack, actorBId, lt, value) then
			count = count + 1
		end
	end
	
	local tpos = LDataPack.getPosition(npack)
	LDataPack.setPosition(npack, pos)
	LDataPack.writeInt(npack, count)
	LDataPack.setPosition(npack, tpos)
	LDataPack.flush(npack)
end

local function sendAddListMember(actor,lt,actorId)
	if not (lt > ltUndefine and lt < ltMax) then
		print(LActor.getActorId(actor) .. "friendsystem.sendDelListMember lt error ")
		return
	end

	local data = getListData(actor,lt,actorId)
	if not data then 
		print(LActor.getActorId(actor) .. "friendsystem.sendDelListMember data error ")
		return
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Friend, Protocol.sFriendCmd_AddListX)
	if npack == nil then return false end
	LDataPack.writeByte(npack, lt)
	setCommomDataToNpack(actor, npack, actorId, lt, data)
	LDataPack.flush(npack)
end
-- 
function sendDelListMember(actor,lt,actorId)
	if not (lt > ltUndefine and lt < ltMax) then
		print(LActor.getActorId(actor) .. "friendsystem.sendDelListMember lt error ")
		return
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Friend, Protocol.sFriendCmd_DelListX)
	if npack == nil then return false end
	LDataPack.writeByte(npack, lt)
	LDataPack.writeUInt(npack, actorId)
	LDataPack.flush(npack)
end

-- Comments: 请求加好友
local function sAddFriend(actor, pack)
	if not isFriendSystemOpen(actor) then
		-- LActor.sendTipmsg(actor, LangFriend.fr033, ttScreenCenter)
		return
	end

	local actorBId = LDataPack.readUInt(pack)
	local actorBName = LDataPack.readString(pack)

	if actorBId == 0 then
		--根据角色名字查id
		actorBId = LActor.getActorIdByName(actorBName)
		if actorBId == 0 then
			LActor.sendTipmsg(actor, LangFriend.fr034, ttScreenCenter)
			return
		end
	end

	--加自己为好友
	local actorId = LActor.getActorId(actor)
	if actorId == actorBId then return end

	--玩家列表己满
	if isListFull(actor, ltFriend) then
		LActor.sendTipmsg(actor, LangFriend.fr008, ttScreenCenter)
		return
	end

	--如果B己经是A的好友
	if isInList(actor, ltFriend, actorBId) then
		LActor.sendTipmsg(actor, LangFriend.fr004, ttScreenCenter)
		return
	end

	--B在A的黑名单中
	if isInList(actor, ltBlack, actorBId) then
		--将好友从黑名单删除再发送申请
		return
		-- delFromList(actor, ltBlack, actorBId)
	end

	local actorPtr = LActor.getActorById(actorBId)
	--
	if actorPtr then
		if not isFriendSystemOpen(actorPtr) then
			LActor.sendTipmsg(actor, LangFriend.fr033, ttScreenCenter)
			return
		end

		-- A在B的黑名单中
		if isInList(actorPtr, ltBlack, actorId) then
			LActor.sendTipmsg(actor, LangFriend.fr019, ttScreenCenter)
			return
		end

		--对方玩家申请列表己满
		if isListFull(actorPtr, ltApply) then
			local id = ltApList(actorPtr, ltApply)
			delFromList(actorPtr,ltApply,id)
			sendDelListMember(actorPtr,ltApply,id)
			--LActor.sendTipmsg(actor, LangFriend.fr038, ttScreenCenter)
			--return
		end

		--加入申请列表
		addToList(actorPtr,ltApply, actorId)
		--
		sendAddListMember(actorPtr,ltApply,actorId)
		--返回提示给前端
		LActor.sendTipmsg(actor, LangFriend.fr014, ttScreenCenter)
	else
		--對方不在綫也發一個通知先
		LActor.sendTipmsg(actor, LangFriend.fr014, ttScreenCenter)
		-- load image run
		asynevent.reg(actorBId,function(imageActor,srcActorId,tarActorBId)
			print("friendsystem.sAddFriend 4 "..srcActorId.." "..tarActorBId)
			local srcActor = LActor.getActorById(srcActorId)
			if srcActor == nil then return end
			if not isFriendSystemOpen(imageActor) then
				LActor.sendTipmsg(srcActor, LangFriend.fr033, ttScreenCenter)
				return
			end
			LActor.postScriptEventLite(srcActor,2000,function(callActor,_imageActor,_srcActor,_srcActorId,_tarActorBId)
				print("friendsystem.sAddFriend 5 ".._srcActorId.." ".._tarActorBId)
				local check = LActor.getActorById(_srcActorId)
				if check == nil or check ~= _srcActor then return end
				local check2 = LActor.getActorById(_tarActorBId,false,true)
				if check2 == nil or check2 ~= _imageActor then return end
				print("friendsystem.sAddFriend 6 ".._srcActorId.." ".._tarActorBId)
				-- A在B的黑名单中
				if isInList(_imageActor, ltBlack, _srcActorId) then
					if callActor == nil then return end
					LActor.sendTipmsg(callActor, LangFriend.fr037, ttScreenCenter)
					return
				end
				--对方玩家申请列表己满
				if isListFull(_imageActor, ltApply) then
					if callActor == nil then return end
					LActor.sendTipmsg(callActor, LangFriend.fr038, ttScreenCenter)
					return
				end
				--加入列表
				addToList(_imageActor,ltApply, _srcActorId)
				--
			end,imageActor,srcActor,srcActorId,tarActorBId)


		end,actorId,actorBId)
	end
	return true
end

-- Comments: 请求加好友的回应
local function sAddResp(actor, pack)
	LActor.log(actor,"friendsystem.sAddResp","1")
	local actorBId = LDataPack.readUInt(pack)
	--0：拒绝 1：接受 
	local isReceive = LDataPack.readByte(pack)   

	local actorId = LActor.getActorId(actor)
	if actorId == actorBId then return false end


	local actorPtr = LActor.getActorById(actorBId)


	if isInList(actor, ltApply, actorBId) then
		--从申请删除
		delFromList(actor, ltApply, actorBId)
		sendDelListMember(actor,ltApply,actorBId)
	else
		return
	end

	LActor.log(actor,"friendsystem.sAddResp","2",isReceive)
	if isReceive == 1 then --如果接受
		--如果B己经是A的好友
		if isInList(actor, ltFriend, actorBId) then
			LActor.sendTipmsg(actor, LangFriend.fr004, ttScreenCenter)
			return false
		end

		--对方在你的黑名单中
		if isInList(actor, ltBlack, actorBId) then
			LActor.sendTipmsg(actor, LangFriend.fr020, ttScreenCenter)
			return false
		end

		--玩家列表己满
		if isListFull(actor, ltFriend) then
			LActor.sendTipmsg(actor, LangFriend.fr008, ttScreenCenter)
			return false
		end

		LActor.log(actor,"friendsystem.sAddResp","3",actorPtr)
		if actorPtr then
			--你在对方黑名单中
			if isInList(actorPtr, ltBlack, LActor.getActorId(actor)) then
				LActor.sendTipmsg(actor, LangFriend.fr021, ttScreenCenter)
				return false
			end

			--对方玩家列表己满
			if isListFull(actorPtr, ltFriend) then
				LActor.sendTipmsg(actor, LangFriend.fr009, ttScreenCenter)
				return false
			end

			--相互添加好友
			addToList(actor,ltFriend, actorBId)
			sendAddListMember(actor,ltFriend,actorBId)

			addToList(actorPtr,ltFriend, LActor.getActorId(actor))
			sendAddListMember(actorPtr,ltFriend, LActor.getActorId(actor))

			if (isInList(actorPtr,ltApply,LActor.getActorId(actor))) then
				delFromList(actorPtr, ltApply, LActor.getActorId(actor))
				sendDelListMember(actorPtr,ltApply,LActor.getActorId(actor))
			end

			--发送通知
			local tips = string.format(LangFriend.fr005, LActor.getName(actor))
			LActor.sendTipmsg(actorPtr, tips, ttScreenCenter)
		else
			-- --load image run
			LActor.log(actor,"friendsystem.sAddResp","4")
			asynevent.reg(actorBId,function(imageActor,srcActorId,tarActorBId)
				print("friendsystem.sAddResp 5 srcActorId:"..srcActorId.." tarActorBId:"..tarActorBId)
				local srcActor = LActor.getActorById(srcActorId)
				if srcActor == nil then return end
				if not isFriendSystemOpen(imageActor) then
					LActor.sendTipmsg(srcActor, LangFriend.fr033, ttScreenCenter)
					return
				end

				if srcActor == nil then return end
				LActor.postScriptEventLite(srcActor,1500,function(callActor,_imageActor,_srcActor,_srcActorId,_tarActorBId)
					print("friendsystem.sAddResp 6 srcActorId:".._srcActorId.." tarActorBId:".._tarActorBId)
					local check = LActor.getActorById(_srcActorId)
					if check == nil then return end
					local check2 = LActor.getActorById(_tarActorBId,false,true)
					if check2 == nil then return end
					print("friendsystem.sAddResp 7 srcActorId:".._srcActorId.." tarActorBId:".._tarActorBId)
					-- A在B的黑名单中
					if isInList(_imageActor, ltBlack, _srcActorId) then
						if callActor == nil then return end
						LActor.sendTipmsg(callActor, LangFriend.fr019, ttScreenCenter)
						return
					end

					--对方玩家列表己满
					if isListFull(_imageActor, ltFriend) then
						if callActor == nil then return end
						LActor.sendTipmsg(callActor, LangFriend.fr009, ttScreenCenter)
						return false
					end

					--加入好友列表
					addToList(_srcActor,ltFriend, _tarActorBId)
					
					addToList(_imageActor,ltFriend, _srcActorId)
					--
					sendAddListMember(_srcActor,ltFriend,_tarActorBId)

				end,imageActor,srcActor,srcActorId,tarActorBId)


			end,actorId,actorBId)
		
		end
	else
		--拒绝
		local tips = string.format((isReceive == 0 and LangFriend.fr006) or LangFriend.fr030,LActor.getName(actor))
		LActor.sendTipmsg(actorPtr, tips, ttScreenCenter)
	end
end

-- Comments: 添加黑名单
local function sAddBlack(actor, pack)
	LActor.log(actor,"friendsystem.sAddBlack","1")
	if not isFriendSystemOpen(actor) then
		-- LActor.sendTipmsg(actor, LangFriend.fr033, ttScreenCenter)
		return
	end

	local actorBId = LDataPack.readUInt(pack)
	local actorBName = LDataPack.readString(pack)

	if actorBId == 0 then
		--根据角色名字查id
		actorBId = LActor.getActorIdByName(actorBName)
		if actorBId == 0 then
			-- LActor.sendTipmsg(actor, LangFriend.fr034, ttScreenCenter)
			return
		end
	end

	local actorId = LActor.getActorId(actor)
	if actorId == actorBId then return false end

	--列表已满
	if isListFull(actor, ltBlack) then
		LActor.sendTipmsg(actor, LangFriend.fr010, ttScreenCenter)
		return
	end

	--己经在黑名单里
	if isInList(actor, ltBlack, actorBId) then
		LActor.sendTipmsg(actor, LangFriend.fr020, ttScreenCenter)
		return
	end

	if isInList(actor, ltFriend, actorBId) then
		delFromList(actor, ltFriend, actorBId)
		sendDelListMember(actorPtr,ltFriend,actorId)
	end

	if isInList(actor, ltApply, actorBId) then
		delFromList(actor, ltApply, actorBId)
		sendDelListMember(actorPtr,ltApply,actorId)
	end

	if isInList(actor, ltChats, actorBId) then
		delFromList(actor, ltChats, actorBId)
		sendDelListMember(actorPtr,ltChats,actorId)
	end

	--插入黑名单列表
	if addToList(actor,ltBlack, actorBId) then
		LActor.log(actor,"friendsystem.sAddBlack","2")
		sendAddListMember(actor,ltBlack,actorBId)
		local str = string.format(LangFriend.fr028, actorBName)
		LActor.sendTipmsg(actor, str, ttScreenCenter)

		local actorPtr = LActor.getActorById(actorBId)
		if actorPtr then
			if isInList(actorPtr, ltFriend, actorId) then
				delFromList(actorPtr,ltFriend, actorId)
				sendDelListMember(actorPtr,ltFriend, actorId)
			end

			if isInList(actorPtr, ltChats, actorId) then
				delFromList(actorPtr,ltChats, actorId)
				sendDelListMember(actorPtr,ltChats, actorId)
			end
		else
			--这个可以直接发db请求
			friendtodb.delFromDb(actorBId, actorId, ltFriend)
			friendtodb.delFromDb(actorBId, actorId, ltChats)
		end
	end
end

local function sDelListX(actor, pack)
	LActor.log(actor,"friendsystem.sDelListX","1")
	local lt = LDataPack.readByte(pack)
	local actorBId = LDataPack.readUInt(pack)
	local actorId = LActor.getActorId(actor)
	--
	if not (lt > ltUndefine and lt < ltMax) then
		print(LActor.getActorId(actor) .. "friendsystem.sDelListX lt error ")
		return
	end

	--不存在
	if not isInList(actor, lt, actorBId) then
		print(LActor.getActorId(actor) .. "friendsystem.sDelListX undefine ")
		return
	end

	local ret = delFromList(actor, lt, actorBId)
	LActor.log(actor,"friendsystem.sDelListX","2",ret)
	if ret then

		sendDelListMember(actor,lt,actorBId)
		if ltFriend == lt then
			--好友没了，最近联系要删了
			delFromList(actor, ltChats, actorBId)
			sendDelListMember(actor,ltChats,actorBId)
		elseif ltChats == lt then
		elseif ltApply == lt then
		elseif ltBlack == lt then
		end
		
		local actorPtr = LActor.getActorById(actorBId)
		if actorPtr then
			if ltFriend == lt then
				--在线就删除推送
				delFromList(actorPtr, ltFriend, actorId)
				sendDelListMember(actorPtr,ltFriend,actorId)
				delFromList(actorPtr, ltChats, actorId)
				sendDelListMember(actorPtr,ltChats,actorId)
			elseif ltChats == lt then
			elseif ltApply == lt then
			elseif ltBlack == lt then
			end
		else
			if ltFriend == lt then
				--这个可以直接发db请求
				friendtodb.delFromDb(actorBId, actorId, ltFriend)
				friendtodb.delFromDb(actorBId, actorId, ltChats)
			elseif ltChats == _lt then
			elseif ltApply == _lt then
			elseif ltBlack == _lt then
			end
		end
	end
end

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


local function sChat(actor, pack)
	local actorBId = LDataPack.readUInt(pack)
	local content = LDataPack.readString(pack)

	local limit = getFriendContentLimit()
	if utf8len(content) > limit then
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Friend, Protocol.sFriendCmd_Chat)
		if npack == nil then return false end
		LDataPack.writeByte(npack, 0)
		LDataPack.flush(npack)
		print(LActor.getActorId(actor) .. "person char len error")
		return
	end

	content = System.filterText(content)



	local actorId = LActor.getActorId(actor)
	if actorId == actorBId then return false end

	if not isInList(actor, ltFriend, actorBId) then
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Friend, Protocol.sFriendCmd_Chat)
		if npack == nil then return false end
		LDataPack.writeByte(npack, 0)
		LDataPack.flush(npack)
		LActor.sendTipmsg(actor,LangFriend.fr036, ttScreenCenter)
		
		print(LActor.getActorId(actor) .. "if not friend " .. actorBId)
		return
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Friend, Protocol.sFriendCmd_Chat)
	if npack == nil then return false end
	LDataPack.writeByte(npack, 1)
	LDataPack.writeUInt(npack, actorBId)
	LDataPack.writeInt(npack, System.getNowTime())
	LDataPack.writeString(npack, content)
	LDataPack.flush(npack)

	-- 增加最近联系人
	if addToList(actor,ltChats, actorBId) then
		sendAddListMember(actor,ltChats,actorBId)
	end

	local actorPtr = LActor.getActorById(actorBId)
	if actorPtr then
		-- print("push msg !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
		local npack = LDataPack.allocPacket(actorPtr, Protocol.CMD_Friend, Protocol.sFriendCmd_SingleChat)
		if npack == nil then return false end
		LDataPack.writeUInt(npack, actorId)
		LDataPack.writeInt(npack, System.getNowTime() or 0)
		LDataPack.writeString(npack, content)
		LDataPack.flush(npack)
		-- 增加最近联系人
		if addToList(actorPtr,ltChats, actorId) then
			sendAddListMember(actorPtr,ltChats,actorId)
		end
	else
		--离线留言
		friendoffline.sendOffChat(actorId,actorBId,System.getNowTime(),content)	
	end


end


-------------------------------------------------------------------------------------------


-- Comments: 上下线通知好友
function onlineChange(actor, online)
	--只通知好友列表
	local list = getList(actor,ltFriend)
	broadCast(actor, list, ltFriend, online)
	
	-- broadCast(actor, lists, ftChats,  online)
	-- broadCast(actor, lists, ftApply,  online)
	-- broadCast(actor, lists, ftBlack,  online)
end


-- Comments: 广播上下线通知
function broadCast(actor, friendList, friendType, online)
	if not friendList then return end
	local actorId = LActor.getActorId(actor)
	for aid,_ in pairs(friendList.data) do
		local actorPtr = LActor.getActorById(aid)
		if actorPtr then
			local pack = LDataPack.allocPacket(actorPtr, Protocol.CMD_Friend, Protocol.sFriendCmd_online)
			if pack == nil then return end
			LDataPack.writeUInt(pack,actorId)
			LDataPack.writeByte(pack,online)
			LDataPack.flush(pack)

			local name = LActor.getName(actor)
			local tip = string.format(online == 1 and LangFriend.fr024 or LangFriend.fr025, name)
			LActor.sendTipmsg(actorPtr, tip, ttScreenCenter)
		end
	end
end

-- Comments: 从db加载数据
function loadData(actor, packet)
	LoadDbFriend(actor, packet)

	if LActor.isImage(actor) then return end
	-- 将好友信息发送给客户端
	sendList(actor,ltFriend)
	sendList(actor,ltChats)
	sendList(actor,ltApply)
	sendList(actor,ltBlack)

	-- 通知上线
	onlineChange(actor, online or 1)
end

-- load数据
local function onBeforeLogin(actor)
	-- if not isFriendSystemOpen(actor) then
	-- 	return
	-- end
	local actorId = LActor.getActorId(actor)
	local serverId = LActor.getServerId(actor)
	System.SendToDb(serverId, 1, dbCmd.dcLoadFriends, 1, dtInt, actorId)
end

-- Comments: 上线
function onLogin(actor)

end

-- Comments: 下线
function onLogout(actor)
	if LActor.isImage(actor) then return end
	updateChatsTime(actor)
	onlineChange(actor, 0)
end

-- Comments: 新的一天
function onNewDay(actor)
end


--上线执行
local function offlineDealPushMsg(actor, offmsg)
	local actorId = LActor.getActorId(actor)
	local msgType = LDataPack.readWord(offmsg)
	local actorBId = LDataPack.readUInt(offmsg)
	--对方角色id，时间，内容
	local time = LDataPack.readInt(offmsg)
	--保存时候已经过滤了
	local content = LDataPack.readString(offmsg)

	-- print(msgType .. "xx"..time.."======")
	-- print("whatsay========="..content)
	-- print(msgType,actorBId,time,content)
	
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Friend, Protocol.sFriendCmd_SingleChat)
	if npack == nil then return false end
	LDataPack.writeUInt(npack, actorBId)
	LDataPack.writeInt(npack, time)
	LDataPack.writeString(npack, content or "")
	LDataPack.flush(npack)
	-- 增加最近联系人

	if addToList(actor,ltChats, actorBId) then
		sendAddListMember(actor,ltChats,actorBId)
	end

	-- 离线消息限制
	friendoffline.PV(actorBId,actorId,-1)
	
	-- 成功返回删除该消息
	return true
end

msgsystem.regHandle( offlineFriendMsg, offlineDealPushMsg )

--require???
local dbretdispatcher = require("utils.net.dbretdispatcher")
-- 数据库协议

dbretdispatcher.reg(dbEntity, dbCmd.dcLoadFriends, loadData)

actorevent.reg(aeInit, onBeforeLogin)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeUserLogout, onLogout)
actorevent.reg(aeNewDayArrive, onNewDay)



netmsgdispatcher.reg(Protocol.CMD_Friend, Protocol.cFriendCmd_GetFriendList, function(actor,pack) sendList(actor,ltFriend) end)
netmsgdispatcher.reg(Protocol.CMD_Friend, Protocol.cFriendCmd_GetChatsList,  function(actor,pack) sendList(actor,ltChats) end)
netmsgdispatcher.reg(Protocol.CMD_Friend, Protocol.cFriendCmd_GetApplyList,  function(actor,pack) sendList(actor,ltApply) end)
netmsgdispatcher.reg(Protocol.CMD_Friend, Protocol.cFriendCmd_GetBlackList,  function(actor,pack) sendList(actor,ltBlack) end)
netmsgdispatcher.reg(Protocol.CMD_Friend, Protocol.cFriendCmd_AddFriend, sAddFriend)
netmsgdispatcher.reg(Protocol.CMD_Friend, Protocol.cFriendCmd_AddBlack,  sAddBlack)
netmsgdispatcher.reg(Protocol.CMD_Friend, Protocol.cFriendCmd_AddResp,   sAddResp)
netmsgdispatcher.reg(Protocol.CMD_Friend, Protocol.cFriendCmd_DelListX,  sDelListX)
netmsgdispatcher.reg(Protocol.CMD_Friend, Protocol.cFriendCmd_Chat,      sChat)
netmsgdispatcher.reg(Protocol.CMD_Friend, Protocol.cFriendCmd_ChatCache, sChatCache)


local gmsystem    = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.fs = function(actor, args)
	local lt = tonumber(args[1])
	sendList(actor,lt)
end

gmCmdHandlers.fsp5 = function(actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, tonumber(args[1]))
	LDataPack.writeString(pack, args[2])
	LDataPack.setPosition(pack, 0)
	sAddFriend(actor,pack)
end

gmCmdHandlers.fsp6 = function(actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, tonumber(args[1]))
	LDataPack.writeString(pack, args[2])
	LDataPack.setPosition(pack, 0)
	sAddBlack(actor,pack)
end

gmCmdHandlers.fsp8 = function(actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, tonumber(args[1]))
	LDataPack.writeByte(pack, tonumber(args[2]))
	LDataPack.setPosition(pack, 0)
	sAddResp(actor,pack)
end

gmCmdHandlers.fsp9 = function(actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, tonumber(args[1]))
	LDataPack.writeUInt(pack, tonumber(args[2]))
	LDataPack.setPosition(pack, 0)
	sDelListX(actor,pack)
end

gmCmdHandlers.fsp11 = function(actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeUInt(pack, tonumber(args[1]))
	LDataPack.writeString(pack, args[2])
	LDataPack.setPosition(pack, 0)
	sChat(actor,pack)
end

gmCmdHandlers.fsp14 = function(actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeUInt(pack, tonumber(args[1]))
	LDataPack.writeString(pack, args[2])
	LDataPack.setPosition(pack, 0)
	sChat(actor,pack)
end
