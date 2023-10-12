--好友系统
module("friendoffline", package.seeall)

local LActor = LActor
local LDataPack = LDataPack
local LangFriend = LAN.Friend

local ltUndefine      = friendcommon.ltUndefine
local ltFriend 		  = friendcommon.ltFriend
local ltChats 		  = friendcommon.ltChats
local ltApply   	  = friendcommon.ltApply
local ltBlack  		  = friendcommon.ltBlack
local ltMax           = friendcommon.ltMax

local isFriendSystemOpen     = friendcommon.isFriendSystemOpen
local LoadDbFriend           = friendcommon.LoadDbFriend

local getList                = friendcommon.getList
local getListCount           = friendcommon.getListCount
local isListFull             = friendcommon.isListFull

local addToList              = friendcommon.addToList
local delFromList            = friendcommon.delFromList
local isInList               = friendcommon.isInList
local getListData            = friendcommon.getListData

local offlineFriendMsg = msgsystem.offlineFriendMsg

_G.FriendOfflineMsgLimit = _G.FriendOfflineMsgLimit or {}

function getFriendOfflineMsgCount(actorId,actorBId)
	FriendOfflineMsgLimit[actorBId] = FriendOfflineMsgLimit[actorBId] or 0
	return FriendOfflineMsgLimit[actorBId]
end

function PV(actorId,actorBId,pv)
	FriendOfflineMsgLimit[actorBId] = FriendOfflineMsgLimit[actorBId] or 0
	FriendOfflineMsgLimit[actorBId] = FriendOfflineMsgLimit[actorBId] + pv
	-- print(pv.."pv=========================="..actorBId.."===="..FriendOfflineMsgLimit[actorBId])
end

function checkLimit(actorId,actorBId)
	FriendOfflineMsgLimit[actorBId] = FriendOfflineMsgLimit[actorBId] or 0
	if FriendOfflineMsgLimit[actorBId] >= 0 and FriendOfflineMsgLimit[actorBId] <= 31 then
		return true
	end
	return false
end

function sendOffChat(actorId,actorBId,time,content)
	-- print("=========================="..actorBId.."===="..FriendOfflineMsgLimit[actorBId])
	if not checkLimit(actorId,actorBId) then
		return false
	end
	local npack = LDataPack.allocPacket()
	LDataPack.writeWord(npack, offlineFriendMsg)
	LDataPack.writeUInt(npack, actorId)
	LDataPack.writeInt(npack, time)
	LDataPack.writeString(npack, content)
	System.sendOffMsg(actorBId, "","", actorId, npack)

	PV(actorId,actorBId,1)
end


