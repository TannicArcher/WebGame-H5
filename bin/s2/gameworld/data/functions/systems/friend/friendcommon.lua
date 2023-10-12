module("friendcommon", package.seeall)

local LActor = LActor
local LDataPack = LDataPack

local friendtodb = friendtodb

--lt            = list type
ltUndefine      = 0 --
ltFriend 		= 1 --好友
ltChats 		= 2 --最近的联系人
ltApply   	    = 3 --申请
ltBlack  		= 4 --黑名单
ltMax           = 5


local TOTAL_NUM = FriendLimit.friendListLen + FriendLimit.chatsListLen + FriendLimit.applyListLen + FriendLimit.blacklistLen


function isFriendSystemOpen(actor)
	if LActor.getLevel(actor) >= FriendLimit.sysLv then
		return true
	end
	return false
end

function getFriendContentLimit(actor)
	return FriendLimit.contentLimit
end

-- Comments: 初始化列表
function initFriendList(actor)

	local var = LActor.getDynamicVar(actor)
	var.lists = {}
	var.lists[ltFriend] = {}
	var.lists[ltFriend].len = 0
	var.lists[ltFriend].data = {}
	var.lists[ltChats] = {}
	var.lists[ltChats].len = 0
	var.lists[ltChats].data = {}
	var.lists[ltApply] = {}
	var.lists[ltApply].len = 0
	var.lists[ltApply].data = {}
	var.lists[ltBlack] = {}
	var.lists[ltBlack].len = 0
	var.lists[ltBlack].data = {}
	return var.lists
end

function getLists(actor)
	local var = LActor.getDynamicVar(actor)
	local initflag = var.lists
	if var.lists == nil then
		var.lists = {}
		var.lists[ltFriend] = {}
		var.lists[ltFriend].len = 0
		var.lists[ltFriend].data = {}
		var.lists[ltChats] = {}
		var.lists[ltChats].len = 0
		var.lists[ltChats].data = {}
		var.lists[ltApply] = {}
		var.lists[ltApply].len = 0
		var.lists[ltApply].data = {}
		var.lists[ltBlack] = {}
		var.lists[ltBlack].len = 0
		var.lists[ltBlack].data = {}
	end
	return var.lists,initflag
end

function getList(actor, lt)
	if not (lt > ltUndefine and lt < ltMax) then
		print(LActor.getActorId(actor) .. "friendcommon.getList lt error ")
		return
	end
	local lists = getLists(actor)
	return lists[lt]
end

function getListCount(actor, lt)
	if not (lt > ltUndefine and lt < ltMax) then
		print(LActor.getActorId(actor) .. "friendcommon.getListCount lt error ")
		return
	end
	local list = getList(actor,lt)
	return list.len
end

function isListFull(actor, lt)
	if not (lt > ltUndefine and lt < ltMax) then
		print(LActor.getActorId(actor) .. "friendsystem.isListFull lt error ")
		return
	end
	local count = getListCount(actor, lt)
	if ltFriend == lt then
		return count >= FriendLimit.friendListLen
	elseif ltChats == lt then
		return count >= FriendLimit.chatsListLen
	elseif ltApply == lt then
		return count >= FriendLimit.applyListLen
	elseif ltBlack == lt then
		return count >= FriendLimit.blacklistLen
	end
end

--判断最近联系人
function tidyList(actor, lt)
	if isListFull(actor, lt) then
		local list = getList(actor, lt)
		local min = -1
		local actor_id = -1
		for k, v in pairs(list.data) do
			if min == -1 or (v.newLastcontact or v.lastcontact) < min then
				min = v.newLastcontact or v.lastcontact
				actor_id = k
			end
		end
		return actor_id
	end
end

--判断申请列表
function ltApList(actor, lt)
	if isListFull(actor, lt) then
		local list = getList(actor, lt)
		local min = -1
		local actor_id = -1
		for k, v in pairs(list.data) do
			if min == -1 or (v.addfriendtime ) < min then
				min = v.addfriendtime
				actor_id = k
			end
		end
		return actor_id
	end
end

function addToList(actor, lt, actorBId)
	if not (lt > ltUndefine and lt < ltMax) then
		print(LActor.getActorId(actor) .. "friendsystem.addToList lt error ")
		return
	end

	local list = getList(actor, lt)
	if list.data[actorBId] == nil then
		--干掉超出最近聯係人长度的
		if lt == ltChats then
			local id = tidyList(actor, lt)
			if id and list.data[id] then
				friendtodb.delFromDb(LActor.getActorId(actor), id, lt)
				list.len = list.len - 1
				list.data[id] = nil
				friendsystem.sendDelListMember(actor, ltChats, id)
			end
		end

		list.len = list.len + 1
		list.data[actorBId] = {}
		list.data[actorBId].addfriendtime = System.getNowTime()
		list.data[actorBId].lastcontact = System.getNowTime()
		--存到数据库
		friendtodb.addToDb(LActor.getActorId(actor), actorBId, lt, list.data[actorBId].addfriendtime,list.data[actorBId].lastcontact)
		-- print(LActor.getActorId(actor) .. "friendsystem.addToList ok")
		return true
	elseif ltChats == lt and list.data[actorBId] ~= nil then
		-- list.data[actorBId].addfriendtime = System.getNowTime()
		-- list.data[actorBId].lastcontact = System.getNowTime()
		list.data[actorBId].newLastcontact = System.getNowTime()
	end
end

function updateChatsTime(actor)
	local list = getList(actor, ltChats)
	if list.data == nil then return end
	for actorBId,v in pairs(list.data) do
		if v.newLastcontact and v.newLastcontact > v.lastcontact and v.addfriendtime then
			friendtodb.addToDb(LActor.getActorId(actor), actorBId, ltChats, v.addfriendtime,v.newLastcontact)
		end
	end
end

function delFromList(actor, lt, actorBId)
	if not (lt > ltUndefine and lt < ltMax) then
		print(LActor.getActorId(actor) .. "friendsystem.delFromList lt error ")
		return
	end
	if (actorBId == nil ) then return end
	
	local list = getList(actor, lt)
	if list.data[actorBId] then
		friendtodb.delFromDb(LActor.getActorId(actor), actorBId, lt)
		list.data[actorBId] = nil
		list.len = list.len - 1
		-- print(LActor.getActorId(actor) .. "friendsystem.delFromList ok")
		return true
	end
end

function getFromList(actor, lt, actorBId)
	if not (lt > ltUndefine and lt < ltMax) then
		print(LActor.getActorId(actor) .. "friendsystem.getFromList lt error ")
		return
	end
	local list = getList(actor, lt)
	return list[actorBId]
end

function isInList(actor, lt, actorBId)
	if not (lt > ltUndefine and lt < ltMax) then
		print(LActor.getActorId(actor) .. "friendsystem.isInList lt error ")
		return
	end
	local list = getList(actor, lt)
	if list.data[actorBId] then
		-- print(LActor.getActorId(actor) .. "friendsystem.isInList ok")
		return true
	end
end

function getListData(actor, lt, actorBId)
	if not (lt > ltUndefine and lt < ltMax) then
		print(LActor.getActorId(actor) .. "friendsystem.getListData lt error ")
		return
	end
	local list = getList(actor, lt)
	if list.data[actorBId] then
		return list.data[actorBId]
	end
end

function loadList(actor, aid, friendType, paddfriendtime, plastcontact)
	local lt = friendType
	if not (lt > ltUndefine and lt < ltMax) then
		print(LActor.getActorId(actor) .. "friendsystem.isInList lt error ")
		return
	end
	local list = getList(actor, lt)
	list.data[aid] = {addfriendtime = paddfriendtime, lastcontact = plastcontact}
	list.len = list.len + 1
	return true
end



-- Comments: 从db加载数据初始化
function LoadDbFriend(actor, packet)
	--从数据库加载好友
	if actor == nil or packet == nil then return end
	local count = LDataPack.readInt(packet)
	if count > TOTAL_NUM then
		print(LActor.getActorId(actor) .. "friendsystem.LoadDbFriend unexept count" .. count)
		count = TOTAL_NUM
	end
	
	--初始化
	local aid, friendType, addfriendtime, lastcontact = 0,0,0,0
	local friendList = initFriendList(actor)
	for i=1, count do
		aid,friendType,addfriendtime, lastcontact = LDataPack.readData(packet, 4, dtUint, dtByte,dtUint,dtUint)
		loadList(actor, aid, friendType, addfriendtime, lastcontact)
	end
	-- local log,_=getLists(actor)
	-- print_lua_table(log)
end


-- function print_lua_table(lua_table, indent)
-- 	indent = indent or 0
-- 	for k, v in pairs(lua_table) do
-- 		if type(k) == "string" then
-- 			k = string.format("%q", k)
-- 		end
-- 		local szSuffix = ""
-- 		if type(v) == "table" then
-- 			szSuffix = "{"
-- 		end
-- 		local szPrefix = string.rep("    ", indent)
-- 		formatting = szPrefix.."["..k.."]".." = "..szSuffix
-- 		if type(v) == "table" then
-- 			print(formatting)
-- 			print_lua_table(v, indent + 1)
-- 			print(szPrefix.."},")
-- 		else
-- 			local szValue = ""
-- 			if type(v) == "string" then
-- 				szValue = string.format("%q", v)
-- 			else
-- 				szValue = tostring(v)
-- 			end
-- 			print(formatting..szValue..",")
-- 		end
-- 	end
-- end

